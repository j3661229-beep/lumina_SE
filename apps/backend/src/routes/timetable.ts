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
    const profile = await prisma.profile.findUnique({
      where: { id: req.userId! },
      select: { batch: true }
    });
    const batchCode = profile?.batch ?? 'A'; // Default to A if not set
    const batchLetter = batchCode.replace(/[^A-D]/g, '') || 'A';
    // If user's batch is "A", we just want "A".


    console.log(`[OCR] Sending to Gemini... Batch configured: ${batchCode} (Letter: ${batchLetter})`);

    const promptText = `Extract the class timetable from the provided image. The user's batch is "${batchLetter}".
Follow these rules strictly:
1. The timetable contains both LECTURES (single-line cells) and LABS (multi-line cells spanning 2 hours).
2. For LECTURE slots (cells with a single entry like "DAA / PBB / 508"): Extract them normally. They apply to all batches.
3. For LAB slots (cells containing multiple stacked entries for different batches, e.g., "OS / A / AN / 509", "DAA / B / SND / 604"): 
   - Parse all the stacked lines in that time block.
   - ONLY extract the specific line where the batch letter (the second item, e.g., "B" in "OS / B /...") matches the user's batch "${batchLetter}". 
   - Ignore the lines for other batches.
   - For this extracted lab, ensure the slot_type is "lab" and its duration covers the entire 2-hour block (e.g., start_time: 11:15, end_time: 13:15).
4. Format: Identify the subject name, the assigned teacher (if available), the day of the week (lowercase long format like "monday"), the start time (HH:mm 24-hr format), the end time (HH:mm 24-hr format), and room number (if available).
5. Extract "holidays" or "vacation dates" if mentioned in the document. For holidays, extract the "date" (YYYY-MM-DD) and a "name".
6. Ignore blank slots, short breaks, recess, or lunch.`;

    const response = await ai.models.generateContent({
      model: 'gemini-2.5-flash-lite',
      contents: [
        {
          role: 'user',
          parts: [
            { text: promptText },
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
            },
            holidays: {
              type: Type.ARRAY,
              items: {
                type: Type.OBJECT,
                properties: {
                  name: { type: Type.STRING },
                  date: { type: Type.STRING, description: "YYYY-MM-DD" }
                },
                required: ['name', 'date']
              }
            }
          },
          required: ['slots', 'holidays']
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
    const { slots, holidays, semester_start, semester_end } = req.body as {
      slots: Array<{ subject_name: string; teacher?: string; day_of_week: DayOfWeek; start_time: string; end_time: string; room?: string; slot_type?: string }>;
      holidays?: Array<{ name: string; date: string }>;
      semester_start?: string;
      semester_end?: string;
    };

    // Update Profile with semester dates
    if (semester_start || semester_end) {
      await prisma.profile.update({
        where: { id: userId },
        data: {
          semesterStart: semester_start ? new Date(semester_start) : undefined,
          semesterEnd: semester_end ? new Date(semester_end) : undefined,
        }
      });
    }

    // Save holidays (deduplicate by date to avoid P2002)
    if (holidays && holidays.length > 0) {
      await prisma.holiday.deleteMany({ where: { userId } });
      
      const uniqueHolidays: any[] = [];
      const seenDates = new Set<string>();
      
      for (const h of holidays) {
        try {
          const d = new Date(h.date);
          const ISOString = d.toISOString().split('T')[0];
          if (!seenDates.has(ISOString)) {
            seenDates.add(ISOString);
            uniqueHolidays.push(h);
          }
        } catch (_) { /* Skip invalid dates */ }
      }

      await prisma.holiday.createMany({
        data: uniqueHolidays.map(h => ({
          userId,
          name: h.name,
          date: new Date(h.date)
        }))
      });
    }

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

    // Process slots sequentially to avoid connection pool timeouts (Prisma P2024)
    const inserted = [];
    for (const s of slots) {
      const slot = await prisma.timetableSlot.upsert({
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
      });
      inserted.push(slot);
    }

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
    id: s.id,
    user_id: s.userId,
    subject_id: s.subjectId,
    day_of_week: s.dayOfWeek,   // enum → 'monday' | 'tuesday' …
    start_time: s.startTime,
    end_time: s.endTime,
    room: s.room,
    slot_type: s.slotType,
    created_at: s.createdAt,
    subject: {
      name: s.subject.name,
      code: s.subject.code,
      color_hex: s.subject.colorHex,
      teacher: s.subject.teacher,
    },
  }));

  return res.json(result);
});

// ─────────────────────────────────────────────────────────────
// PUT /api/timetable/slots/:id — Update individual slot
// ─────────────────────────────────────────────────────────────
router.put(
  '/slots/:id',
  requireAuth,
  body('subject_name').isString().trim().notEmpty(),
  body('day_of_week').isIn(Object.values(DayOfWeek)),
  body('start_time').matches(/^\d{2}:\d{2}$/),
  body('end_time').matches(/^\d{2}:\d{2}$/),
  async (req: AuthRequest, res) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) return res.status(422).json({ errors: errors.array() });

    const userId = req.userId!;
    const slotId = req.params.id;
    const { subject_name, day_of_week, start_time, end_time, room, slot_type } = req.body;

    // Ensure slot belongs to user
    const existing = await prisma.timetableSlot.findFirst({
      where: { id: slotId, userId }
    });
    if (!existing) return res.status(404).json({ error: 'Slot not found' });

    // Upsert subject
    const subject = await prisma.subject.upsert({
      where: { userId_name: { userId, name: subject_name } },
      create: { userId, name: subject_name },
      update: {},
      select: { id: true },
    });

    const updated = await prisma.timetableSlot.update({
      where: { id: slotId },
      data: {
        subjectId: subject.id,
        dayOfWeek: day_of_week,
        startTime: start_time,
        endTime: end_time,
        room: room ?? null,
        slotType: slot_type ?? 'lecture',
      }
    });

    return res.json(updated);
  }
);

// ─────────────────────────────────────────────────────────────
// DELETE /api/timetable/slots/:id — Delete individual slot
// ─────────────────────────────────────────────────────────────
router.delete('/slots/:id', requireAuth, async (req: AuthRequest, res) => {
  const userId = req.userId!;
  const slotId = req.params.id;

  const existing = await prisma.timetableSlot.findFirst({
    where: { id: slotId, userId }
  });
  if (!existing) return res.status(404).json({ error: 'Slot not found' });

  await prisma.timetableSlot.delete({
    where: { id: slotId }
  });

  return res.json({ message: 'Slot deleted successfully.' });
});

// ─────────────────────────────────────────────────────────────
// GET /api/timetable/attendance — Fetch all attendance logs
// ─────────────────────────────────────────────────────────────
router.get('/attendance', requireAuth, async (req: AuthRequest, res) => {
  const logs = await prisma.attendanceLog.findMany({
    where: { userId: req.userId! },
    select: { slotId: true, date: true, status: true }
  });
  return res.json(logs);
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

  const profile = await prisma.profile.findUnique({
    where: { id: userId },
    select: { semesterStart: true, semesterEnd: true }
  });

  const slots = await prisma.timetableSlot.findMany({
    where: { userId },
    include: {
      subject: { select: { name: true, teacher: true, colorHex: true } },
      attendanceLogs: { select: { status: true, date: true } },
    },
  });

  const holidays = await prisma.holiday.findMany({
    where: { userId },
    select: { date: true }
  });
  const holidaySet = new Set(holidays.map(h => h.date.toISOString().split('T')[0]));

  const result = slots.map(slot => {
    const presentCount = slot.attendanceLogs.filter(l => l.status === 'present').length;
    const absentCount = slot.attendanceLogs.filter(l => l.status === 'absent').length;
    const cancelledCount = slot.attendanceLogs.filter(l => l.status === 'cancelled').length;
    const totalHeld = presentCount + absentCount + cancelledCount;

    // Projection logic
    let totalPlanned = totalHeld;
    if (profile?.semesterStart && profile?.semesterEnd) {
      const now = new Date();
      const end = new Date(profile.semesterEnd);
      
      const dayMap: Record<DayOfWeek, number> = {
        'monday': 1, 'tuesday': 2, 'wednesday': 3, 'thursday': 4, 'friday': 5, 'saturday': 6, 'sunday': 0
      };
      const targetDay = dayMap[slot.dayOfWeek];

      let current = new Date(now);
      current.setHours(0,0,0,0);
      current.setDate(current.getDate() + 1); // Start projecting from tomorrow
      end.setHours(23,59,59,999);

      while (current <= end) {
        if (current.getDay() === targetDay) {
          const dateStr = current.toISOString().split('T')[0];
          if (!holidaySet.has(dateStr)) {
            totalPlanned++;
          }
        }
        current.setDate(current.getDate() + 1);
      }
    }

    return {
      subject_name: slot.subject.name,
      teacher: slot.subject.teacher,
      color_hex: slot.subject.colorHex,
      attended: presentCount,
      absent: absentCount,
      total_held: totalHeld,
      total_planned: totalPlanned,
      percentage: totalHeld > 0 ? Math.round((presentCount / totalHeld) * 100) : 0,
      bunks_remaining: Math.max(0, Math.floor(presentCount / 0.75) - totalPlanned)
    };
  });

  const grouped: Record<string, any> = {};
  for (const r of result) {
    if (!grouped[r.subject_name]) {
      grouped[r.subject_name] = { ...r };
    } else {
      grouped[r.subject_name].attended += r.attended;
      grouped[r.subject_name].absent += r.absent;
      grouped[r.subject_name].total_held += r.total_held;
      grouped[r.subject_name].total_planned += r.total_planned;
      const g = grouped[r.subject_name];
      g.percentage = g.total_held > 0 ? Math.round((g.attended / g.total_held) * 100) : 0;
      g.bunks_remaining = Math.max(0, Math.floor(g.attended / 0.75) - g.total_planned);
    }
  }

  return res.json(Object.values(grouped));
});

// ─────────────────────────────────────────────────────────────
// POST /api/timetable/generate — Deterministic Auto-Generation
// ─────────────────────────────────────────────────────────────
router.post('/generate', requireAuth, body('division').isString(), body('batch').isString(), async (req: AuthRequest, res) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) return res.status(422).json({ errors: errors.array() });

  const { division, batch } = req.body;
  const userId = req.userId!;

  // 1. Clear old timetable & subjects
  await prisma.subject.deleteMany({ where: { userId } });

  // 2. Mock template subjects based on div
  const subjDB = await prisma.subject.createManyAndReturn({
    data: [
      { userId, name: 'Data Structures', code: 'CS201', teacher: 'Prof. Smith', colorHex: '#EF4444' },
      { userId, name: 'Algorithms', code: 'CS202', teacher: 'Prof. Doe', colorHex: '#F59E0B' },
      { userId, name: 'Database Systems', code: 'CS203', teacher: 'Prof. Lee', colorHex: '#10B981' },
      { userId, name: 'Operating Systems', code: 'CS204', teacher: 'Prof. Turing', colorHex: '#6366F1' },
      { userId, name: 'Computer Networks', code: 'CS205', teacher: 'Prof. Cerf', colorHex: '#8B5CF6' }
    ]
  });

  // 3. Generate slots based on batch
  const isA = batch.startsWith('A');
  const d = subjDB;

  const slotsData = [];
  const days: DayOfWeek[] = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday'];

  for (let i = 0; i < days.length; i++) {
    // 2 lectures per day
    slotsData.push({
      userId,
      subjectId: d[i % d.length].id,
      dayOfWeek: days[i],
      startTime: isA ? '09:00' : '10:00',
      endTime: isA ? '10:00' : '11:00',
      room: `Room ${101 + i}`,
      slotType: 'lecture'
    });
    slotsData.push({
      userId,
      subjectId: d[(i + 1) % d.length].id,
      dayOfWeek: days[i],
      startTime: isA ? '10:00' : '11:00',
      endTime: isA ? '11:00' : '12:00',
      room: `Room ${101 + i}`,
      slotType: 'lecture'
    });
  }

  // Lab session
  slotsData.push({
    userId,
    subjectId: d[2].id,
    dayOfWeek: isA ? 'monday' : 'wednesday',
    startTime: '13:00',
    endTime: '15:00',
    room: 'Lab 3',
    slotType: 'lab'
  });

  await prisma.timetableSlot.createMany({ data: slotsData });

  return res.json({ message: 'Timetable auto-generated successfully.' });
});

export default router;
