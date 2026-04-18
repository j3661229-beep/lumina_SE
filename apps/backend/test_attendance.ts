import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

async function main() {
  const profile = await prisma.profile.findFirst();
  if (!profile) return console.log("No profile");
  
  const slot = await prisma.timetableSlot.findFirst({
    where: { userId: profile.id }
  });
  
  if (!slot) return console.log("No slot");
  
  console.log("Found slot:", slot.id);
  
  try {
    const log = await prisma.attendanceLog.upsert({
      where: { slotId_date: { slotId: slot.id, date: new Date('2026-04-18') } },
      create: { userId: profile.id, slotId: slot.id, date: new Date('2026-04-18'), status: 'present' },
      update: { status: 'present' },
    });
    console.log("Success log:", log);
  } catch (e) {
    console.error("error Upserting!", e);
  }
}

main().catch(console.error).finally(()=>prisma.$disconnect());
