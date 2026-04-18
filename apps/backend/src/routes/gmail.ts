import { Router } from 'express';
import { body, validationResult } from 'express-validator';
import { prisma } from '../config/prisma';
import { requireAuth, AuthRequest } from '../middleware/auth';
import { google } from 'googleapis';
import { StressLevel, EventSource } from '@prisma/client';

const router = Router();

const ACADEMIC_KEYWORDS = [
  'assignment','submission','deadline','exam','quiz','test','viva','project',
  'due','marks','grade','internal','external','practical','lab report',
  'attendance','re-exam','supplementary','result','admit card','hall ticket',
  'project submission','term paper','report due','final exam','mid-term',
  'mid sem','end sem','semester exam','lab exam','practical exam',
];

const STRESS_ORDER: StressLevel[] = ['low','medium','high','critical'];

function classifyStressLevel(keywords: string[], daysUntilEvent: number): StressLevel {
  const keywordScore = keywords.length;
  if (daysUntilEvent <= 1 && keywordScore >= 2) return 'critical';
  if (daysUntilEvent <= 1) return 'high';
  if (daysUntilEvent <= 3 || keywordScore >= 3) return 'high';
  if (daysUntilEvent <= 7 || keywordScore >= 1) return 'medium';
  return 'low';
}

function getOAuthClient() {
  return new google.auth.OAuth2(
    process.env.GOOGLE_CLIENT_ID,
    process.env.GOOGLE_CLIENT_SECRET,
    process.env.GOOGLE_REDIRECT_URI ?? 'urn:ietf:wg:oauth:2.0:oob'
  );
}

// ─────────────────────────────────────────────────────────────
// GET /api/gmail/auth-url — Generate Google OAuth URL
// ─────────────────────────────────────────────────────────────
router.get('/auth-url', requireAuth, (req: AuthRequest, res) => {
  const oAuth2Client = getOAuthClient();
  const url = oAuth2Client.generateAuthUrl({
    access_type: 'offline',
    scope: [
      'https://www.googleapis.com/auth/gmail.readonly',
      'https://www.googleapis.com/auth/calendar.readonly',
    ],
    prompt: 'consent',
  });
  return res.json({ url });
});

// ─────────────────────────────────────────────────────────────
// POST /api/gmail/sync — Use access_token to scan Gmail + GCal
// ─────────────────────────────────────────────────────────────
router.post(
  '/sync',
  requireAuth,
  body('access_token').isString().notEmpty(),
  async (req: AuthRequest, res) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) return res.status(422).json({ errors: errors.array() });

    const { access_token } = req.body as { access_token: string };
    console.log('[Gmail Sync] Token prefix:', access_token?.slice(0, 20));

    const auth = new google.auth.OAuth2();
    auth.setCredentials({ access_token });

    const gmail = google.gmail({ version: 'v1', auth });
    const calendar = google.calendar({ version: 'v3', auth });
    const userId = req.userId!;

    // Ensure profile exists
    await prisma.profile.upsert({
      where: { id: userId },
      create: { id: userId, displayName: 'Lumina User' },
      update: {},
    });

    const events: any[] = [];
    const debugLog: string[] = [];

    // === Scan Gmail ===
    try {
      const keywordQuery = ACADEMIC_KEYWORDS.slice(0, 8).join(' OR ');
      const { data: gmailData } = await gmail.users.messages.list({
        userId: 'me',
        q: `${keywordQuery} newer_than:30d`,
        maxResults: 50,
      });
      const msgCount = gmailData.messages?.length ?? 0;
      debugLog.push(`Gmail: found ${msgCount} messages matching keywords`);
      console.log('[Gmail Sync] Gmail messages found:', msgCount);

      for (const msg of gmailData.messages ?? []) {
        const { data: full } = await gmail.users.messages.get({
          userId: 'me', id: msg.id!, format: 'metadata',
          metadataHeaders: ['Subject', 'Date'],
        });
        const subject = full.payload?.headers?.find((h) => h.name === 'Subject')?.value ?? '';
        const dateStr = full.payload?.headers?.find((h) => h.name === 'Date')?.value ?? '';
        const found = ACADEMIC_KEYWORDS.filter((k) => subject.toLowerCase().includes(k));
        if (found.length === 0) continue;

        const eventDate = new Date(dateStr);
        if (isNaN(eventDate.getTime())) continue;
        const daysUntil = Math.ceil((eventDate.getTime() - Date.now()) / 86400000);

        events.push({
          userId, title: subject.slice(0, 200),
          eventDate, stressLevel: classifyStressLevel(found, daysUntil),
          source: 'gmail' as EventSource, externalId: msg.id!,
          keywords: found,
        });
      }
      debugLog.push(`Gmail: saved ${events.filter(e => e.source === 'gmail').length} events`);
    } catch (e: any) {
      const msg = e?.message ?? String(e);
      debugLog.push(`Gmail ERROR: ${msg}`);
      console.error('[Gmail Sync] Gmail error:', msg);
    }

    // === Sync Google Calendar ===
    const calStart = events.length;
    try {
      const timeMin = new Date(Date.now() - 7 * 86400000).toISOString();
      const timeMax = new Date(Date.now() + 90 * 86400000).toISOString();
      console.log('[Gmail Sync] Fetching GCal events from', timeMin, 'to', timeMax);

      const { data: calData } = await calendar.events.list({
        calendarId: 'primary',
        timeMin, timeMax,
        maxResults: 250, singleEvents: true, orderBy: 'startTime',
      });

      const calCount = calData.items?.length ?? 0;
      debugLog.push(`GCal: fetched ${calCount} raw events`);
      console.log('[Gmail Sync] GCal raw events:', calCount);

      for (const event of calData.items ?? []) {
        const title = event.summary ?? 'Untitled';
        const found = ACADEMIC_KEYWORDS.filter((k) => title.toLowerCase().includes(k));
        const start = event.start?.date ?? event.start?.dateTime ?? '';
        if (!start) continue;

        const daysUntil = Math.ceil((new Date(start).getTime() - Date.now()) / 86400000);
        // Save ALL calendar events (not just keyword-matched)
        const stressLevel = found.length > 0
          ? classifyStressLevel(found, daysUntil)
          : daysUntil <= 2 ? 'high' : daysUntil <= 7 ? 'medium' : 'low';

        events.push({
          userId, title: title.slice(0, 200),
          description: event.description?.slice(0, 500),
          eventDate: new Date(start.split('T')[0]),
          startTime: event.start?.dateTime ? start.split('T')[1]?.slice(0, 5) : null,
          endTime: event.end?.dateTime ? event.end.dateTime!.split('T')[1]?.slice(0, 5) : null,
          stressLevel, source: 'gcal' as EventSource,
          externalId: event.id!, keywords: found,
        });
      }
      debugLog.push(`GCal: saving ${events.length - calStart} events`);
    } catch (e: any) {
      const msg = e?.message ?? String(e);
      debugLog.push(`GCal ERROR: ${msg}`);
      console.error('[Gmail Sync] GCal error:', msg);
    }

    // Upsert all events
    let saved = 0;
    for (const ev of events) {
      try {
        await prisma.calendarEvent.upsert({
          where: { userId_externalId: { userId, externalId: ev.externalId } },
          create: ev,
          update: { stressLevel: ev.stressLevel, keywords: ev.keywords ?? [], title: ev.title },
        });
        saved++;
      } catch (e: any) {
        console.error('[Gmail Sync] Upsert error:', e?.message);
      }
    }

    console.log('[Gmail Sync] Done. Saved:', saved, 'of', events.length);
    return res.json({ synced: saved, found: events.length, debug: debugLog });
  }
);


// ─────────────────────────────────────────────────────────────
// POST /api/gmail/manual — Save manual calendar event
// ─────────────────────────────────────────────────────────────
router.post(
  '/manual',
  requireAuth,
  body('title').isString().trim().notEmpty(),
  body('event_date').isISO8601(),
  body('stress_level').isIn(['low','medium','high','critical']),
  async (req: AuthRequest, res) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) return res.status(422).json({ error: errors.array()[0].msg });

    const { title, event_date, stress_level, description, keywords } = req.body as {
      title: string; event_date: string; stress_level: StressLevel;
      description?: string; keywords?: string[];
    };
    const userId = req.userId!;

    await prisma.profile.upsert({
      where: { id: userId },
      create: { id: userId, displayName: 'Lumina User' },
      update: {},
    });

    const ev = await prisma.calendarEvent.create({
      data: {
        userId, title, description,
        eventDate: new Date(event_date),
        stressLevel: stress_level,
        source: 'manual',
        keywords: keywords ?? [],
      },
    });

    return res.status(201).json(ev);
  }
);

// ─────────────────────────────────────────────────────────────
// GET /api/gmail/heatmap?year=2024&month=11
// ─────────────────────────────────────────────────────────────
router.get('/heatmap', requireAuth, async (req: AuthRequest, res) => {
  const userId = req.userId!;

  await prisma.profile.upsert({
    where: { id: userId },
    create: { id: userId, displayName: 'Lumina User' },
    update: {},
  });

  const now = new Date();
  // 6 months back → 6 months forward (full 12-month window, UTC)
  const startDate = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth() - 6, 1));
  const endDate   = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth() + 7, 1, 0, 0, 0, -1));

  const events = await prisma.calendarEvent.findMany({
    where: { userId, eventDate: { gte: startDate, lte: endDate } },
    select: { eventDate: true, stressLevel: true, title: true, keywords: true, id: true, source: true },
    orderBy: { eventDate: 'asc' },
  });

  console.log(`[Heatmap] 12-month: ${events.length} events (${startDate.toISOString().split('T')[0]} → ${endDate.toISOString().split('T')[0]})`);

  // Group by YYYY-MM-DD, worst stress level per day
  const heatmap: Record<string, { level: string; events: any[] }> = {};
  for (const ev of events) {
    const dateKey = ev.eventDate.toISOString().split('T')[0];
    const cur = heatmap[dateKey];
    const evIdx = STRESS_ORDER.indexOf(ev.stressLevel);
    if (!cur || evIdx > STRESS_ORDER.indexOf(cur.level as StressLevel)) {
      heatmap[dateKey] = { level: ev.stressLevel, events: [] };
    }
    heatmap[dateKey].events.push({ title: ev.title, keywords: ev.keywords, source: ev.source });
  }

  return res.json(heatmap);
});


// DELETE /api/gmail/event/:id
router.delete('/event/:id', requireAuth, async (req: AuthRequest, res) => {
  await prisma.calendarEvent.deleteMany({
    where: { id: req.params.id, userId: req.userId! },
  });
  return res.status(204).send();
});

export default router;
