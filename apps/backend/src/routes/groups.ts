import { Router } from 'express';
import { body, validationResult } from 'express-validator';
import { prisma } from '../config/prisma';
import { requireAuth, AuthRequest } from '../middleware/auth';

const router = Router();

// Helper: ensure profile exists for this user (upsert on every mutation)
async function ensureProfile(userId: string, displayName?: string) {
  await prisma.profile.upsert({
    where: { id: userId },
    create: { id: userId, displayName: displayName ?? 'Lumina User' },
    update: {},
  });
}

// ────────────────────────────────────────────────────────────
// GET /api/groups  — list groups the user belongs to
// ────────────────────────────────────────────────────────────
router.get('/', requireAuth, async (req: AuthRequest, res) => {
  await ensureProfile(req.userId!);
  const memberships = await prisma.groupMember.findMany({
    where: { profileId: req.userId! },
    include: {
      group: {
        select: { id: true, name: true, description: true, inviteCode: true, createdAt: true },
      },
    },
  });
  return res.json(memberships.map((m) => ({ ...m.group, role: m.role })));
});

// ────────────────────────────────────────────────────────────
// POST /api/groups  — create group + auto-add creator as admin
// ────────────────────────────────────────────────────────────
router.post(
  '/',
  requireAuth,
  body('name').isString().trim().notEmpty().withMessage('Group name required'),
  async (req: AuthRequest, res) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) return res.status(422).json({ error: errors.array()[0].msg });

    const { name, description } = req.body as { name: string; description?: string };
    const userId = req.userId!;

    // Upsert profile first (foreign key requirement)
    await ensureProfile(userId, name);

    const group = await prisma.$transaction(async (tx) => {
      const g = await tx.group.create({
        data: { name, description, createdBy: userId },
      });
      await tx.groupMember.create({
        data: { groupId: g.id, profileId: userId, role: 'admin' },
      });
      return g;
    });

    return res.status(201).json(group);
  }
);

// ────────────────────────────────────────────────────────────
// POST /api/groups/join  — join via 8-char invite code
// ────────────────────────────────────────────────────────────
router.post(
  '/join',
  requireAuth,
  body('invite_code').isString().trim().isLength({ min: 8, max: 8 }).withMessage('Invite code must be 8 chars'),
  async (req: AuthRequest, res) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) return res.status(422).json({ error: errors.array()[0].msg });

    const { invite_code } = req.body as { invite_code: string };
    const userId = req.userId!;

    await ensureProfile(userId);

    const group = await prisma.group.findUnique({
      where: { inviteCode: invite_code },
      select: { id: true, name: true },
    });

    if (!group) return res.status(404).json({ error: 'Invalid invite code — check and try again.' });

    await prisma.groupMember.upsert({
      where: { groupId_profileId: { groupId: group.id, profileId: userId } },
      create: { groupId: group.id, profileId: userId, role: 'member' },
      update: {},
    });

    return res.json({ group_id: group.id, group_name: group.name, message: 'Joined successfully! 🎉' });
  }
);

// ────────────────────────────────────────────────────────────
// DELETE /api/groups/:id  — leave group
// ────────────────────────────────────────────────────────────
router.delete('/:id/leave', requireAuth, async (req: AuthRequest, res) => {
  await prisma.groupMember.deleteMany({
    where: { groupId: req.params.id, profileId: req.userId! },
  });
  return res.json({ message: 'Left group successfully.' });
});

// ────────────────────────────────────────────────────────────
// GET /api/groups/:id/members — list all members
// ────────────────────────────────────────────────────────────
router.get('/:id/members', requireAuth, async (req: AuthRequest, res) => {
  const members = await prisma.groupMember.findMany({
    where: { groupId: req.params.id },
    select: {
      role: true,
      profile: { select: { id: true, displayName: true, avatarUrl: true } }
    }
  });

  const group = await prisma.group.findUnique({
    where: { id: req.params.id },
    select: { createdBy: true }
  });

  if (!group) return res.status(404).json({ error: 'Group not found.' });

  return res.json({
    creatorId: group.createdBy,
    members: members.map(m => ({
      id: m.profile.id,
      name: m.profile.displayName,
      avatar: m.profile.avatarUrl,
      role: m.role,
      isCreator: m.profile.id === group.createdBy
    }))
  });
});

// ────────────────────────────────────────────────────────────
// POST /api/groups/:id/promote — make admin
// ────────────────────────────────────────────────────────────
router.post('/:id/promote', requireAuth, body('memberId').isUUID(), async (req: AuthRequest, res) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) return res.status(422).json({ error: errors.array()[0].msg });

  const { memberId } = req.body;
  const groupId = req.params.id;
  const requesterId = req.userId!;

  // Check if requester has powers (creator or admin)
  const group = await prisma.group.findUnique({ where: { id: groupId } });
  if (!group) return res.status(404).json({ error: 'Group not found.' });

  const requesterMember = await prisma.groupMember.findUnique({
    where: { groupId_profileId: { groupId, profileId: requesterId } }
  });

  if (!requesterMember || (requesterMember.role !== 'admin' && group.createdBy !== requesterId)) {
    return res.status(403).json({ error: 'You do not have permission to promote users.' });
  }

  // Promote
  await prisma.groupMember.update({
    where: { groupId_profileId: { groupId, profileId: memberId } },
    data: { role: 'admin' }
  });

  return res.json({ message: 'Promoted to admin successfully.' });
});

export default router;
