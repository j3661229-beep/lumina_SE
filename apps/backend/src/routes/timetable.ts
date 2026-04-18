import { Router } from 'express';
import { body, validationResult } from 'express-validator';
import { prisma } from '../config/prisma';
import { requireAuth, AuthRequest } from '../middleware/auth';
import { DayOfWeek, AttendanceStatus } from '@prisma/client';
import multer from 'multer';
import { GoogleGenAI, Type } from '@google/genai';

const router = Router();
const upload = multer({ storage: multer.memoryStorage(), limits: { fileSize: 10 * 1024 * 1024 } });


async function ensureProfile(userId: string) {
  await prisma.profile.upsert({
    where: { id: userId },
    create: { id: userId, displayName: 'Lumina User' },
    update: {},
  });
}

// ─────────────────────────────────────────────────────────────
// DELETE /api/timetable — Wipe entire timetable for user
// ─────────────────────────────────────────────────────────────
router.delete('/', requireAuth, async (req: AuthRequest, res) => {
  // Cascading deletes on Subject will wipe timetableSlots and attendanceLogs
  await prisma.subject.deleteMany({
    where: { userId: req.userId! },
  });
  return res.json({ message: 'Timetable deleted successfully.' });
});

// ─────────────────────────────────────────────────────────────
// POST /api/timetable/upload-ocr — Pass image to Gemini AI
// ─────────────────────────────────────────────────────────────
router.post('/upload-ocr', requireAuth, upload.single('file'), async (req: AuthRequest, res) => {
  if (!req.file) return res.status(400).json({ error: 'No file uploaded.' });
  if (!process.env.GEMINI_API_KEY) return res.status(500).json({ error: 'GEMINI_API_KEY is not configured.' });

  console.log(`[OCR] File received: ${req.file.originalname}, size: ${req.file.size} bytes, mime: ${req.file.mimetype}`);

  const ai = new GoogleGenAI({ apiKey: process.env.GEMINI_API_KEY });

  try {
    console.log('[OCR] Sending to Gemini...');
    const response = await ai.models.generateContent({
      model: 'gemini-2.5-flash',
      contents: [
        {
          role: 'user',
          parts: [
            { text: 'Extract the class timetable from this document. Identify the subject name, the assigned teacher (if available), the day of the week (lowercase long format like "monday"), the start time (HH:mm 24-hr format), and the end time (HH:mm 24-hr format). Ignore blank slots or recess/lunch.' },
            { inlineData: { data: req.file.buffer.toString('base64'), mimeType: req.file.mimetype } }
          ]
        }
      ],
      config: {
        responseMimeType: 'application/json',
        responseSchema: {
          type: Type.OBJECT,
          properties: {
            slots: {
              type: Type.ARRAY,
              items: {
                type: Type.OBJECT,
                properties: {
                  subject_name: { type: Type.STRING },
                  teacher: { type: Type.STRING, nullable: true },
                  day_of_week: { type: Type.STRING, enum: ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'] },
                  start_time: { type: Type.STRING, description: "HH:mm format 24hr" },
                  end_time: { type: Type.STRING, description: "HH:mm format 24hr" },
                  slot_type: { type: Type.STRING, enum: ['lecture', 'lab', 'tutorial'] },
                  room: { type: Type.STRING, nullable: true }
                },
                required: ['subject_name', 'day_of_week', 'start_time', 'end_time', 'slot_type']
              }
            }
          },
          required: ['slots']
        }
      }
    });

    const text = response.text;
    if (!text) return res.status(500).json({ error: 'Failed to extract data via OCR.' });

    const cleanedText = text.replace(/^```json\n?/, '').replace(/\n?```$/, '').trim();
    return res.json(JSON.parse(cleanedText));
  } catch (e: any) {
    console.error('Gemini OCR Error:', e);
    return res.status(500).json({ error: 'Failed to process image through AI OCR.' });
  }
});

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
      slots: Array<{ subject_name: string; teacher?: string; day_of_week: DayOfWeek; start_time: string; end_time: string; room?: string; slot_type?: string }>;
    };

    // Upsert subjects by name — return id map
    const subjectNames = [...new Set(slots.map((s) => s.subject_name))];
    const subjectMap: Record<string, string> = {};

    for (const name of subjectNames) {
      const match = slots.find(s => s.subject_name === name && s.teacher);
      const teacher = match?.teacher ?? null;

      const subject = await prisma.subject.upsert({
        where: { userId_name: { userId, name } },
        create: { userId, name, teacher },
        update: { ...(teacher && { teacher }) },
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

  // Transform to snake_case so the Flutter client can read all fields correctly
  const result = slots.map((s) => ({
    id:          s.id,
    user_id:     s.userId,
    subject_id:  s.subjectId,
    day_of_week: s.dayOfWeek,   // enum → 'monday' | 'tuesday' …
    start_time:  s.startTime,
    end_time:    s.endTime,
    room:        s.room,
    slot_type:   s.slotType,
    created_at:  s.createdAt,
    subject: {
      name:      s.subject.name,
      code:      s.subject.code,
      color_hex: s.subject.colorHex,
      teacher:   s.subject.teacher,
    },
  }));

  return res.json(result);
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
  const userId = req.userId!;

  // Get all slots for the user with their attendance logs
  const slots = await prisma.timetableSlot.findMany({
    where: { userId },
    include: {
      subject: { select: { name: true, teacher: true, colorHex: true } },
      attendanceLogs: { select: { status: true } },
    },
  });

  // Aggregate per subject
  const subjectMap: Record<string, {
    subject_name: string; teacher: string | null; color_hex: string;
    total: number; present: number; absent: number; cancelled: number;
  }> = {};

  for (const slot of slots) {
    const name = slot.subject.name;
    if (!subjectMap[name]) {
      subjectMap[name] = {
        subject_name: name,
        teacher: slot.subject.teacher,
        color_hex: slot.subject.colorHex,
        total: 0, present: 0, absent: 0, cancelled: 0,
      };
    }
    for (const log of slot.attendanceLogs) {
      subjectMap[name].total++;
      if (log.status === 'present')   subjectMap[name].present++;
      if (log.status === 'absent')    subjectMap[name].absent++;
      if (log.status === 'cancelled') subjectMap[name].cancelled++;
    }
  }

  const result = Object.values(subjectMap).map((s) => ({
    ...s,
    attendance_pct: s.total > 0 ? Math.round((s.present / s.total) * 100) : null,
    // 75% rule: need to attend at least 75% → can bunk floor((total * 0.25)) more
    can_bunk: s.total > 0
      ? Math.max(0, Math.floor(s.present / 0.75) - s.total)
      : null,
    needs_to_attend: s.total > 0 && (s.present / s.total) < 0.75
      ? Math.ceil((0.75 * s.total - s.present) / 0.25)
      : 0,
  }));

  return res.json(result);
});

export default router;
