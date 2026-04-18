import { Router } from 'express';
import { prisma } from '../config/prisma';
import { requireAuth, AuthRequest } from '../middleware/auth';

const router = Router();

// ─────────────────────────────────────────────────────────────
// POST /api/demo/seed
// Automatically populates the current user's account with rich dummy data
// to demonstrate the AI Timetable, Attendance Engine, and Context Switch Debt.
// ─────────────────────────────────────────────────────────────
router.post('/seed', requireAuth, async (req: AuthRequest, res) => {
  const userId = req.userId!;

  // 1. Wipe existing data for clean slate
  await prisma.attendanceLog.deleteMany({ where: { userId } });
  await prisma.timetableSlot.deleteMany({ where: { userId } });
  await prisma.subject.deleteMany({ where: { userId } });
  await prisma.contextSwitchLog.deleteMany({ where: { userId } });
  await prisma.cognitiveDebtScore.deleteMany({ where: { userId } });
  await prisma.studySquadScore.deleteMany({ where: { profileId: userId } });
  await prisma.studySquadMember.deleteMany({ where: { profileId: userId } });

  // 2. Timetable & Attendance Engine (Setup exactly at ~75% threshold)
  const subjects = await prisma.subject.createManyAndReturn({
    data: [
      { userId, name: 'Data Structures', code: 'CS201', teacher: 'Prof. Smith', colorHex: '#EF4444' },
      { userId, name: 'Operating Systems', code: 'CS204', teacher: 'Prof. Turing', colorHex: '#6366F1' },
      { userId, name: 'Computer Networks', code: 'CS205', teacher: 'Prof. Cerf', colorHex: '#10B981' }
    ]
  });

  const slots = await prisma.timetableSlot.createManyAndReturn({
    data: [
      { userId, subjectId: subjects[0].id, dayOfWeek: 'monday', startTime: '09:00', endTime: '10:00', room: '101', slotType: 'lecture' },
      { userId, subjectId: subjects[1].id, dayOfWeek: 'monday', startTime: '11:00', endTime: '13:00', room: 'Lab 2', slotType: 'lab' },
      { userId, subjectId: subjects[2].id, dayOfWeek: 'tuesday', startTime: '10:00', endTime: '11:00', room: '204', slotType: 'lecture' },
      { userId, subjectId: subjects[0].id, dayOfWeek: 'wednesday', startTime: '09:00', endTime: '10:00', room: '101', slotType: 'lecture' },
      { userId, subjectId: subjects[1].id, dayOfWeek: 'thursday', startTime: '11:00', endTime: '12:00', room: '305', slotType: 'lecture' },
    ]
  });

  // Generate 4 weeks of past attendance
  const attendanceData = [];
  const now = new Date();
  for (let i = 28; i >= 0; i--) {
    const d = new Date(now);
    d.setDate(d.getDate() - i);
    const dayStr = ['sunday', 'monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday'][d.getDay()];
    
    const daySlots = slots.filter(s => s.dayOfWeek === dayStr);
    for (const s of daySlots) {
      // 75% attendance probability
      const status = Math.random() < 0.75 ? 'present' : 'absent';
      attendanceData.push({
        userId,
        slotId: s.id,
        date: d,
        status,
        synced: true
      });
    }
  }
  await prisma.attendanceLog.createMany({ data: attendanceData });

  // 3. Context Switch Data: "You said you were studying. Your phone disagrees."
  // Generate high cognitive debt for the past 7 days (oscillating between focus and distraction apps)
  const debtData = [];
  const switchLogs = [];
  const focusApps = ['Visual Studio Code', 'Notion', 'Chrome (StackOverflow)', 'Lumina'];
  const distApps = ['Instagram', 'WhatsApp', 'YouTube', 'TikTok'];

  for (let i = 6; i >= 0; i--) {
    const d = new Date(now);
    d.setHours(0, 0, 0, 0);
    d.setDate(d.getDate() - i);

    // Some days high debt, some days low debt
    const baseScore = i === 0 ? 82.5 : (30 + Math.random() * 60); // High debt today
    debtData.push({
      userId,
      windowDate: new Date(d),
      score: baseScore,
      computedAt: new Date(d.getTime() + 1000 * 60 * 60 * 20), // 8 PM
    });

    // Make lots of rapid 30-sec app switches for today to justify it
    if (i === 0) {
      let t = new Date(now.getTime() - 1000 * 60 * 60 * 3); // 3 hours ago
      for (let j = 0; j < 40; j++) {
        const app = j % 3 === 0 ? focusApps[0] : distApps[j % distApps.length];
        const durationMin = j % 3 === 0 ? 5 : 0.5; // Focus longer, distract shorter (rapid switches)
        const tEnd = new Date(t.getTime() + durationMin * 60000);
        switchLogs.push({
          userId,
          appName: app,
          packageName: `com.app.${app.toLowerCase()}`,
          sessionStart: new Date(t),
          sessionEnd: new Date(tEnd),
        });
        t = new Date(tEnd.getTime() + 1000 * 10); // 10 seconds empty
      }
    }
  }

  await prisma.contextSwitchLog.createMany({ data: switchLogs });
  await prisma.cognitiveDebtScore.createMany({ data: debtData });

  return res.json({ message: 'Lumina demo data seeded perfectly.' });
});

export default router;
