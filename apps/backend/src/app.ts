import 'express-async-errors';
import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import morgan from 'morgan';
import dotenv from 'dotenv';
import { prisma } from './config/prisma';

dotenv.config();

import timetableRouter from './routes/timetable';
import contextSwitchRouter from './routes/contextSwitch';
import gmailRouter from './routes/gmail';
import expensesRouter from './routes/expenses';
import groupsRouter from './routes/groups';
import authRouter from './routes/auth';
import profileRouter from './routes/profile';
import demoRouter from './routes/demo';

const app = express();

app.use(helmet());
app.use(cors({ origin: '*' }));
app.use(morgan('combined'));
app.use(express.json({ limit: '10mb' }));

// Health check — also verifies Prisma DB connection
app.get('/health', async (_, res) => {
  try {
    await prisma.$queryRaw`SELECT 1`;
    res.json({ status: 'ok', db: 'connected', ts: new Date().toISOString() });
  } catch {
    res.status(503).json({ status: 'error', db: 'disconnected' });
  }
});

app.use('/api/auth', authRouter);
app.use('/api/timetable', timetableRouter);
app.use('/api/context-switch', contextSwitchRouter);
app.use('/api/gmail', gmailRouter);
app.use('/api/expenses', expensesRouter);
app.use('/api/groups', groupsRouter);
app.use('/api/profile', profileRouter);
app.use('/api/demo', demoRouter);

// Global error handler
app.use(
  (
    err: any,
    _req: express.Request,
    res: express.Response,
    _next: express.NextFunction
  ) => {
    console.error('[Lumina Error]', err);
    res.status(err.status ?? 500).json({
      error: err.message ?? 'Internal server error',
    });
  }
);

const PORT = process.env.PORT ?? 3000;
const HOST = '0.0.0.0'; // listen on all interfaces so physical devices can connect
app.listen(Number(PORT), HOST, async () => {
  console.log(`🌟 Lumina backend running on http://${HOST}:${PORT}`);
  console.log(`📱 From device, use: http://10.10.53.131:${PORT}/api`);
  // Verify DB on startup
  try {
    await prisma.$connect();
    console.log('✅ Prisma connected to PostgreSQL');
  } catch (e) {
    console.error('❌ Prisma connection failed:', e);
  }
});

export default app;
