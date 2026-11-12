class GradeItem {
  final int? id;
  final int subjectId;
  final String component; // 'Tugas', 'UH', 'PTS', 'PAS'
  final String title;
  final double score;
  final String date;

  GradeItem({
    this.id,
    required this.subjectId,
    required this.component,
    required this.title,
    required this.score,
    required this.date,
  });

  factory GradeItem.fromMap(Map<String, dynamic> map) {
    return GradeItem(
      id: map['id'] as int?,
      subjectId: map['subject_id'] as int,
      component: map['component'] as String,
      title: map['title'] as String,
      score: (map['score'] as num).toDouble(),
      date: map['date'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'subject_id': subjectId,
      'component': component,
      'title': title,
      'score': score,
      'date': date,
    };
  }
}

class SubjectModel {
  final int? id;
  final String name;
  final double kkm;
  final double targetScore;
  final String teacherNote;
  final String room;
  final double weightTugas;
  final double weightUh;
  final double weightPts;
  final double weightPas;
  final List<GradeItem> grades;

  SubjectModel({
    this.id,
    required this.name,
    required this.kkm,
    required this.targetScore,
    required this.teacherNote,
    required this.room,
    this.weightTugas = 30.0,
    this.weightUh = 30.0,
    this.weightPts = 20.0,
    this.weightPas = 20.0,
    this.grades = const [],
  });

  // Menghitung rata-rata untuk komponen tertentu (misal hanya 'Tugas')
  double? averageForComponent(String component) {
    final filtered = grades.where((g) => g.component == component).toList();
    if (filtered.isEmpty) return null;
    final total = filtered.fold<double>(0.0, (sum, item) => sum + item.score);
    return total / filtered.length;
  }

  // Menghitung nilai akhir sementara berdasarkan bobot komponen yang sudah terisi
  double get currentWeightedAverage {
    double weightedSum = 0.0;
    double activeWeight = 0.0;

    final avgTugas = averageForComponent('Tugas');
    if (avgTugas != null) {
      weightedSum += avgTugas * weightTugas;
      activeWeight += weightTugas;
    }

    final avgUh = averageForComponent('UH');
    if (avgUh != null) {
      weightedSum += avgUh * weightUh;
      activeWeight += weightUh;
    }

    final avgPts = averageForComponent('PTS');
    if (avgPts != null) {
      weightedSum += avgPts * weightPts;
      activeWeight += weightPts;
    }

    final avgPas = averageForComponent('PAS');
    if (avgPas != null) {
      weightedSum += avgPas * weightPas;
      activeWeight += weightPas;
    }

    if (activeWeight == 0.0) return 0.0;
    return weightedSum / activeWeight;
  }

  // Status indikator rawan: 'Aman', 'Waspada', 'Rawan', atau 'Belum Ada Nilai'
  String get statusLabel {
    if (grades.isEmpty) return 'Belum Ada Nilai';
    final avg = currentWeightedAverage;
    if (avg < kkm) return 'Rawan (< KKM)';
    if (avg < targetScore) return 'Waspada (< Target)';
    return 'Aman';
  }

  factory SubjectModel.fromMap(
    Map<String, dynamic> map, {
    List<GradeItem> grades = const [],
  }) {
    return SubjectModel(
      id: map['id'] as int?,
      name: map['name'] as String,
      kkm: (map['kkm'] as num).toDouble(),
      targetScore: (map['target_score'] as num).toDouble(),
      teacherNote: map['teacher_note'] as String,
      room: map['room'] as String,
      weightTugas: (map['weight_tugas'] as num).toDouble(),
      weightUh: (map['weight_uh'] as num).toDouble(),
      weightPts: (map['weight_pts'] as num).toDouble(),
      weightPas: (map['weight_pas'] as num).toDouble(),
      grades: grades,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'kkm': kkm,
      'target_score': targetScore,
      'teacher_note': teacherNote,
      'room': room,
      'weight_tugas': weightTugas,
      'weight_uh': weightUh,
      'weight_pts': weightPts,
      'weight_pas': weightPas,
    };
  }
}
