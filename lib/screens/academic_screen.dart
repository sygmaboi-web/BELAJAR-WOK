import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../database/database_helper.dart';
import '../main.dart';
import '../models/academic_model.dart';
import '../models/task_model.dart';

class AcademicScreen extends StatefulWidget {
  const AcademicScreen({super.key});

  @override
  State<AcademicScreen> createState() => _AcademicScreenState();
}

class _AcademicScreenState extends State<AcademicScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<List<SubjectModel>> _loadSubjects() async {
    final db = DatabaseHelper.instance;
    final subjectsRaw = await db.queryAll('subjects', orderBy: 'name ASC');
    final List<SubjectModel> result = [];

    for (final s in subjectsRaw) {
      final gradesRaw = await db.queryAll(
        'grades',
        where: 'subject_id = ?',
        whereArgs: [s['id']],
        orderBy: 'id DESC',
      );
      final grades = gradesRaw.map((g) => GradeItem.fromMap(g)).toList();
      result.add(SubjectModel.fromMap(s, grades: grades));
    }
    return result;
  }

  Future<List<TaskItem>> _loadTasks() async {
    final db = DatabaseHelper.instance;
    final tasksRaw = await db.queryAll(
      'tasks',
      orderBy: 'is_completed ASC, deadline ASC',
    );
    final List<TaskItem> result = [];

    for (final t in tasksRaw) {
      final subsRaw = await db.queryAll(
        'subtasks',
        where: 'task_id = ?',
        whereArgs: [t['id']],
      );
      final subs = subsRaw.map((sub) => SubTaskItem.fromMap(sub)).toList();
      result.add(TaskItem.fromMap(t, subtasks: subs));
    }
    return result;
  }

  void _showAddSubjectDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    final kkmCtrl = TextEditingController(text: '75');
    final targetCtrl = TextEditingController(text: '85');
    final roomCtrl = TextEditingController();
    final noteCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tambah Mata Pelajaran'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Nama Mapel'),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: kkmCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'KKM'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: targetCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Target Rapor'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                controller: roomCtrl,
                decoration: const InputDecoration(labelText: 'Ruang Kelas'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: noteCtrl,
                decoration: const InputDecoration(
                    labelText: 'Catatan Khusus Guru / Aturan'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty) return;
              final subject = SubjectModel(
                name: nameCtrl.text.trim(),
                kkm: double.tryParse(kkmCtrl.text) ?? 75,
                targetScore: double.tryParse(targetCtrl.text) ?? 85,
                teacherNote: noteCtrl.text.trim(),
                room: roomCtrl.text.trim(),
              );
              await DatabaseHelper.instance
                  .insertRow('subjects', subject.toMap());
              if (context.mounted) {
                Provider.of<AppStateProvider>(context, listen: false)
                    .notifyAllScreens();
                Navigator.pop(ctx);
              }
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  void _showAddGradeDialog(BuildContext context, SubjectModel subject) {
    String selectedComp = 'Tugas';
    final titleCtrl = TextEditingController();
    final scoreCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Input Nilai - ${subject.name}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: selectedComp,
                decoration: const InputDecoration(labelText: 'Komponen'),
                items: ['Tugas', 'UH', 'PTS', 'PAS']
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (val) {
                  if (val != null) setDialogState(() => selectedComp = val);
                },
              ),
              const SizedBox(height: 10),
              TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(
                  labelText: 'Judul Penilaian',
                  hintText: 'Contoh: UH 2 Turunan',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: scoreCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Nilai (0 - 100)',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () async {
                final score = double.tryParse(scoreCtrl.text);
                if (score == null || score < 0 || score > 100) return;

                final grade = GradeItem(
                  subjectId: subject.id!,
                  component: selectedComp,
                  title: titleCtrl.text.trim().isEmpty
                      ? selectedComp
                      : titleCtrl.text.trim(),
                  score: score,
                  date: DateFormat('yyyy-MM-dd').format(DateTime.now()),
                );
                await DatabaseHelper.instance
                    .insertRow('grades', grade.toMap());
                if (context.mounted) {
                  Provider.of<AppStateProvider>(context, listen: false)
                      .notifyAllScreens();
                  Navigator.pop(ctx);
                }
              },
              child: const Text('Simpan Nilai'),
            ),
          ],
        ),
      ),
    );
  }

  void _showWhatIfSimulator(BuildContext context, SubjectModel subject) {
    double wTugas = subject.weightTugas;
    double wUh = subject.weightUh;
    double wPts = subject.weightPts;
    double wPas = subject.weightPas;

    final targetCtrl =
        TextEditingController(text: subject.targetScore.toStringAsFixed(0));
    final tugasCtrl = TextEditingController(
      text: subject.averageForComponent('Tugas')?.toStringAsFixed(1) ?? '',
    );
    final uhCtrl = TextEditingController(
      text: subject.averageForComponent('UH')?.toStringAsFixed(1) ?? '',
    );
    final ptsCtrl = TextEditingController(
      text: subject.averageForComponent('PTS')?.toStringAsFixed(1) ?? '',
    );
    final pasCtrl = TextEditingController(
      text: subject.averageForComponent('PAS')?.toStringAsFixed(1) ?? '',
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) {
          final target = double.tryParse(targetCtrl.text) ?? subject.targetScore;
          final nTugas = double.tryParse(tugasCtrl.text);
          final nUh = double.tryParse(uhCtrl.text);
          final nPts = double.tryParse(ptsCtrl.text);
          final nPas = double.tryParse(pasCtrl.text);

          final totalWeight = wTugas + wUh + wPts + wPas;
          double earnedPoints = 0;
          double remainingWeight = 0;

          if (nTugas != null) {
            earnedPoints += nTugas * wTugas;
          } else {
            remainingWeight += wTugas;
          }
          if (nUh != null) {
            earnedPoints += nUh * wUh;
          } else {
            remainingWeight += wUh;
          }
          if (nPts != null) {
            earnedPoints += nPts * wPts;
          } else {
            remainingWeight += wPts;
          }
          if (nPas != null) {
            earnedPoints += nPas * wPas;
          } else {
            remainingWeight += wPas;
          }

          String resultText;
          if (totalWeight <= 0) {
            resultText = 'Total bobot harus lebih dari 0%.';
          } else if (remainingWeight == 0) {
            final finalScore = earnedPoints / totalWeight;
            resultText =
                'Semua komponen terisi! Nilai Akhir Rapor: ${finalScore.toStringAsFixed(2)}';
          } else {
            final requiredScore =
                ((target * totalWeight) - earnedPoints) / remainingWeight;
            if (requiredScore <= 0) {
              resultText =
                  'Target ${target.toStringAsFixed(0)} sudah aman tercapai!';
            } else if (requiredScore > 100) {
              resultText =
                  'Butuh rata-rata ${requiredScore.toStringAsFixed(1)} di sisa komponen (melebihi 100, perlu perbaikan nilai/remedial).';
            } else {
              resultText =
                  'Kamu butuh minimal nilai ${requiredScore.toStringAsFixed(1)} pada komponen yang masih kosong!';
            }
          }

          return Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 20,
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Simulasi Target Rapor: ${subject.name}',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Kosongkan kolom ujian yang belum dilaksanakan untuk melihat nilai minimal yang harus kamu kejar.',
                    style: TextStyle(fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: targetCtrl,
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setSheetState(() {}),
                    decoration: const InputDecoration(
                      labelText: 'Target Nilai Akhir Rapor',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: tugasCtrl,
                          keyboardType: TextInputType.number,
                          onChanged: (_) => setSheetState(() {}),
                          decoration: InputDecoration(
                            labelText: 'Tugas (${wTugas.toInt()}%)',
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: uhCtrl,
                          keyboardType: TextInputType.number,
                          onChanged: (_) => setSheetState(() {}),
                          decoration: InputDecoration(
                            labelText: 'UH (${wUh.toInt()}%)',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: ptsCtrl,
                          keyboardType: TextInputType.number,
                          onChanged: (_) => setSheetState(() {}),
                          decoration: InputDecoration(
                            labelText: 'PTS (${wPts.toInt()}%)',
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: pasCtrl,
                          keyboardType: TextInputType.number,
                          onChanged: (_) => setSheetState(() {}),
                          decoration: InputDecoration(
                            labelText: 'PAS (${wPas.toInt()}%)',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Atur Bobot: Tugas ${wTugas.toInt()}% • UH ${wUh.toInt()}% • PTS ${wPts.toInt()}% • PAS ${wPas.toInt()}%',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Slider(
                    value: wPas,
                    min: 10,
                    max: 50,
                    divisions: 8,
                    label: 'Bobot PAS: ${wPas.toInt()}%',
                    onChanged: (val) {
                      setSheetState(() {
                        wPas = val;
                      });
                    },
                  ),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      resultText,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color:
                            Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showAddTaskDialog(BuildContext context) {
    final titleCtrl = TextEditingController();
    final subjectCtrl = TextEditingController();
    final deadlineCtrl = TextEditingController(
      text: DateFormat('yyyy-MM-dd')
          .format(DateTime.now().add(const Duration(days: 2))),
    );
    String priority = 'Sedang';
    bool isGroup = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Tambah PR / Tugas'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(labelText: 'Nama Tugas'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: subjectCtrl,
                  decoration: const InputDecoration(labelText: 'Mata Pelajaran'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: deadlineCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Deadline (YYYY-MM-DD)',
                  ),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: priority,
                  decoration: const InputDecoration(labelText: 'Prioritas'),
                  items: ['Tinggi', 'Sedang', 'Rendah']
                      .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) setDialogState(() => priority = val);
                  },
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Mode Tugas Kelompok'),
                  value: isGroup,
                  onChanged: (val) => setDialogState(() => isGroup = val),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () async {
                if (titleCtrl.text.trim().isEmpty) return;
                final task = TaskItem(
                  title: titleCtrl.text.trim(),
                  subjectName: subjectCtrl.text.trim().isEmpty
                      ? 'Umum'
                      : subjectCtrl.text.trim(),
                  deadline: deadlineCtrl.text.trim(),
                  priority: priority,
                  isCompleted: false,
                  isGroup: isGroup,
                );
                await DatabaseHelper.instance.insertRow('tasks', task.toMap());
                if (context.mounted) {
                  Provider.of<AppStateProvider>(context, listen: false)
                      .notifyAllScreens();
                  Navigator.pop(ctx);
                }
              },
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddSubtaskDialog(BuildContext context, int taskId) {
    final titleCtrl = TextEditingController();
    final assigneeCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tambah Pembagian Kerja'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleCtrl,
              decoration: const InputDecoration(labelText: 'Bagian Tugas'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: assigneeCtrl,
              decoration: const InputDecoration(
                labelText: 'Nama Anggota Kelompok',
                hintText: 'Contoh: Farelle / Saya',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () async {
              if (titleCtrl.text.trim().isEmpty) return;
              final sub = SubTaskItem(
                taskId: taskId,
                title: titleCtrl.text.trim(),
                assignee: assigneeCtrl.text.trim().isEmpty
                    ? 'Saya'
                    : assigneeCtrl.text.trim(),
                isDone: false,
              );
              await DatabaseHelper.instance.insertRow('subtasks', sub.toMap());
              if (context.mounted) {
                Provider.of<AppStateProvider>(context, listen: false)
                    .notifyAllScreens();
                Navigator.pop(ctx);
              }
            },
            child: const Text('Tambah'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Provider.of<AppStateProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Academic & Rapor Engine',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Mapel & Rapor'),
            Tab(text: 'Tugas & Kelompok'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // TAB 1: MAPEL & RAPOR
          FutureBuilder<List<SubjectModel>>(
            future: _loadSubjects(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final subjects = snapshot.data!;
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Daftar Mata Pelajaran',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      FilledButton.icon(
                        onPressed: () => _showAddSubjectDialog(context),
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Mapel Baru'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ...subjects.map((subj) {
                    Color badgeColor = Colors.green;
                    if (subj.statusLabel.startsWith('Rawan')) {
                      badgeColor = Colors.red;
                    } else if (subj.statusLabel.startsWith('Waspada')) {
                      badgeColor = Colors.orange;
                    } else if (subj.grades.isEmpty) {
                      badgeColor = Colors.grey;
                    }

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ExpansionTile(
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                subj.name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: badgeColor.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: badgeColor),
                              ),
                              child: Text(
                                subj.statusLabel,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: badgeColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                        subtitle: Text(
                          'Rata-rata: ${subj.currentWeightedAverage.toStringAsFixed(1)} | KKM: ${subj.kkm.toInt()} | Target: ${subj.targetScore.toInt()}',
                        ),
                        childrenPadding: const EdgeInsets.all(16),
                        children: [
                          if (subj.teacherNote.isNotEmpty)
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'Catatan Guru (${subj.room}): ${subj.teacherNote}',
                                style: const TextStyle(
                                    fontStyle: FontStyle.italic, fontSize: 13),
                              ),
                            ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            children: [
                              OutlinedButton.icon(
                                onPressed: () =>
                                    _showAddGradeDialog(context, subj),
                                icon: const Icon(Icons.add_chart, size: 18),
                                label: const Text('Input Nilai'),
                              ),
                              FilledButton.tonalIcon(
                                onPressed: () =>
                                    _showWhatIfSimulator(context, subj),
                                icon: const Icon(Icons.calculate, size: 18),
                                label: const Text('Simulasi Target Rapor'),
                              ),
                            ],
                          ),
                          const Divider(height: 20),
                          if (subj.grades.isEmpty)
                            const Text('Belum ada riwayat nilai.')
                          else
                            ...subj.grades.map(
                              (g) => ListTile(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                title: Text('${g.component}: ${g.title}'),
                                trailing: Text(
                                  g.score.toStringAsFixed(1),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15),
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  }),
                ],
              );
            },
          ),

          // TAB 2: TUGAS & KELOMPOK
          FutureBuilder<List<TaskItem>>(
            future: _loadTasks(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final tasks = snapshot.data!;
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Daftar PR & Proyek Kelompok',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      FilledButton.icon(
                        onPressed: () => _showAddTaskDialog(context),
                        icon: const Icon(Icons.add_task, size: 18),
                        label: const Text('Tugas Baru'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ...tasks.map((task) {
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Checkbox(
                                  value: task.isCompleted,
                                  onChanged: (val) async {
                                    await DatabaseHelper.instance.updateRow(
                                      'tasks',
                                      {'is_completed': (val ?? false) ? 1 : 0},
                                      'id = ?',
                                      [task.id],
                                    );
                                    if (context.mounted) {
                                      Provider.of<AppStateProvider>(context,
                                              listen: false)
                                          .notifyAllScreens();
                                    }
                                  },
                                ),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        task.title,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          decoration: task.isCompleted
                                              ? TextDecoration.lineThrough
                                              : null,
                                        ),
                                      ),
                                      Text(
                                        '${task.subjectName} • Deadline: ${task.deadline} • Prioritas ${task.priority}',
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            if (task.isGroup) ...[
                              const Divider(),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Progres Kelompok (${(task.groupProgress * 100).toInt()}%)',
                                    style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600),
                                  ),
                                  TextButton.icon(
                                    onPressed: () =>
                                        _showAddSubtaskDialog(context, task.id!),
                                    icon: const Icon(Icons.person_add, size: 16),
                                    label: const Text('Bagi Tugas'),
                                  ),
                                ],
                              ),
                              LinearProgressIndicator(
                                value: task.groupProgress,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              const SizedBox(height: 6),
                              ...task.subtasks.map(
                                (sub) => CheckboxListTile(
                                  dense: true,
                                  contentPadding: EdgeInsets.zero,
                                  value: sub.isDone,
                                  title: Text(sub.title),
                                  subtitle: Text('PIC: ${sub.assignee}'),
                                  onChanged: (val) async {
                                    await DatabaseHelper.instance.updateRow(
                                      'subtasks',
                                      {'is_done': (val ?? false) ? 1 : 0},
                                      'id = ?',
                                      [sub.id],
                                    );
                                    if (context.mounted) {
                                      Provider.of<AppStateProvider>(context,
                                              listen: false)
                                          .notifyAllScreens();
                                    }
                                  },
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
