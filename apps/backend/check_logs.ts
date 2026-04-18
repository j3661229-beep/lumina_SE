import { PrismaClient } from '@prisma/client';
const prisma = new PrismaClient();

async function main() {
  const logs = await prisma.attendanceLog.findMany({
    include: { profile: true, slot: { include: { subject: true } } }
  });
  console.log("Total logs in DB:", logs.length);
  if (logs.length > 0) {
    console.log(logs.map(l => `${l.profile.email}: ${l.slot.subject.name} on ${l.date} -> ${l.status}`));
  }
}
main();
