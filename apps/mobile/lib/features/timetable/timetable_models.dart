class ParsedSlot {
  final String subjectName, dayOfWeek, startTime, endTime, slotType;
  final String? teacher, room;
  
  const ParsedSlot({
    required this.subjectName,
    required this.dayOfWeek,
    required this.startTime,
    required this.endTime,
    required this.slotType,
    this.teacher,
    this.room,
  });

  Map<String, dynamic> toJson() => {
    'subject_name': subjectName,
    'day_of_week': dayOfWeek,
    'start_time': startTime,
    'end_time': endTime,
    'slot_type': slotType,
    if (teacher != null) 'teacher': teacher,
    if (room != null) 'room': room,
  };
}

class ParsedHoliday {
  final String name, date;
  const ParsedHoliday({required this.name, required this.date});
  Map<String, dynamic> toJson() => {'name': name, 'date': date};
}

class OcrResult {
  final List<ParsedSlot> slots;
  final List<ParsedHoliday> holidays;
  const OcrResult({required this.slots, required this.holidays});
}
