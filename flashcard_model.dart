class OcclusionBox {
  final int? id;
  final int flashcardId;
  final double x; // Posisi relatif horizontal (0.0 - 1.0)
  final double y; // Posisi relatif vertikal (0.0 - 1.0)
  final double width; // Lebar relatif (0.0 - 1.0)
  final double height; // Tinggi relatif (0.0 - 1.0)
  final String label;

  OcclusionBox({
    this.id,
    required this.flashcardId,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    this.label = 'Ketuk untuk buka',
  });

  factory OcclusionBox.fromMap(Map<String, dynamic> map) {
    return OcclusionBox(
      id: map['id'] as int?,
      flashcardId: map['flashcard_id'] as int,
      x: (map['x'] as num).toDouble(),
      y: (map['y'] as num).toDouble(),
      width: (map['width'] as num).toDouble(),
      height: (map['height'] as num).toDouble(),
      label: map['label'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'flashcard_id': flashcardId,
      'x': x,
      'y': y,
      'width': width,
      'height': height,
      'label': label,
    };
  }
}

class FlashcardItem {
  final int? id;
  final String subjectName;
  final String title;
  final String imagePath;
  final String notes;
  final String nextReviewDate; // Format: yyyy-MM-dd
  final int intervalDays;
  final List<OcclusionBox> boxes;

  FlashcardItem({
    this.id,
    required this.subjectName,
    required this.title,
    required this.imagePath,
    required this.notes,
    required this.nextReviewDate,
    this.intervalDays = 1,
    this.boxes = const [],
  });

  factory FlashcardItem.fromMap(
    Map<String, dynamic> map, {
    List<OcclusionBox> boxes = const [],
  }) {
    return FlashcardItem(
      id: map['id'] as int?,
      subjectName: map['subject_name'] as String,
      title: map['title'] as String,
      imagePath: map['image_path'] as String,
      notes: map['notes'] as String,
      nextReviewDate: map['next_review_date'] as String,
      intervalDays: map['interval_days'] as int,
      boxes: boxes,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'subject_name': subjectName,
      'title': title,
      'image_path': imagePath,
      'notes': notes,
      'next_review_date': nextReviewDate,
      'interval_days': intervalDays,
    };
  }
}
