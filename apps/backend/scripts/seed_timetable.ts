import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

async function main() {
  const profile = await prisma.profile.findFirst();
  if (!profile) {
    console.error('No profile found. Please register/login first.');
    return;
  }
  const userId = profile.id;

  // Clear existing subjects and slots
  await prisma.timetableSlot.deleteMany({ where: { userId } });
  await prisma.subject.deleteMany({ where: { userId } });

  const subjectsData = [
    { name: 'MDM', code: 'MDM', teacher: '-', colorHex: '#4F46E5' },
    { name: 'DAA', code: 'DAA', teacher: 'PBB or SND or NR', colorHex: '#10B981' },
    { name: 'CCN', code: 'CCN', teacher: 'AVS or JS or AT or IS', colorHex: '#F59E0B' },
    { name: 'OS', code: 'OS', teacher: 'SK or AGN or AN or KKD', colorHex: '#EF4444' },
    { name: 'PCS', code: 'PCS', teacher: 'SD or AY', colorHex: '#8B5CF6' },
    { name: 'FOM-II', code: 'FOM-II', teacher: 'AsT', colorHex: '#EC4899' },
    { name: 'HSS', code: 'HSS', teacher: '-', colorHex: '#64748B' },
    { name: 'LLC', code: 'LLC', teacher: '-', colorHex: '#14B8A6' },
  ];

  const subjectMap: Record<string, string> = {};
  for (const s of subjectsData) {
    const created = await prisma.subject.create({
      // @ts-ignore
      data: { ...s, userId }
    });
    subjectMap[s.name] = created.id;
  }

  const slots = [
    // Monday
    { dayOfWeek: 'monday', startTime: '09:00', endTime: '11:00', subjectId: subjectMap['MDM'], room: 'Lab', slotType: 'lab' },
    { dayOfWeek: 'monday', startTime: '11:15', endTime: '12:15', subjectId: subjectMap['DAA'], room: '508', slotType: 'lecture' },
    { dayOfWeek: 'monday', startTime: '12:15', endTime: '13:15', subjectId: subjectMap['CCN'], room: '508', slotType: 'lecture' },
    { dayOfWeek: 'monday', startTime: '14:15', endTime: '15:15', subjectId: subjectMap['MDM'], room: '508', slotType: 'lecture' },
    { dayOfWeek: 'monday', startTime: '15:15', endTime: '16:15', subjectId: subjectMap['MDM'], room: 'Lab', slotType: 'lab' },

    // Tuesday
    { dayOfWeek: 'tuesday', startTime: '09:00', endTime: '10:00', subjectId: subjectMap['OS'], room: '508', slotType: 'lecture' },
    { dayOfWeek: 'tuesday', startTime: '10:00', endTime: '11:00', subjectId: subjectMap['DAA'], room: '508', slotType: 'lecture' },
    { dayOfWeek: 'tuesday', startTime: '11:15', endTime: '13:15', subjectId: subjectMap['PCS'], room: '608', slotType: 'lab' },
    { dayOfWeek: 'tuesday', startTime: '14:15', endTime: '15:15', subjectId: subjectMap['MDM'], room: '508', slotType: 'lecture' },
    { dayOfWeek: 'tuesday', startTime: '15:15', endTime: '16:15', subjectId: subjectMap['MDM'], room: 'Lab', slotType: 'lab' },

    // Wednesday
    { dayOfWeek: 'wednesday', startTime: '09:00', endTime: '11:00', subjectId: subjectMap['CCN'], room: '703-B', slotType: 'lab' },
    { dayOfWeek: 'wednesday', startTime: '11:15', endTime: '12:15', subjectId: subjectMap['CCN'], room: '508', slotType: 'lecture' },
    { dayOfWeek: 'wednesday', startTime: '12:15', endTime: '13:15', subjectId: subjectMap['DAA'], room: '508', slotType: 'lecture' },
    { dayOfWeek: 'wednesday', startTime: '14:15', endTime: '15:15', subjectId: subjectMap['FOM-II'], room: '307', slotType: 'lecture' },
    { dayOfWeek: 'wednesday', startTime: '15:15', endTime: '16:15', subjectId: subjectMap['HSS'], room: '-', slotType: 'lecture' },

    // Thursday
    { dayOfWeek: 'thursday', startTime: '09:00', endTime: '10:00', subjectId: subjectMap['PCS'], room: '508', slotType: 'lecture' },
    { dayOfWeek: 'thursday', startTime: '10:00', endTime: '11:00', subjectId: subjectMap['OS'], room: '508', slotType: 'lecture' },
    { dayOfWeek: 'thursday', startTime: '11:15', endTime: '13:15', subjectId: subjectMap['DAA'], room: '604', slotType: 'lab' },
    { dayOfWeek: 'thursday', startTime: '14:15', endTime: '15:15', subjectId: subjectMap['FOM-II'], room: '307', slotType: 'lecture' },
    { dayOfWeek: 'thursday', startTime: '15:15', endTime: '16:15', subjectId: subjectMap['HSS'], room: '-', slotType: 'lecture' },
    { dayOfWeek: 'thursday', startTime: '16:15', endTime: '17:15', subjectId: subjectMap['LLC'], room: '-', slotType: 'lecture' },
    { dayOfWeek: 'thursday', startTime: '17:15', endTime: '18:15', subjectId: subjectMap['LLC'], room: '-', slotType: 'lecture' },

    // Friday
    { dayOfWeek: 'friday', startTime: '09:00', endTime: '10:00', subjectId: subjectMap['CCN'], room: '508', slotType: 'lecture' },
    { dayOfWeek: 'friday', startTime: '10:00', endTime: '11:00', subjectId: subjectMap['FOM-II'], room: '307', slotType: 'lecture' },
    { dayOfWeek: 'friday', startTime: '11:15', endTime: '13:15', subjectId: subjectMap['OS'], room: '509', slotType: 'lab' },
    { dayOfWeek: 'friday', startTime: '14:15', endTime: '15:15', subjectId: subjectMap['OS'], room: '508', slotType: 'lecture' },
  ];

  await prisma.timetableSlot.createMany({
    data: slots.map(s => ({ ...s, userId })) as any
  });

  console.log('Successfully seeded ' + slots.length + ' slots and ' + subjectsData.length + ' subjects for user ' + userId);
}

main()
  .catch(e => {
    console.error(e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
