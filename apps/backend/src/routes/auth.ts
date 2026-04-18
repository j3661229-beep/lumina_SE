import { Router, Request, Response } from 'express';
import { createClient } from '@supabase/supabase-js';
import { body, validationResult } from 'express-validator';
import { prisma } from '../config/prisma';
import { requireAuth, AuthRequest } from '../middleware/auth';

const router = Router();

// Anon client — for sign-in proxy
const anonSupabase = createClient(
  process.env.SUPABASE_URL!,
  process.env.SUPABASE_ANON_KEY!
);

// Admin client (service role) — auto-confirms users on register
const adminSupabase = createClient(
  process.env.SUPABASE_URL!,
  process.env.SUPABASE_SERVICE_KEY!,
  { auth: { autoRefreshToken: false, persistSession: false } }
);

// ─────────────────────────────────────────────────────────────────────────────
// POST /api/auth/signin — proxy sign-in (college WiFi fallback)
// ─────────────────────────────────────────────────────────────────────────────
router.post(
  '/signin',
  [
    body('email').isEmail().withMessage('Valid email required'),
    body('password').notEmpty().withMessage('Password required'),
  ],
  async (req: Request, res: Response) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) return res.status(400).json({ error: errors.array()[0].msg });

    const { email, password } = req.body as { email: string; password: string };
    const { data, error } = await anonSupabase.auth.signInWithPassword({ email, password });

    if (error) {
      if (error.message.includes('Invalid login credentials'))
        return res.status(401).json({ error: 'Wrong email or password.' });
      if (error.message.includes('Email not confirmed'))
        return res.status(403).json({ error: 'Email not confirmed.' });
      return res.status(400).json({ error: error.message });
    }

    return res.json({
      accessToken: data.session!.access_token,
      refreshToken: data.session!.refresh_token,
      expiresAt: data.session!.expires_at,
      user: {
        id: data.user!.id,
        email: data.user!.email,
        displayName: data.user!.user_metadata?.display_name ?? data.user!.email?.split('@')[0],
      },
    });
  }
);

// ─────────────────────────────────────────────────────────────────────────────
// POST /api/auth/register — creates user with email auto-confirmed
// ─────────────────────────────────────────────────────────────────────────────
router.post(
  '/register',
  [
    body('email').isEmail().withMessage('Valid email required'),
    body('password').isLength({ min: 6 }).withMessage('Password must be at least 6 characters'),
  ],
  async (req: Request, res: Response) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) return res.status(400).json({ error: errors.array()[0].msg });

    const { email, password, displayName } = req.body as {
      email: string; password: string; displayName?: string;
    };

    const { data, error } = await adminSupabase.auth.admin.createUser({
      email,
      password,
      email_confirm: true,
      user_metadata: { display_name: displayName || email.split('@')[0] },
    });

    if (error) {
      if (error.message.includes('already been registered') || error.message.includes('already exists'))
        return res.status(409).json({ error: 'Email already registered. Please sign in instead.' });
      return res.status(400).json({ error: error.message });
    }

    const { data: signInData, error: signInError } = await anonSupabase.auth.signInWithPassword({
      email, password
    });

    if (signInError || !signInData.session) {
      return res.status(201).json({
        message: 'Account created. Please sign in.',
        userId: data.user.id,
      });
    }

    return res.status(201).json({
      message: 'Account created successfully',
      accessToken: signInData.session.access_token,
      refreshToken: signInData.session.refresh_token,
      expiresAt: signInData.session.expires_at,
      user: {
        id: data.user.id,
        email: data.user.email,
        displayName: displayName || email.split('@')[0],
      },
    });
  }
);

// ─────────────────────────────────────────────────────────────────────────────
// POST /api/auth/confirm-user  (utility)
// ─────────────────────────────────────────────────────────────────────────────
router.post('/confirm-user', async (req: Request, res: Response) => {
  const { email } = req.body as { email: string };
  if (!email) return res.status(400).json({ error: 'Email required' });

  const { data: list } = await adminSupabase.auth.admin.listUsers();
  const user = list?.users?.find((u) => u.email === email);
  if (!user) return res.status(404).json({ error: 'User not found' });

  const { error } = await adminSupabase.auth.admin.updateUserById(user.id, {
    email_confirm: true,
  });

  if (error) return res.status(500).json({ error: error.message });
  return res.json({ message: `${email} confirmed successfully` });
});

// ─────────────────────────────────────────────────────────────────────────────
// POST /api/auth/ensure-profile
// Called after ANY sign-in (email or Google OAuth).
// Upserts Profile row in Prisma so FK references never break.
// ─────────────────────────────────────────────────────────────────────────────
router.post('/ensure-profile', requireAuth, async (req: AuthRequest, res) => {
  const userId = req.userId!;

  // Fetch user metadata from Supabase admin
  const { data: { user } } = await adminSupabase.auth.admin.getUserById(userId);

  const displayName =
    (user?.user_metadata?.display_name as string | undefined) ||
    (user?.user_metadata?.full_name as string | undefined) ||
    user?.email?.split('@')[0] ||
    'Lumina User';

  await prisma.profile.upsert({
    where: { id: userId },
    create: { id: userId, displayName },
    update: { displayName },
  });

  return res.json({ ok: true, displayName });
});

export default router;
