import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../database/database_helper.dart';
import '../main.dart';
import '../models/project_model.dart';

class ProjectScreen extends StatefulWidget {
  const ProjectScreen({super.key});

  @override
  State<ProjectScreen> createState() => _ProjectScreenState();
}

class _ProjectScreenState extends State<ProjectScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final NumberFormat _currencyFmt =
      NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showAddEventDialog(BuildContext context) {
    final titleCtrl = TextEditingController();
    final deadlineCtrl = TextEditingController(
      text: DateFormat('yyyy-MM-dd')
          .format(DateTime.now().add(const Duration(days: 3))),
    );
    final eventDateCtrl = TextEditingController(
      text: DateFormat('yyyy-MM-dd')
          .format(DateTime.now().add(const Duration(days: 5))),
    );
    final notesCtrl = TextEditingController();
    String category = 'Lomba';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Tambah Event / Lomba / Ujian'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(labelText: 'Nama Kegiatan'),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: category,
                  decoration: const InputDecoration(labelText: 'Kategori'),
                  items: ['Lomba', 'Event/Pentas', 'Latihan', 'Ujian']
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) setDialogState(() => category = val);
                  },
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: deadlineCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Deadline Karya (YYYY-MM-DD)'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: eventDateCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Tanggal Hari-H (YYYY-MM-DD)'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: notesCtrl,
                  decoration: const InputDecoration(labelText: 'Catatan'),
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
                final item = EventItem(
                  title: titleCtrl.text.trim(),
                  category: category,
                  deadlineDate: deadlineCtrl.text.trim(),
                  eventDate: eventDateCtrl.text.trim(),
                  notes: notesCtrl.text.trim(),
                );
                await DatabaseHelper.instance
                    .insertRow('events', item.toMap());
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

  void _showAddSetlistDialog(BuildContext context) {
    final songCtrl = TextEditingController();
    final artistCtrl = TextEditingController();
    final bpmCtrl = TextEditingController(text: '120');
    final notesCtrl = TextEditingController();
    String status = 'Baru Ngulik';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Tambah Lagu Setlist'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: songCtrl,
                  decoration: const InputDecoration(labelText: 'Judul Lagu'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: artistCtrl,
                  decoration: const InputDecoration(labelText: 'Artis / Band'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: bpmCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Tempo (BPM)'),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: status,
                  decoration: const InputDecoration(labelText: 'Status Progres'),
                  items: ['Baru Ngulik', 'Lumayan', 'Siap Tampil']
                      .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) setDialogState(() => status = val);
                  },
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: notesCtrl,
                  decoration:
                      const InputDecoration(labelText: 'Catatan Evaluasi'),
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
                if (songCtrl.text.trim().isEmpty) return;
                final item = SetlistItem(
                  songTitle: songCtrl.text.trim(),
                  artist: artistCtrl.text.trim(),
                  bpm: int.tryParse(bpmCtrl.text.trim()) ?? 120,
                  status: status,
                  notes: notesCtrl.text.trim(),
                );
                await DatabaseHelper.instance
                    .insertRow('setlists', item.toMap());
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

  void _showAddBomDialog(BuildContext context) {
    final projectCtrl = TextEditingController();
    final itemCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final storeCtrl = TextEditingController();
    String status = 'Belum Beli';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Tambah Komponen / Bahan DIY'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: projectCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Nama Proyek',
                    hintText: 'Contoh: DIY Drum Module / Custom Denim',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: itemCtrl,
                  decoration:
                      const InputDecoration(labelText: 'Nama Komponen / Bahan'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: priceCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Estimasi Harga (Rp)',
                    prefixText: 'Rp ',
                  ),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: status,
                  decoration: const InputDecoration(labelText: 'Status'),
                  items: ['Belum Beli', 'Sudah Ada']
                      .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) setDialogState(() => status = val);
                  },
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: storeCtrl,
                  decoration:
                      const InputDecoration(labelText: 'Nama Toko / Link'),
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
                if (itemCtrl.text.trim().isEmpty) return;
                final item = BomItem(
                  projectName: projectCtrl.text.trim().isEmpty
                      ? 'Proyek DIY'
                      : projectCtrl.text.trim(),
                  itemName: itemCtrl.text.trim(),
                  estimatedPrice: double.tryParse(priceCtrl.text.trim()) ?? 0,
                  status: status,
                  storeLink: storeCtrl.text.trim(),
                );
                await DatabaseHelper.instance
                    .insertRow('bom_items', item.toMap());
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

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppStateProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Creative & Project Logbook',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Lomba & Event'),
            Tab(text: 'Setlist Band'),
            Tab(text: 'DIY & BOM'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // TAB 1: COMPETITION & EVENT TRACKER
          FutureBuilder(
            future: DatabaseHelper.instance
                .queryAll('events', orderBy: 'event_date ASC'),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final rawList = snapshot.data as List>;
              final events =
                  rawList.map((e) => EventItem.fromMap(e)).toList();

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Jadwal Lomba, Event & Ujian',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      FilledButton.icon(
                        onPressed: () => _showAddEventDialog(context),
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Event'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ...events.map(
                    (ev) => Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: ev.category == 'Ujian'
                              ? Colors.red.withOpacity(0.2)
                              : Colors.blue.withOpacity(0.2),
                          child: Icon(
                            ev.category == 'Ujian'
                                ? Icons.school
                                : Icons.emoji_events,
                          ),
                        ),
                        title: Text(
                          ev.title,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          '${ev.category} • Deadline: ${ev.deadlineDate} | Hari-H: ${ev.eventDate}\n${ev.notes}',
                        ),
                        isThreeLine: true,
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () async {
                            await DatabaseHelper.instance
                                .deleteRow('events', 'id = ?', [ev.id]);
                            appState.notifyAllScreens();
                          },
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),

          // TAB 2: REHEARSAL & SETLIST MANAGER
          FutureBuilder(
            future:
                DatabaseHelper.instance.queryAll('setlists', orderBy: 'id DESC'),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final rawList = snapshot.data as List>;
              final songs =
                  rawList.map((e) => SetlistItem.fromMap(e)).toList();

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Setlist & Evaluasi Latihan',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      FilledButton.icon(
                        onPressed: () => _showAddSetlistDialog(context),
                        icon: const Icon(Icons.music_note, size: 18),
                        label: const Text('Lagu'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ...songs.map(
                    (song) => Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        title: Text(
                          '${song.songTitle} - ${song.artist}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          '${song.bpm} BPM • Status: ${song.status}\nCatatan: ${song.notes}',
                        ),
                        isThreeLine: true,
                        trailing: PopupMenuButton<String>(
                          onSelected: (newStatus) async {
                            await DatabaseHelper.instance.updateRow(
                              'setlists',
                              {'status': newStatus},
                              'id = ?',
                              [song.id],
                            );
                            appState.notifyAllScreens();
                          },
                          itemBuilder: (_) => const [
                            PopupMenuItem(
                                value: 'Baru Ngulik',
                                child: Text('Baru Ngulik')),
                            PopupMenuItem(
                                value: 'Lumayan', child: Text('Lumayan')),
                            PopupMenuItem(
                                value: 'Siap Tampil',
                                child: Text('Siap Tampil')),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),

          // TAB 3: DIY / CRAFT INVENTORY & BOM
          FutureBuilder(
            future: DatabaseHelper.instance
                .queryAll('bom_items', orderBy: 'project_name ASC'),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final rawList = snapshot.data as List>;
              final items =
                  rawList.map((e) => BomItem.fromMap(e)).toList();

              final double totalUnbought = items
                  .where((i) => i.status == 'Belum Beli')
                  .fold(0.0, (sum, i) => sum + i.estimatedPrice);

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    color: Theme.of(context).colorScheme.secondaryContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Estimasi Belanja Komponen',
                                style: TextStyle(fontSize: 12),
                              ),
                              Text(
                                _currencyFmt.format(totalUnbought),
                                style: const TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          FilledButton.icon(
                            onPressed: () => _showAddBomDialog(context),
                            icon: const Icon(Icons.add_shopping_cart, size: 18),
                            label: const Text('Item BOM'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...items.map(
                    (bom) => Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        leading: Checkbox(
                          value: bom.status == 'Sudah Ada',
                          onChanged: (val) async {
                            await DatabaseHelper.instance.updateRow(
                              'bom_items',
                              {
                                'status':
                                    (val ?? false) ? 'Sudah Ada' : 'Belum Beli'
                              },
                              'id = ?',
                              [bom.id],
                            );
                            appState.notifyAllScreens();
                          },
                        ),
                        title: Text(
                          bom.itemName,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          'Proyek: ${bom.projectName} • ${_currencyFmt.format(bom.estimatedPrice)}\nToko: ${bom.storeLink}',
                        ),
                        isThreeLine: true,
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () async {
                            await DatabaseHelper.instance
                                .deleteRow('bom_items', 'id = ?', [bom.id]);
                            appState.notifyAllScreens();
                          },
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
