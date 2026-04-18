import { Router } from 'express';
import { body, validationResult } from 'express-validator';
import { prisma } from '../config/prisma';
import { requireAuth, AuthRequest } from '../middleware/auth';
import { ExpenseCategory } from '@prisma/client';

const router = Router();

async function ensureProfile(userId: string) {
  await prisma.profile.upsert({
    where: { id: userId },
    create: { id: userId, displayName: 'Lumina User' },
    update: {},
  });
}

// ─────────────────────────────────────────────────────────────
// POST /api/expenses
// ─────────────────────────────────────────────────────────────
router.post(
  '/',
  requireAuth,
  body('amount').isFloat({ min: 0.01 }),
  body('category').isIn(Object.values(ExpenseCategory)),
  body('description').optional().isString().trim(),
  body('expense_date').optional().isISO8601(),
  async (req: AuthRequest, res) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) return res.status(422).json({ errors: errors.array() });

    const { amount, category, description, expense_date } = req.body as {
      amount: number; category: ExpenseCategory; description?: string; expense_date?: string;
    };

    await ensureProfile(req.userId!);

    const expense = await prisma.expense.create({
      data: {
        userId: req.userId!,
        amount,
        category,
        description,
        expenseDate: expense_date ? new Date(expense_date) : new Date(),
      },
    });

    return res.status(201).json(expense);
  }
);

// ─────────────────────────────────────────────────────────────
// GET /api/expenses?from=YYYY-MM-DD&to=YYYY-MM-DD
// ─────────────────────────────────────────────────────────────
router.get('/', requireAuth, async (req: AuthRequest, res) => {
  await ensureProfile(req.userId!);
  const { from, to } = req.query as { from?: string; to?: string };

  const expenses = await prisma.expense.findMany({
    where: {
      userId: req.userId!,
      expenseDate: {
        ...(from && { gte: new Date(from) }),
        ...(to && { lte: new Date(to) }),
      },
    },
    orderBy: { expenseDate: 'desc' },
  });

  return res.json(expenses);
});

// ─────────────────────────────────────────────────────────────
// GET /api/expenses/weekly-wrap — Last 8 weeks summary
// ─────────────────────────────────────────────────────────────
router.get('/weekly-wrap', requireAuth, async (req: AuthRequest, res) => {
  const data = await prisma.$queryRaw`
    SELECT 
      date_trunc('week', expense_date) AS week_start,
      category,
      SUM(amount) AS total
    FROM public.expenses
    WHERE user_id = ${req.userId!}::uuid
    GROUP BY date_trunc('week', expense_date), category
    ORDER BY week_start DESC
  `;
  return res.json(data);
});

// ─────────────────────────────────────────────────────────────
// PUT /api/expenses/:id
// ─────────────────────────────────────────────────────────────
router.put(
  '/:id',
  requireAuth,
  body('amount').optional().isFloat({ min: 0.01 }),
  body('category').optional().isIn(Object.values(ExpenseCategory)),
  async (req: AuthRequest, res) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) return res.status(422).json({ errors: errors.array() });

    const { amount, category, description, expense_date } = req.body;

    const expense = await prisma.expense.updateMany({
      where: { id: req.params.id, userId: req.userId! },
      data: {
        ...(amount !== undefined && { amount }),
        ...(category && { category }),
        ...(description !== undefined && { description }),
        ...(expense_date && { expenseDate: new Date(expense_date) }),
      },
    });

    if (expense.count === 0) {
      return res.status(404).json({ error: 'Expense not found' });
    }

    const updated = await prisma.expense.findFirst({
      where: { id: req.params.id, userId: req.userId! },
    });
    return res.json(updated);
  }
);

// ─────────────────────────────────────────────────────────────
// DELETE /api/expenses/:id
// ─────────────────────────────────────────────────────────────
router.delete('/:id', requireAuth, async (req: AuthRequest, res) => {
  const deleted = await prisma.expense.deleteMany({
    where: { id: req.params.id, userId: req.userId! },
  });

  if (deleted.count === 0) {
    return res.status(404).json({ error: 'Expense not found' });
  }

  return res.status(204).send();
});

export default router;
