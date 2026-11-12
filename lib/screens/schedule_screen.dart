import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../database/database_helper.dart';
import '../main.dart';
import '../models/schedule_model.dart';

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  int _selectedDay = DateTime.now().weekday > 5 ? 1 : DateTime.now().weekday;

  final List<String> _profiles = [
    'Reguler',
    'Blok/Praktikum',
    'Ujian',
    'Libur/Jamkos',
  ];

  final Map<int, String> _dayNames = {
    1: 'Senin',
    2: 'Selasa',
    3: 'Rabu',
    4: 'Kamis',
    5: 'Jumat',
    6: 'Sabtu',
  };

  Future<dynamic> _loadScheduleAndPacking(String profile) async {
    final db = DatabaseHelper.instance;
    final daySchedulesRaw = await db.queryAll(
      'schedules',
      where: 'profile = ? AND day_of_week = ?',
      whereArgs: [profile, _selectedDay],
      orderBy: 'start_time ASC',
    ) as List>;
    final daySchedules =
        daySchedulesRaw.map((e) => ScheduleItem.fromMap(e)).toList();

    final tomorrowWeekday = (DateTime.now().weekday % 7) + 1;
    final tomorrowRaw = await db.queryAll(
      'schedules',
      where: 'profile = ? AND day_of_week = ?',
      whereArgs: [profile, tomorrowWeekday],
      orderBy: 'start_time ASC',
    ) as List>;
    final tomorrowSchedules =
        tomorrowRaw.map((e) => ScheduleItem.fromMap(e)).toList();

    final Set<String> tomorrowItems = {};
    for (final s in tomorrowSchedules) {
      tomorrowItems.addAll(s.packingList);
    }

    final Map<String, bool> checkStates = {};
    for (final item in tomorrowItems) {
      final key = '${profile}_${tomorrowWeekday}_$item';
      checkStates[item] = await db.isPackingItemChecked(key);
    }

    return {
      'daySchedules': daySchedules,
      'tomorrowWeekday': tomorrowWeekday,
      'tomorrowItems': tomorrowItems.toList(),
      'checkStates': checkStates,
    };
  }

  void _showAddScheduleDialog(BuildContext context, String activeProfile) {
    final subjectCtrl = TextEditingController();
    final startCtrl = TextEditingController(text: '07:00');
    final endCtrl = TextEditingController(text: '08:30');
    final roomCtrl = TextEditingController();
    final uniformCtrl = TextEditingController(text: 'Putih Abu-Abu');
    final packingCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Tambah Jadwal (${_dayNames[_selectedDay]})'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: subjectCtrl,
                decoration: const InputDecoration(labelText: 'Mata Pelajaran'),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: startCtrl,
                      decoration: const InputDecoration(labelText: 'Jam Mulai'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: endCtrl,
                      decoration: const InputDecoration(labelText: 'Jam Selesai'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                controller: roomCtrl,
                decoration: const InputDecoration(labelText: 'Ruang / Lab'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: uniformCtrl,
                decoration: const InputDecoration(labelText: 'Seragam Hari Ini'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: packingCtrl,
                decoration: const InputDecoration(
                  labelText: 'Tag Barang Bawaan (pisahkan koma)',
                  hintText: 'Jas Lab, Kalkulator, Buku Paket',
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
              if (subjectCtrl.text.trim().isEmpty) return;
              final item = ScheduleItem(
                profile: activeProfile,
                dayOfWeek: _selectedDay,
                startTime: startCtrl.text.trim(),
                endTime: endCtrl.text.trim(),
                subjectName: subjectCtrl.text.trim(),
                room: roomCtrl.text.trim(),
                uniform: uniformCtrl.text.trim(),
                packingItems: packingCtrl.text.trim(),
              );
              await DatabaseHelper.instance
                  .insertRow('schedules', item.toMap());
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

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppStateProvider>(context);
    final activeProfile = appState.activeScheduleProfile;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Dynamic Schedule & Tas',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            onPressed: () => _showAddScheduleDialog(context, activeProfile),
            icon: const Icon(Icons.add_circle_outline),
            tooltip: 'Tambah Jadwal',
          ),
        ],
      ),
      body: Column(
        children: [
          // SWITCH PROFIL JADWAL AKTIF
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: _profiles.map((prof) {
                final isSelected = prof == activeProfile;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(prof),
                    selected: isSelected,
                    onSelected: (_) {
                      appState.setScheduleProfile(prof);
                    },
                  ),
                );
              }).toList(),
            ),
          ),

          // PILIHAN HARI
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: _dayNames.entries.map((entry) {
                final selected = entry.key == _selectedDay;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: FilterChip(
                    label: Text(entry.value),
                    selected: selected,
                    onSelected: (_) {
                      setState(() => _selectedDay = entry.key);
                    },
                  ),
                );
              }).toList(),
            ),
          ),

          Expanded(
            child: FutureBuilder(
              future: _loadScheduleAndPacking(activeProfile),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final data = snapshot.data as Map<String, dynamic>;
                final List<ScheduleItem> schedules =
                    data['daySchedules'] as List<ScheduleItem>;
                final int tomorrowWeekday = data['tomorrowWeekday'] as int;
                final List<String> tomorrowItems =
                    data['tomorrowItems'] as List<String>;
                final Map<String, bool> checkStates =
                    data['checkStates'] as Map<String, bool>;

                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (activeProfile == 'Libur/Jamkos')
                      Card(
                        color: Theme.of(context).colorScheme.tertiaryContainer,
                        child: const Padding(
                          padding: EdgeInsets.all(16),
                          child: Text(
                            'Mode Libur / Jamkos aktif! Gunakan waktu luang untuk cicil Flashcard atau Proyek DIY.',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      )
                    else if (schedules.isEmpty)
                      const Card(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Text('Belum ada jadwal pelajaran di hari ini.'),
                        ),
                      )
                    else
                      ...schedules.map(
                        (s) => Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          child: ListTile(
                            leading: CircleAvatar(
                              child: Text(s.startTime.substring(0, 2)),
                            ),
                            title: Text(
                              s.subjectName,
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                    '${s.startTime} - ${s.endTime} • ${s.room}'),
                                if (s.packingItems.isNotEmpty)
                                  Text(
                                    'Bawaan: ${s.packingItems}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color:
                                          Theme.of(context).colorScheme.primary,
                                    ),
                                  ),
                              ],
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () async {
                                await DatabaseHelper.instance.deleteRow(
                                  'schedules',
                                  'id = ?',
                                  [s.id],
                                );
                                appState.notifyAllScreens();
                              },
                            ),
                          ),
                        ),
                      ),

                    const SizedBox(height: 16),

                    // AUTO-GENERATED SMART PACKING LIST UNTUK BESOK
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.checklist_rtl,
                                    color:
                                        Theme.of(context).colorScheme.primary),
                                const SizedBox(width: 8),
                                Text(
                                  'Smart Packing List (${_dayNames[tomorrowWeekday] ?? 'Besok'})',
                                  style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Otomatis ditarik dari tag barang bawaan jadwal besok:',
                              style: TextStyle(fontSize: 12),
                            ),
                            const Divider(height: 18),
                            if (tomorrowItems.isEmpty)
                              const Text(
                                  'Tidak ada barang khusus yang perlu disiapkan.')
                            else
                              ...tomorrowItems.map((item) {
                                final checked = checkStates[item] ?? false;
                                final key =
                                    '${activeProfile}_${tomorrowWeekday}_$item';
                                return CheckboxListTile(
                                  contentPadding: EdgeInsets.zero,
                                  value: checked,
                                  title: Text(
                                    item,
                                    style: TextStyle(
                                      decoration: checked
                                          ? TextDecoration.lineThrough
                                          : null,
                                    ),
                                  ),
                                  onChanged: (val) async {
                                    await DatabaseHelper.instance
                                        .togglePackingItem(key, val ?? false);
                                    appState.notifyAllScreens();
                                  },
                                );
                              }),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
