import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../database/database_helper.dart';
import '../main.dart';
import '../models/budget_model.dart';
import '../models/project_model.dart';
import '../models/schedule_model.dart';
import '../models/task_model.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final NumberFormat _currencyFmt =
      NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

  Future> _loadDashboardData(String activeProfile) async {
    final db = DatabaseHelper.instance;
    final now = DateTime.now();
    final todayWeekday = now.weekday;
    final tomorrow = now.add(const Duration(days: 1));
    final tomorrowWeekday = tomorrow.weekday;

    // 1. Ambil Jadwal Hari Ini & Besok
    final todaySchedulesRaw = await db.queryAll(
      'schedules',
      where: 'profile = ? AND day_of_week = ?',
      whereArgs: [activeProfile, todayWeekday],
      orderBy: 'start_time ASC',
    );
    final todaySchedules =
        todaySchedulesRaw.map((e) => ScheduleItem.fromMap(e)).toList();

    final tomorrowSchedulesRaw = await db.queryAll(
      'schedules',
      where: 'profile = ? AND day_of_week = ?',
      whereArgs: [activeProfile, tomorrowWeekday],
      orderBy: 'start_time ASC',
    );
    final tomorrowSchedules =
        tomorrowSchedulesRaw.map((e) => ScheduleItem.fromMap(e)).toList();

    // Kumpulkan checklist barang bawaan untuk besok
    final Set<String> tomorrowItems = {};
    for (final sched in tomorrowSchedules) {
      tomorrowItems.addAll(sched.packingList);
    }
    final Map<String, bool> packingStatus = {};
    for (final item in tomorrowItems) {
      final key = '${activeProfile}_${tomorrowWeekday}_$item';
      packingStatus[item] = await db.isPackingItemChecked(key);
    }

    // 2. Ambil Tugas Aktif yang belum selesai
    final tasksRaw = await db.queryAll(
      'tasks',
      where: 'is_completed = 0',
      orderBy: 'deadline ASC',
    );
    final tasks = tasksRaw.map((e) => TaskItem.fromMap(e)).toList();

    // 3. Hitung Daily Safe-to-Spend
    final budgetRaw = await db.queryAll('budget_config', where: 'id = 1');
    final BudgetConfig budgetConfig = budgetRaw.isNotEmpty
        ? BudgetConfig.fromMap(budgetRaw.first)
        : BudgetConfig(
            periodName: 'Mingguan',
            totalBudget: 200000,
            startDate: DateFormat('yyyy-MM-dd').format(now),
            endDate: DateFormat('yyyy-MM-dd')
                .format(now.add(const Duration(days: 6))),
          );

    final txRaw = await db.queryAll(
      'transactions',
      where: 'date >= ?',
      whereArgs: ['${budgetConfig.startDate} 00:00'],
    );
    final transactions =
        txRaw.map((e) => TransactionItem.fromMap(e)).toList();
    final double totalSpent =
        transactions.fold(0.0, (sum, item) => sum + item.amount);
    final double remainingBudget = budgetConfig.totalBudget - totalSpent;

    final DateTime endDate = DateTime.parse(budgetConfig.endDate);
    final DateTime todayDateOnly = DateTime(now.year, now.month, now.day);
    final int remainingDays =
        (endDate.difference(todayDateOnly).inDays + 1).clamp(1, 365);

    final double safeToSpendToday =
        remainingBudget > 0 ? remainingBudget / remainingDays : 0.0;

    // 4. Cek Conflict Alert Banner (Ujian berdekatan H-3 atau bentrok dengan Event/Lomba)
    final eventsRaw = await db.queryAll('events', orderBy: 'event_date ASC');
    final events = eventsRaw.map((e) => EventItem.fromMap(e)).toList();
    final List<String> conflictAlerts = [];

    final exams = events.where((e) => e.category == 'Ujian').toList();
    final nonExams = events.where((e) => e.category != 'Ujian').toList();

    for (final exam in exams) {
      final examDate = DateTime.parse(exam.eventDate);
      final diffFromToday = examDate.difference(todayDateOnly).inDays;

      if (diffFromToday >= 0 && diffFromToday <= 3) {
        conflictAlerts.add(
          'H-$diffFromToday menuju ${exam.title} (${DateFormat('dd MMM', 'id_ID').format(examDate)}).',
        );
      }

      for (final activity in nonExams) {
        final actDate = DateTime.parse(activity.eventDate);
        final actDeadline = DateTime.parse(activity.deadlineDate);
        if ((examDate.difference(actDate).inDays).abs() <= 2 ||
            (examDate.difference(actDeadline).inDays).abs() <= 2) {
          conflictAlerts.add(
            'Bentrok Jadwal: "${exam.title}" berdekatan dengan "${activity.title}"!',
          );
        }
      }
    }

    return {
      'todaySchedules': todaySchedules,
      'tomorrowSchedules': tomorrowSchedules,
      'tomorrowItems': tomorrowItems.toList(),
      'packingStatus': packingStatus,
      'tomorrowWeekday': tomorrowWeekday,
      'tasks': tasks,
      'remainingBudget': remainingBudget,
      'remainingDays': remainingDays,
      'safeToSpendToday': safeToSpendToday,
      'conflictAlerts': conflictAlerts.toSet().toList(),
    };
  }

  void _showQuickExpenseDialog(BuildContext context) {
    final titleCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    String selectedCategory = 'Makan/Minum';
    final categories = [
      'Makan/Minum',
      'Bensin/Transport',
      'Print/Fotokopi',
      'Patungan/Kas Kelas',
    ];

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Catat Jajan Cepat'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: amountCtrl,
                      keyboardType: TextInputType.number,
                      autofocus: true,
                      decoration: const InputDecoration(
                        labelText: 'Nominal (Rp)',
                        prefixText: 'Rp ',
                        hintText: '15000',
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: selectedCategory,
                      decoration: const InputDecoration(labelText: 'Kategori'),
                      items: categories
                          .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() => selectedCategory = val);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: titleCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Keterangan Singkat',
                        hintText: 'Contoh: Es teh & gorengan',
                      ),
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
                    final amount = double.tryParse(
                            amountCtrl.text.replaceAll('.', '').trim()) ??
                        0;
                    if (amount <= 0) return;

                    final tx = TransactionItem(
                      title: titleCtrl.text.trim().isEmpty
                          ? selectedCategory
                          : titleCtrl.text.trim(),
                      amount: amount,
                      category: selectedCategory,
                      date:
                          DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now()),
                    );
                    await DatabaseHelper.instance
                        .insertRow('transactions', tx.toMap());
                    if (context.mounted) {
                      Provider.of<AppStateProvider>(context, listen: false)
                          .notifyAllScreens();
                      Navigator.pop(ctx);
                    }
                  },
                  child: const Text('Simpan'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppStateProvider>(context);
    final now = DateTime.now();
    final isMorningOrAfternoon = now.hour >= 5 && now.hour < 15;
    final dateHeader = DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(now);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Personal Student OS',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            Text(
              dateHeader,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Chip(
              label: Text(
                appState.activeScheduleProfile,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
              visualDensity: VisualDensity.compact,
            ),
          ),
        ],
      ),
      body: FutureBuilder>(
        future: _loadDashboardData(appState.activeScheduleProfile),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data!;
          final List<String> alerts = data['conflictAlerts'];
          final double safeToSpend = data['safeToSpendToday'];
          final double remainingBudget = data['remainingBudget'];
          final int remainingDays = data['remainingDays'];
          final List<ScheduleItem> todaySchedules = data['todaySchedules'];
          final List<ScheduleItem> tomorrowSchedules =
              data['tomorrowSchedules'];
          final List<String> tomorrowItems = data['tomorrowItems'];
          final Map<String, bool> packingStatus = data['packingStatus'];
          final int tomorrowWeekday = data['tomorrowWeekday'];
          final List<TaskItem> tasks = data['tasks'];

          return RefreshIndicator(
            onRefresh: () async => setState(() {}),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // 1. CONFLICT ALERT BANNER
                if (alerts.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.error,
                        width: 1.2,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.warning_amber_rounded,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onErrorContainer,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Peringatan Jadwal & Ujian!',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onErrorContainer,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ...alerts.map(
                          (msg) => Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              '• $msg',
                              style: TextStyle(
                                fontSize: 13,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onErrorContainer,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // 2. DAILY SAFE-TO-SPEND CARD
                Card(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Jatah Jajan Aman Hari Ini',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onPrimaryContainer,
                              ),
                            ),
                            FilledButton.icon(
                              onPressed: () =>
                                  _showQuickExpenseDialog(context),
                              icon: const Icon(Icons.add, size: 18),
                              label: const Text('Catat Jajan'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _currencyFmt.format(safeToSpend),
                          style: TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context)
                                .colorScheme
                                .onPrimaryContainer,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Sisa budget ${_currencyFmt.format(remainingBudget)} untuk $remainingDays hari ke depan',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context)
                                .colorScheme
                                .onPrimaryContainer
                                .withOpacity(0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // 3. SMART CONTEXT CARD (PAGI/SIANG vs SORE/MALAM)
                if (isMorningOrAfternoon)
                  _buildMorningContextCard(context, todaySchedules, now)
                else
                  _buildEveningContextCard(
                    context,
                    appState.activeScheduleProfile,
                    tomorrowWeekday,
                    tomorrowSchedules,
                    tomorrowItems,
                    packingStatus,
                    tasks,
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildMorningContextCard(
    BuildContext context,
    List<ScheduleItem> todaySchedules,
    DateTime now,
  ) {
    final currentMinutes = now.hour * 60 + now.minute;
    ScheduleItem? nextLesson;
    for (final s in todaySchedules) {
      final parts = s.startTime.split(':');
      final startMin = int.parse(parts[0]) * 60 + int.parse(parts[1]);
      if (startMin >= currentMinutes) {
        nextLesson = s;
        break;
      }
    }

    final uniformInfo = todaySchedules.isNotEmpty
        ? todaySchedules.first.uniform
        : 'Bebas / Libur Sekolah';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.wb_sunny_outlined,
                    color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                const Text(
                  'Fokus Sekolah Hari Ini',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.checkroom, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Seragam: $uniformInfo',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
            if (nextLesson != null) ...[
              const SizedBox(height: 12),
              Text(
                'Pelajaran Berikutnya: ${nextLesson.subjectName} (${nextLesson.startTime} • ${nextLesson.room})',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
            const Divider(height: 24),
            if (todaySchedules.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('Tidak ada jadwal pelajaran hari ini.'),
              )
            else
              ...todaySchedules.map(
                (item) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    child: Text(item.startTime.substring(0, 2)),
                  ),
                  title: Text(
                    item.subjectName,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text('${item.startTime} - ${item.endTime} • ${item.room}'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEveningContextCard(
    BuildContext context,
    String activeProfile,
    int tomorrowWeekday,
    List<ScheduleItem> tomorrowSchedules,
    List<String> tomorrowItems,
    Map<String, bool> packingStatus,
    List<TaskItem> tasks,
  ) {
    final uniformTomorrow = tomorrowSchedules.isNotEmpty
        ? tomorrowSchedules.first.uniform
        : 'Tidak ada jadwal besok';

    return Column(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.backpack_outlined,
                        color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 8),
                    const Text(
                      'Persiapan Tas Untuk Besok',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Seragam Besok: $uniformTomorrow',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                ),
                const Divider(height: 20),
                if (tomorrowItems.isEmpty)
                  const Text('Tidak ada barang khusus yang perlu disiapkan.')
                else
                  ...tomorrowItems.map((item) {
                    final checked = packingStatus[item] ?? false;
                    final key = '${activeProfile}_${tomorrowWeekday}_$item';
                    return CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: checked,
                      title: Text(
                        item,
                        style: TextStyle(
                          decoration:
                              checked ? TextDecoration.lineThrough : null,
                        ),
                      ),
                      onChanged: (val) async {
                        await DatabaseHelper.instance
                            .togglePackingItem(key, val ?? false);
                        if (context.mounted) {
                          Provider.of<AppStateProvider>(context, listen: false)
                              .notifyAllScreens();
                        }
                      },
                    );
                  }),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.assignment_late_outlined,
                        color: Theme.of(context).colorScheme.tertiary),
                    const SizedBox(width: 8),
                    const Text(
                      'PR & Tugas Mendekati Deadline',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const Divider(height: 20),
                if (tasks.isEmpty)
                  const Text('Semua PR dan tugas sudah beres!')
                else
                  ...tasks.take(4).map(
                        (t) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            t.isGroup ? Icons.groups : Icons.person,
                            color: t.priority == 'Tinggi'
                                ? Colors.red
                                : Colors.orange,
                          ),
                          title: Text(t.title),
                          subtitle:
                              Text('${t.subjectName} • Deadline: ${t.deadline}'),
                        ),
                      ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
