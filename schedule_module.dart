class ScheduleItem {
  final int? id;
  final String profile;
  final int dayOfWeek; // 1 = Senin ... 7 = Minggu
  final String startTime;
  final String endTime;
  final String subjectName;
  final String room;
  final String uniform;
  final String packingItems;

  ScheduleItem({
    this.id,
    required this.profile,
    required this.dayOfWeek,
    required this.startTime,
    required this.endTime,
    required this.subjectName,
    required this.room,
    required this.uniform,
    required this.packingItems,
  });

  // Memecah string barang bawaan (misal: "Jas Lab, Kalkulator") menjadi List
  List<String> get packingList {
    if (packingItems.trim().isEmpty) return [];
    return packingItems
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  factory ScheduleItem.fromMap(Map<String, dynamic> map) {
    return ScheduleItem(
      id: map['id'] as int?,
      profile: map['profile'] as String,
      dayOfWeek: map['day_of_week'] as int,
      startTime: map['start_time'] as String,
      endTime: map['end_time'] as String,
      subjectName: map['subject_name'] as String,
      room: map['room'] as String,
      uniform: map['uniform'] as String,
      packingItems: map['packing_items'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'profile': profile,
      'day_of_week': dayOfWeek,
      'start_time': startTime,
      'end_time': endTime,
      'subject_name': subjectName,
      'room': room,
      'uniform': uniform,
      'packing_items': packingItems,
    };
  }
}
