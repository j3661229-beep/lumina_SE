import { Router } from 'express';
import { body, validationResult } from 'express-validator';
import { prisma } from '../config/prisma';
import { requireAuth, AuthRequest } from '../middleware/auth';
import crypto from 'crypto';

const router = Router();

// ─────────────────────────────────────────────────────────────
// Exponential decay cognitive debt model
// debt(t) = Σ weight * e^(-λ * minutes_since)
// λ = 0.05; short sessions (< 2 min) penalized 3×
// ─────────────────────────────────────────────────────────────
function computeCognitiveDebt(
  sessions: Array<{ sessionStart: Date; sessionEnd: Date | null }>
): number {
  const LAMBDA = 0.05;
  const now = Date.now();
  let debt = 0;

  for (const sw of sessions) {
    if (!sw.sessionEnd) continue;
    const durationSecs = (sw.sessionEnd.getTime() - sw.sessionStart.getTime()) / 1000;
    const minutesSince = (now - sw.sessionEnd.getTime()) / 60000;
    const switchWeight = durationSecs < 120 ? 3.0 : 1.0;
    debt += switchWeight * Math.exp(-LAMBDA * minutesSince);
  }

  return Math.min(100, Math.round(debt * 100) / 100);
}

// ─────────────────────────────────────────────────────────────
// POST /api/context-switch/batch
// ─────────────────────────────────────────────────────────────
router.post(
  '/batch',
  requireAuth,
  body('sessions').isArray({ min: 1 }),
  async (req: AuthRequest, res) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) return res.status(422).json({ errors: errors.array() });

    const { sessions } = req.body as {
      sessions: Array<{
        app_name: string;
        package_name?: string;
        session_start: string;
        session_end?: string;
      }>;
    };

    const userId = req.userId!;

    // Bulk insert sessions
    await prisma.contextSwitchLog.createMany({
      data: sessions.map((s) => ({
        userId,
        appName: s.app_name,
        packageName: s.package_name ?? null,
        sessionStart: new Date(s.session_start),
        sessionEnd: s.session_end ? new Date(s.session_end) : null,
      })),
    });

    // Compute today's debt
    const todayStart = new Date();
    todayStart.setHours(0, 0, 0, 0);

    const todaysSessions = await prisma.contextSwitchLog.findMany({
      where: { userId, sessionStart: { gte: todayStart } },
      select: { sessionStart: true, sessionEnd: true },
    });

    const score = computeCognitiveDebt(todaysSessions);
    const windowDate = new Date();
    windowDate.setHours(0, 0, 0, 0);

    await prisma.cognitiveDebtScore.upsert({
      where: { userId_windowDate: { userId, windowDate } },
      create: { userId, score, windowDate },
      update: { score, computedAt: new Date() },
    });

    return res.json({ debt_score: score });
  }
);

// ─────────────────────────────────────────────────────────────
// GET /api/context-switch/score — Last 7 days
// ─────────────────────────────────────────────────────────────
router.get('/score', requireAuth, async (req: AuthRequest, res) => {
  const scores = await prisma.cognitiveDebtScore.findMany({
    where: { userId: req.userId! },
    orderBy: { windowDate: 'desc' },
    take: 7,
    select: { score: true, windowDate: true },
  });
  return res.json(scores);
});

// ─────────────────────────────────────────────────────────────
// POST /api/context-switch/squad-snapshot
// ─────────────────────────────────────────────────────────────
router.post(
  '/squad-snapshot',
  requireAuth,
  body('group_id').isUUID(),
  body('debt_curve').isArray(),
  async (req: AuthRequest, res) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) return res.status(422).json({ errors: errors.array() });

    const { group_id, debt_curve } = req.body as { group_id: string; debt_curve: unknown[] };

    // Anonymize via SHA-256 — irreversible
    const anonId = crypto
      .createHash('sha256')
      .update(req.userId!)
      .digest('hex')
      .slice(0, 16);

    const snapshot = await prisma.squadFlowSnapshot.create({
      data: { groupId: group_id, anonId, debtCurve: debt_curve },
    });

    return res.json(snapshot);
  }
);

export default router;
