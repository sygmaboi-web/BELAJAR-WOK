class SubTaskItem {
  final int? id;
  final int taskId;
  final String title;
  final String assignee;
  final bool isDone;

  SubTaskItem({
    this.id,
    required this.taskId,
    required this.title,
    required this.assignee,
    required this.isDone,
  });

  factory SubTaskItem.fromMap(Map<String, dynamic> map) {
    return SubTaskItem(
      id: map['id'] as int?,
      taskId: map['task_id'] as int,
      title: map['title'] as String,
      assignee: map['assignee'] as String,
      isDone: (map['is_done'] as int) == 1,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'task_id': taskId,
      'title': title,
      'assignee': assignee,
      'is_done': isDone ? 1 : 0,
    };
  }
}

class TaskItem {
  final int? id;
  final String title;
  final String subjectName;
  final String deadline; // Format: yyyy-MM-dd
  final String priority; // 'Tinggi', 'Sedang', 'Rendah'
  final bool isCompleted;
  final bool isGroup;
  final List<SubTaskItem> subtasks;

  TaskItem({
    this.id,
    required this.title,
    required this.subjectName,
    required this.deadline,
    required this.priority,
    required this.isCompleted,
    required this.isGroup,
    this.subtasks = const [],
  });

  // Menghitung persentase progres tugas kelompok (0.0 sampai 1.0)
  double get groupProgress {
    if (subtasks.isEmpty) return isCompleted ? 1.0 : 0.0;
    final doneCount = subtasks.where((s) => s.isDone).length;
    return doneCount / subtasks.length;
  }

  factory TaskItem.fromMap(
    Map<String, dynamic> map, {
    List<SubTaskItem> subtasks = const [],
  }) {
    return TaskItem(
      id: map['id'] as int?,
      title: map['title'] as String,
      subjectName: map['subject_name'] as String,
      deadline: map['deadline'] as String,
      priority: map['priority'] as String,
      isCompleted: (map['is_completed'] as int) == 1,
      isGroup: (map['is_group'] as int) == 1,
      subtasks: subtasks,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'title': title,
      'subject_name': subjectName,
      'deadline': deadline,
      'priority': priority,
      'is_completed': isCompleted ? 1 : 0,
      'is_group': isGroup ? 1 : 0,
    };
  }
}
