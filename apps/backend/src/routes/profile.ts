import { Router } from 'express';
import { prisma } from '../config/prisma';
import { requireAuth, AuthRequest } from '../middleware/auth';

const router = Router();

// GET /api/profile
router.get('/', requireAuth, async (req: AuthRequest, res) => {
  const profile = await prisma.profile.findUnique({
    where: { id: req.userId! }
  });
  return res.json(profile || {});
});

// POST /api/profile/update
router.post('/update', requireAuth, async (req: AuthRequest, res) => {
  const { displayName, college, branch, year, rollNumber, division, batch, weeklyBudget } = req.body;
  const profile = await prisma.profile.upsert({
    where: { id: req.userId! },
    create: { 
      id: req.userId!, 
      displayName: displayName || 'Lumina User', 
      college, branch, year: year ? parseInt(year) : null, rollNumber, division, batch,
      weeklyBudget: weeklyBudget ? parseFloat(weeklyBudget) : 2000.0
    },
    update: { 
      displayName: displayName || undefined,
      college, branch, year: year ? parseInt(year) : null, rollNumber, division, batch,
      weeklyBudget: weeklyBudget ? parseFloat(weeklyBudget) : undefined
    },
  });
  return res.json(profile);
});

export default router;
