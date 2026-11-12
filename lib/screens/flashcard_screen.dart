import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import '../database/database_helper.dart';
import '../main.dart';
import '../models/flashcard_model.dart';
import '../models/schedule_model.dart';

class FlashcardScreen extends StatefulWidget {
  const FlashcardScreen({super.key});

  @override
  State<FlashcardScreen> createState() => _FlashcardScreenState();
}

class _FlashcardScreenState extends State<FlashcardScreen> {
  final ImagePicker _picker = ImagePicker();

  Future<List<FlashcardItem>> _loadFlashcards() async {
    final db = DatabaseHelper.instance;
    final cardsRaw = await db.queryAll(
      'flashcards',
      orderBy: 'next_review_date ASC, id DESC',
    );
    final List<FlashcardItem> result = [];

    for (final c in cardsRaw) {
      final boxesRaw = await db.queryAll(
        'occlusion_boxes',
        where: 'flashcard_id = ?',
        whereArgs: [c['id']],
      );
      final boxes = boxesRaw.map((b) => OcclusionBox.fromMap(b)).toList();
      result.add(FlashcardItem.fromMap(c, boxes: boxes));
    }
    return result;
  }

  Future<String> _saveImagePermanently(String sourcePath) async {
    final appDir = await getApplicationDocumentsDirectory();
    final fileName =
        'fc_${DateTime.now().millisecondsSinceEpoch}${p.extension(sourcePath)}';
    final savedFile = await File(sourcePath).copy(p.join(appDir.path, fileName));
    return savedFile.path;
  }

  Future<void> _startCreateFlashcardFlow(BuildContext context) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Ambil Foto Catatan (Kamera)'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Pilih Gambar dari Galeri'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (source == null) return;

    final XFile? picked = await _picker.pickImage(
      source: source,
      imageQuality: 85,
    );
    if (picked == null) return;

    final permanentPath = await _saveImagePermanently(picked.path);
    if (!context.mounted) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OcclusionEditorPage(imagePath: permanentPath),
      ),
    );
  }

  Future<void> _startQuickReview5Min(BuildContext context) async {
    final db = DatabaseHelper.instance;
    final allCards = await _loadFlashcards();
    if (allCards.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Belum ada kartu flashcard untuk direview.')),
        );
      }
      return;
    }

    final now = DateTime.now();
    final todayStr = DateFormat('yyyy-MM-dd').format(now);
    final tomorrowWeekday = (now.weekday % 7) + 1;
    final activeProfile = await db.getActiveScheduleProfile();

    final tomorrowSchedRaw = await db.queryAll(
      'schedules',
      where: 'profile = ? AND day_of_week = ?',
      whereArgs: [activeProfile, tomorrowWeekday],
    );
    final tomorrowSubjects = tomorrowSchedRaw
        .map((e) => ScheduleItem.fromMap(e).subjectName.toLowerCase())
        .toSet();

    // Prioritaskan kartu jatuh tempo hari ini ATAU berasal dari mapel besok
    final priorityCards = allCards.where((c) {
      final isDue = c.nextReviewDate.compareTo(todayStr) <= 0;
      final isTomorrowSubj =
          tomorrowSubjects.contains(c.subjectName.toLowerCase());
      return isDue || isTomorrowSubj;
    }).toList();

    final pool = priorityCards.isNotEmpty ? priorityCards : List.of(allCards);
    pool.shuffle(Random());
    final selectedDeck = pool.take(10).toList();

    if (!context.mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FlashcardStudyPage(
          deck: selectedDeck,
          sessionTitle: 'Quick-Review 5 Menit (${selectedDeck.length} Kartu)',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Provider.of<AppStateProvider>(context);
    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Visual Flashcard Vault',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            onPressed: () => _startCreateFlashcardFlow(context),
            icon: const Icon(Icons.add_a_photo),
            tooltip: 'Buat Kartu Foto',
          ),
        ],
      ),
      body: FutureBuilder<List<FlashcardItem>>(
        future: _loadFlashcards(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final cards = snapshot.data!;
          final dueCount = cards
              .where((c) => c.nextReviewDate.compareTo(todayStr) <= 0)
              .length;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // BANNER QUICK-REVIEW 5 MENIT
              Card(
                color: Theme.of(context).colorScheme.secondaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.bolt,
                            color: Theme.of(context)
                                .colorScheme
                                .onSecondaryContainer,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Quick-Review 5 Menit',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSecondaryContainer,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '$dueCount kartu jatuh tempo hari ini. Latih memori aktif dengan maksimal 10 kartu acak.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Theme.of(context)
                              .colorScheme
                              .onSecondaryContainer,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          FilledButton.icon(
                            onPressed: () => _startQuickReview5Min(context),
                            icon: const Icon(Icons.play_arrow),
                            label: const Text('Mulai Quick-Review'),
                          ),
                          const SizedBox(width: 10),
                          OutlinedButton.icon(
                            onPressed: () => _startCreateFlashcardFlow(context),
                            icon: const Icon(Icons.camera_alt_outlined),
                            label: const Text('Foto Catatan'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              const Text(
                'Koleksi Kartu Materi',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),

              if (cards.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                        'Belum ada kartu. Tekan "Foto Catatan" untuk menutup rumus/jawaban dari buku catatanmu!'),
                  ),
                )
              else
                ...cards.map((card) {
                  final isDue = card.nextReviewDate.compareTo(todayStr) <= 0;
                  final hasImage = card.imagePath.isNotEmpty &&
                      File(card.imagePath).existsSync();

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      leading: hasImage
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.file(
                                File(card.imagePath),
                                width: 52,
                                height: 52,
                                fit: BoxFit.cover,
                              ),
                            )
                          : const CircleAvatar(child: Icon(Icons.style)),
                      title: Text(
                        card.title,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        '${card.subjectName} • ${card.boxes.length} kotak penutup • Review: ${isDue ? "Hari Ini" : card.nextReviewDate}',
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.play_circle_fill),
                            tooltip: 'Pelajari Kartu Ini',
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => FlashcardStudyPage(
                                    deck: [card],
                                    sessionTitle: card.title,
                                  ),
                                ),
                              );
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () async {
                              await DatabaseHelper.instance.deleteRow(
                                'flashcards',
                                'id = ?',
                                [card.id],
                              );
                              if (context.mounted) {
                                Provider.of<AppStateProvider>(context,
                                        listen: false)
                                    .notifyAllScreens();
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                }),
            ],
          );
        },
      ),
    );
  }
}

// ==================== HALAMAN EDITOR KOTAK PENUTUP (IMAGE OCCLUSION) ====================
class OcclusionEditorPage extends StatefulWidget {
  final String imagePath;

  const OcclusionEditorPage({super.key, required this.imagePath});

  @override
  State<OcclusionEditorPage> createState() => _OcclusionEditorPageState();
}

class _OcclusionEditorPageState extends State<OcclusionEditorPage> {
  final TextEditingController _titleCtrl = TextEditingController();
  final TextEditingController _subjectCtrl = TextEditingController();
  final TextEditingController _notesCtrl = TextEditingController();

  final List<Rect> _normalizedRects = [];
  Offset? _dragStart;
  Offset? _dragCurrent;

  Future<void> _saveFlashcard() async {
    if (_titleCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Isi judul kartu terlebih dahulu.')),
      );
      return;
    }

    final db = DatabaseHelper.instance;
    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());

    final card = FlashcardItem(
      subjectName: _subjectCtrl.text.trim().isEmpty
          ? 'Umum'
          : _subjectCtrl.text.trim(),
      title: _titleCtrl.text.trim(),
      imagePath: widget.imagePath,
      notes: _notesCtrl.text.trim(),
      nextReviewDate: todayStr,
      intervalDays: 1,
    );

    final cardId = await db.insertRow('flashcards', card.toMap());

    for (int i = 0; i < _normalizedRects.length; i++) {
      final r = _normalizedRects[i];
      final box = OcclusionBox(
        flashcardId: cardId,
        x: r.left,
        y: r.top,
        width: r.width,
        height: r.height,
        label: 'Jawaban #${i + 1}',
      );
      await db.insertRow('occlusion_boxes', box.toMap());
    }

    if (mounted) {
      Provider.of<AppStateProvider>(context, listen: false).notifyAllScreens();
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tutup Rumus / Jawaban'),
        actions: [
          IconButton(
            onPressed: _normalizedRects.isEmpty
                ? null
                : () => setState(() => _normalizedRects.removeLast()),
            icon: const Icon(Icons.undo),
            tooltip: 'Hapus Kotak Terakhir',
          ),
          FilledButton(
            onPressed: _saveFlashcard,
            child: const Text('Simpan'),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _titleCtrl,
            decoration: const InputDecoration(
              labelText: 'Judul Kartu / Topik',
              hintText: 'Contoh: Reaksi Redoks & Biloks',
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _subjectCtrl,
            decoration: const InputDecoration(
              labelText: 'Mata Pelajaran',
              hintText: 'Contoh: Kimia',
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Seret jari di atas gambar di bawah untuk membuat kotak penutup jawaban:',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              const height = 340.0;

              return GestureDetector(
                onPanStart: (details) {
                  setState(() {
                    _dragStart = details.localPosition;
                    _dragCurrent = details.localPosition;
                  });
                },
                onPanUpdate: (details) {
                  setState(() {
                    _dragCurrent = Offset(
                      details.localPosition.dx.clamp(0.0, width),
                      details.localPosition.dy.clamp(0.0, height),
                    );
                  });
                },
                onPanEnd: (_) {
                  if (_dragStart != null && _dragCurrent != null) {
                    final left =
                        min(_dragStart!.dx, _dragCurrent!.dx) / width;
                    final top =
                        min(_dragStart!.dy, _dragCurrent!.dy) / height;
                    final boxW =
                        (_dragStart!.dx - _dragCurrent!.dx).abs() / width;
                    final boxH =
                        (_dragStart!.dy - _dragCurrent!.dy).abs() / height;

                    if (boxW > 0.03 && boxH > 0.03) {
                      _normalizedRects.add(Rect.fromLTWH(left, top, boxW, boxH));
                    }
                  }
                  setState(() {
                    _dragStart = null;
                    _dragCurrent = null;
                  });
                },
                child: Container(
                  width: width,
                  height: height,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: Theme.of(context).colorScheme.outline),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.file(
                          File(widget.imagePath),
                          fit: BoxFit.contain,
                        ),
                        ..._normalizedRects.asMap().entries.map((entry) {
                          final idx = entry.key;
                          final r = entry.value;
                          return Positioned(
                            left: r.left * width,
                            top: r.top * height,
                            width: r.width * width,
                            height: r.height * height,
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.amber.withOpacity(0.85),
                                border:
                                    Border.all(color: Colors.deepOrange, width: 2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                '#${idx + 1}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                ),
                              ),
                            ),
                          );
                        }),
                        if (_dragStart != null && _dragCurrent != null)
                          Positioned(
                            left: min(_dragStart!.dx, _dragCurrent!.dx),
                            top: min(_dragStart!.dy, _dragCurrent!.dy),
                            width: (_dragStart!.dx - _dragCurrent!.dx).abs(),
                            height: (_dragStart!.dy - _dragCurrent!.dy).abs(),
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.blue.withOpacity(0.4),
                                border: Border.all(color: Colors.blue, width: 2),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _notesCtrl,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Catatan Tambahan / Petunjuk (Opsional)',
            ),
          ),
        ],
      ),
    );
  }
}

// ==================== HALAMAN MODE BELAJAR (TAP-TO-REVEAL & LEITNER) ====================
class FlashcardStudyPage extends StatefulWidget {
  final List<FlashcardItem> deck;
  final String sessionTitle;

  const FlashcardStudyPage({
    super.key,
    required this.deck,
    required this.sessionTitle,
  });

  @override
  State<FlashcardStudyPage> createState() => _FlashcardStudyPageState();
}

class _FlashcardStudyPageState extends State<FlashcardStudyPage> {
  int _currentIndex = 0;
  final Set<int> _revealedBoxIndices = {};
  bool _textNoteRevealed = false;

  Future<void> _rateCard(int daysToAdd) async {
    final card = widget.deck[_currentIndex];
    final nextDate = DateTime.now().add(Duration(days: daysToAdd));
    final nextDateStr = DateFormat('yyyy-MM-dd').format(nextDate);

    await DatabaseHelper.instance.updateRow(
      'flashcards',
      {
        'next_review_date': nextDateStr,
        'interval_days': daysToAdd,
      },
      'id = ?',
      [card.id],
    );

    if (!mounted) return;
    Provider.of<AppStateProvider>(context, listen: false).notifyAllScreens();

    if (_currentIndex < widget.deck.length - 1) {
      setState(() {
        _currentIndex++;
        _revealedBoxIndices.clear();
        _textNoteRevealed = false;
      });
    } else {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Sesi review selesai! Jadwal Leitner diperbarui.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final card = widget.deck[_currentIndex];
    final hasImage =
        card.imagePath.isNotEmpty && File(card.imagePath).existsSync();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${_currentIndex + 1}/${widget.deck.length} • ${card.subjectName}',
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              card.title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            const Text(
              'Ketuk kotak penutup untuk membuka jawaban, lalu nilai tingkat kesulitanmu:',
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: hasImage
                  ? LayoutBuilder(
                      builder: (context, constraints) {
                        final w = constraints.maxWidth;
                        final h = constraints.maxHeight;

                        return Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                                color: Theme.of(context).colorScheme.outline),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                Image.file(
                                  File(card.imagePath),
                                  fit: BoxFit.contain,
                                ),
                                ...card.boxes.asMap().entries.map((entry) {
                                  final idx = entry.key;
                                  final box = entry.value;
                                  final isRevealed =
                                      _revealedBoxIndices.contains(idx);

                                  return Positioned(
                                    left: box.x * w,
                                    top: box.y * h,
                                    width: box.width * w,
                                    height: box.height * h,
                                    child: GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          if (isRevealed) {
                                            _revealedBoxIndices.remove(idx);
                                          } else {
                                            _revealedBoxIndices.add(idx);
                                          }
                                        });
                                      },
                                      child: AnimatedContainer(
                                        duration:
                                            const Duration(milliseconds: 200),
                                        decoration: BoxDecoration(
                                          color: isRevealed
                                              ? Colors.transparent
                                              : Theme.of(context)
                                                  .colorScheme
                                                  .primary,
                                          borderRadius:
                                              BorderRadius.circular(6),
                                          border: Border.all(
                                            color: isRevealed
                                                ? Colors.green
                                                : Colors.white,
                                            width: 2,
                                          ),
                                        ),
                                        alignment: Alignment.center,
                                        child: isRevealed
                                            ? null
                                            : const Icon(
                                                Icons.visibility_off,
                                                color: Colors.white,
                                                size: 18,
                                              ),
                                      ),
                                    ),
                                  );
                                }),
                              ],
                            ),
                          ),
                        );
                      },
                    )
                  : GestureDetector(
                      onTap: () => setState(
                          () => _textNoteRevealed = !_textNoteRevealed),
                      child: Card(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              _textNoteRevealed
                                  ? card.notes
                                  : 'Ketuk kartu ini untuk menampilkan jawaban / rumus',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                      ),
                    ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: Colors.red),
                    onPressed: () => _rateCard(1),
                    child: const Text('Susah\n(+1 hr)',
                        textAlign: TextAlign.center),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    style:
                        FilledButton.styleFrom(backgroundColor: Colors.orange),
                    onPressed: () => _rateCard(3),
                    child: const Text('Lumayan\n(+3 hr)',
                        textAlign: TextAlign.center),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    style:
                        FilledButton.styleFrom(backgroundColor: Colors.green),
                    onPressed: () => _rateCard(7),
                    child: const Text('Gampang\n(+7 hr)',
                        textAlign: TextAlign.center),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
