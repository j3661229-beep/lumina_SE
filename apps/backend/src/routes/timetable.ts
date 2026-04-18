import { Router } from 'express';
import { body, validationResult } from 'express-validator';
import { prisma } from '../config/prisma';
import { requireAuth, AuthRequest } from '../middleware/auth';
import { DayOfWeek, AttendanceStatus } from '@prisma/client';

const router = Router();

async function ensureProfile(userId: string) {
  await prisma.profile.upsert({
    where: { id: userId },
    create: { id: userId, displayName: 'Lumina User' },
    update: {},
  });
}

// ─────────────────────────────────────────────────────────────
// POST /api/timetable/slots — Bulk upsert OCR-parsed timetable
// ─────────────────────────────────────────────────────────────
router.post(
  '/slots',
  requireAuth,
  body('slots').isArray({ min: 1 }),
  body('slots.*.subject_name').isString().trim().notEmpty(),
  body('slots.*.day_of_week').isIn(Object.values(DayOfWeek)),
  body('slots.*.start_time').matches(/^\d{2}:\d{2}$/),
  body('slots.*.end_time').matches(/^\d{2}:\d{2}$/),
  async (req: AuthRequest, res) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) return res.status(422).json({ errors: errors.array() });

    const userId = req.userId!;
    await ensureProfile(userId);
    const { slots } = req.body as {
      slots: Array<{ subject_name: string; day_of_week: DayOfWeek; start_time: string; end_time: string; room?: string; slot_type?: string }>;
    };

    // Upsert subjects by name — return id map
    const subjectNames = [...new Set(slots.map((s) => s.subject_name))];
    const subjectMap: Record<string, string> = {};

    for (const name of subjectNames) {
      const subject = await prisma.subject.upsert({
        where: { userId_name: { userId, name } },
        create: { userId, name },
        update: {},
        select: { id: true, name: true },
      });
      subjectMap[name] = subject.id;
    }

    // Upsert timetable slots
    const inserted = await Promise.all(
      slots.map((s) =>
        prisma.timetableSlot.upsert({
          where: {
            no_overlap: {
              userId,
              dayOfWeek: s.day_of_week,
              startTime: s.start_time,
            },
          },
          create: {
            userId,
            subjectId: subjectMap[s.subject_name],
            dayOfWeek: s.day_of_week,
            startTime: s.start_time,
            endTime: s.end_time,
            room: s.room ?? null,
            slotType: s.slot_type ?? 'lecture',
          },
          update: {
            subjectId: subjectMap[s.subject_name],
            endTime: s.end_time,
            room: s.room ?? null,
            slotType: s.slot_type ?? 'lecture',
          },
        })
      )
    );

    return res.json({ inserted: inserted.length, slots: inserted });
  }
);

// ─────────────────────────────────────────────────────────────
// GET /api/timetable/slots — Full timetable with subject info
// ─────────────────────────────────────────────────────────────
router.get('/slots', requireAuth, async (req: AuthRequest, res) => {
  await ensureProfile(req.userId!);
  const slots = await prisma.timetableSlot.findMany({
    where: { userId: req.userId! },
    include: {
      subject: { select: { name: true, code: true, colorHex: true, teacher: true } },
    },
    orderBy: [{ dayOfWeek: 'asc' }, { startTime: 'asc' }],
  });
  return res.json(slots);
});

// ─────────────────────────────────────────────────────────────
// POST /api/timetable/attendance — Mark attendance for a slot
// ─────────────────────────────────────────────────────────────
router.post(
  '/attendance',
  requireAuth,
  body('slot_id').isUUID(),
  body('date').isISO8601(),
  body('status').isIn(Object.values(AttendanceStatus)),
  async (req: AuthRequest, res) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) return res.status(422).json({ errors: errors.array() });

    const { slot_id, date, status, note } = req.body as {
      slot_id: string; date: string; status: AttendanceStatus; note?: string;
    };

    const log = await prisma.attendanceLog.upsert({
      where: { slotId_date: { slotId: slot_id, date: new Date(date) } },
      create: { userId: req.userId!, slotId: slot_id, date: new Date(date), status, note },
      update: { status, note },
    });
    return res.json(log);
  }
);

// ─────────────────────────────────────────────────────────────
// GET /api/timetable/bunk-analytics — Per-subject bunk budget
// (reads the materialized view via $queryRaw)
// ─────────────────────────────────────────────────────────────
router.get('/bunk-analytics', requireAuth, async (req: AuthRequest, res) => {
  const data = await prisma.$queryRaw`
    SELECT * FROM public.attendance_summary
    WHERE user_id = ${req.userId!}::uuid
  `;
  return res.json(data);
});

export default router;
