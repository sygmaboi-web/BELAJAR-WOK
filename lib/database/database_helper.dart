import 'package:intl/intl.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  DatabaseHelper._privateConstructor();
  static final DatabaseHelper instance = DatabaseHelper._privateConstructor();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'personal_student_os.db');

    return await openDatabase(
      path,
      version: 1,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE app_settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE schedules (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        profile TEXT NOT NULL,
        day_of_week INTEGER NOT NULL,
        start_time TEXT NOT NULL,
        end_time TEXT NOT NULL,
        subject_name TEXT NOT NULL,
        room TEXT NOT NULL,
        uniform TEXT NOT NULL,
        packing_items TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE packing_checks (
        item_key TEXT PRIMARY KEY,
        is_checked INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE subjects (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        kkm REAL NOT NULL DEFAULT 75.0,
        target_score REAL NOT NULL DEFAULT 85.0,
        teacher_note TEXT NOT NULL,
        room TEXT NOT NULL,
        weight_tugas REAL NOT NULL DEFAULT 30.0,
        weight_uh REAL NOT NULL DEFAULT 30.0,
        weight_pts REAL NOT NULL DEFAULT 20.0,
        weight_pas REAL NOT NULL DEFAULT 20.0
      )
    ''');

    await db.execute('''
      CREATE TABLE grades (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        subject_id INTEGER NOT NULL,
        component TEXT NOT NULL,
        title TEXT NOT NULL,
        score REAL NOT NULL,
        date TEXT NOT NULL,
        FOREIGN KEY (subject_id) REFERENCES subjects (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE tasks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        subject_name TEXT NOT NULL,
        deadline TEXT NOT NULL,
        priority TEXT NOT NULL,
        is_completed INTEGER NOT NULL DEFAULT 0,
        is_group INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE subtasks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        task_id INTEGER NOT NULL,
        title TEXT NOT NULL,
        assignee TEXT NOT NULL,
        is_done INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (task_id) REFERENCES tasks (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE flashcards (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        subject_name TEXT NOT NULL,
        title TEXT NOT NULL,
        image_path TEXT NOT NULL,
        notes TEXT NOT NULL,
        next_review_date TEXT NOT NULL,
        interval_days INTEGER NOT NULL DEFAULT 1
      )
    ''');

    await db.execute('''
      CREATE TABLE occlusion_boxes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        flashcard_id INTEGER NOT NULL,
        x REAL NOT NULL,
        y REAL NOT NULL,
        width REAL NOT NULL,
        height REAL NOT NULL,
        label TEXT NOT NULL,
        FOREIGN KEY (flashcard_id) REFERENCES flashcards (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE budget_config (
        id INTEGER PRIMARY KEY,
        period_name TEXT NOT NULL,
        total_budget REAL NOT NULL,
        start_date TEXT NOT NULL,
        end_date TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE envelopes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        target_amount REAL NOT NULL,
        current_amount REAL NOT NULL,
        icon_name TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        amount REAL NOT NULL,
        category TEXT NOT NULL,
        date TEXT NOT NULL,
        unpaid_notes TEXT NOT NULL,
        is_settled INTEGER NOT NULL DEFAULT 1
      )
    ''');

    await db.execute('''
      CREATE TABLE events (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        category TEXT NOT NULL,
        deadline_date TEXT NOT NULL,
        event_date TEXT NOT NULL,
        notes TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE setlists (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        song_title TEXT NOT NULL,
        artist TEXT NOT NULL,
        bpm INTEGER NOT NULL,
        status TEXT NOT NULL,
        notes TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE bom_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        project_name TEXT NOT NULL,
        item_name TEXT NOT NULL,
        estimated_price REAL NOT NULL,
        status TEXT NOT NULL,
        store_link TEXT NOT NULL
      )
    ''');

    await _seedInitialData(db);
  }

  Future<void> _seedInitialData(Database db) async {
    final now = DateTime.now();
    final fmt = DateFormat('yyyy-MM-dd');
    final todayStr = fmt.format(now);
    final inTwoDaysStr = fmt.format(now.add(const Duration(days: 2)));
    final inThreeDaysStr = fmt.format(now.add(const Duration(days: 3)));
    final inFiveDaysStr = fmt.format(now.add(const Duration(days: 5)));

    await db.insert('app_settings', {
      'key': 'active_schedule_profile',
      'value': 'Reguler',
    });

    final sampleSchedules = [
      {
        'profile': 'Reguler',
        'day_of_week': 1,
        'start_time': '07:00',
        'end_time': '08:30',
        'subject_name': 'Matematika Lanjut',
        'room': 'R. X-5',
        'uniform': 'Putih Abu-Abu + Topi Dasi',
        'packing_items': 'Buku Paket Matematika, Buku Kotak-Kotak, Penggaris',
      },
      {
        'profile': 'Reguler',
        'day_of_week': 1,
        'start_time': '09:00',
        'end_time': '11:00',
        'subject_name': 'Fisika',
        'room': 'Lab Fisika',
        'uniform': 'Putih Abu-Abu + Topi Dasi',
        'packing_items': 'Jas Lab, Kalkulator Scientific, Modul Praktikum',
      },
      {
        'profile': 'Reguler',
        'day_of_week': 2,
        'start_time': '07:00',
        'end_time': '09:00',
        'subject_name': 'Bahasa Inggris',
        'room': 'R. X-5',
        'uniform': 'Putih Abu-Abu',
        'packing_items': 'Buku Tulis Inggris, Kamus Saku',
      },
      {
        'profile': 'Reguler',
        'day_of_week': 2,
        'start_time': '09:30',
        'end_time': '11:30',
        'subject_name': 'Informatika',
        'room': 'Lab Komputer 2',
        'uniform': 'Putih Abu-Abu',
        'packing_items': 'Flashdisk, Buku Catatan Algoritma',
      },
      {
        'profile': 'Reguler',
        'day_of_week': 3,
        'start_time': '07:00',
        'end_time': '08:30',
        'subject_name': 'PJOK',
        'room': 'Lapangan Utama',
        'uniform': 'Seragam Olahraga Sekolah',
        'packing_items': 'Baju Ganti, Sepatu Kets, Botol Minum Besar',
      },
      {
        'profile': 'Reguler',
        'day_of_week': 3,
        'start_time': '09:00',
        'end_time': '11:00',
        'subject_name': 'Kimia',
        'room': 'Lab Kimia',
        'uniform': 'Putih Abu-Abu',
        'packing_items': 'Jas Lab, Tabel Periodik, Kacamata Safety',
      },
      {
        'profile': 'Reguler',
        'day_of_week': 4,
        'start_time': '07:00',
        'end_time': '09:00',
        'subject_name': 'Sejarah Indonesia',
        'room': 'R. X-5',
        'uniform': 'Batik Sekolah',
        'packing_items': 'Buku Paket Sejarah, Stabilo',
      },
      {
        'profile': 'Reguler',
        'day_of_week': 4,
        'start_time': '09:30',
        'end_time': '11:30',
        'subject_name': 'Seni Budaya',
        'room': 'Ruang Seni',
        'uniform': 'Batik Sekolah',
        'packing_items': 'Buku Gambar A3, Pensil 2B & 6B, Penghapus',
      },
      {
        'profile': 'Reguler',
        'day_of_week': 5,
        'start_time': '07:00',
        'end_time': '08:30',
        'subject_name': 'Geografi',
        'room': 'R. X-5',
        'uniform': 'Seragam Pramuka',
        'packing_items': 'Atlas, Pensil Warna, Penggaris',
      },
      {
        'profile': 'Reguler',
        'day_of_week': 5,
        'start_time': '09:00',
        'end_time': '10:30',
        'subject_name': 'Bahasa Indonesia',
        'room': 'R. X-5',
        'uniform': 'Seragam Pramuka',
        'packing_items': 'Buku Teks Bahasa Indonesia, Kliping Artikel',
      },
      {
        'profile': 'Blok/Praktikum',
        'day_of_week': now.weekday > 5 ? 1 : now.weekday,
        'start_time': '07:00',
        'end_time': '11:30',
        'subject_name': 'Blok Praktikum Sains (Fisika & Kimia)',
        'room': 'Lab Terpadu',
        'uniform': 'Seragam Praktikum / Jas Lab',
        'packing_items': 'Jas Lab, Laporan Sementara, Kalkulator',
      },
      {
        'profile': 'Ujian',
        'day_of_week': now.weekday > 5 ? 1 : now.weekday,
        'start_time': '07:30',
        'end_time': '09:30',
        'subject_name': 'Ujian Tengah Semester - Matematika',
        'room': 'Ruang Ujian 04',
        'uniform': 'Putih Abu-Abu Lengkap',
        'packing_items': 'Kartu Peserta Ujian, Pensil 2B, Papan Jalan',
      },
    ];

    for (final s in sampleSchedules) {
      await db.insert('schedules', s);
    }

    final mathId = await db.insert('subjects', {
      'name': 'Matematika Lanjut',
      'kkm': 75.0,
      'target_score': 88.0,
      'teacher_note': 'Wajib tulis langkah penyelesaian lengkap',
      'room': 'R. X-5',
      'weight_tugas': 30.0,
      'weight_uh': 30.0,
      'weight_pts': 20.0,
      'weight_pas': 20.0,
    });
    await db.insert('grades', {
      'subject_id': mathId,
      'component': 'Tugas',
      'title': 'Latihan Fungsi Eksponen',
      'score': 90.0,
      'date': todayStr,
    });
    await db.insert('grades', {
      'subject_id': mathId,
      'component': 'UH',
      'title': 'UH 1 Logaritma',
      'score': 82.0,
      'date': todayStr,
    });
    await db.insert('grades', {
      'subject_id': mathId,
      'component': 'PTS',
      'title': 'PTS Ganjil',
      'score': 84.0,
      'date': todayStr,
    });

    final fisikaId = await db.insert('subjects', {
      'name': 'Fisika',
      'kkm': 75.0,
      'target_score': 85.0,
      'teacher_note': 'Perhatikan satuan SI pada setiap jawaban',
      'room': 'Lab Fisika',
      'weight_tugas': 30.0,
      'weight_uh': 30.0,
      'weight_pts': 20.0,
      'weight_pas': 20.0,
    });
    await db.insert('grades', {
      'subject_id': fisikaId,
      'component': 'Tugas',
      'title': 'Laporan Pengukuran Jangka Sorong',
      'score': 80.0,
      'date': todayStr,
    });
    await db.insert('grades', {
      'subject_id': fisikaId,
      'component': 'UH',
      'title': 'UH Kinematika Gerak Lurus',
      'score': 74.0,
      'date': todayStr,
    });

    final groupTaskId = await db.insert('tasks', {
      'title': 'Laporan Observasi Lapangan & Presentasi',
      'subject_name': 'Bahasa Indonesia',
      'deadline': inTwoDaysStr,
      'priority': 'Tinggi',
      'is_completed': 0,
      'is_group': 1,
    });
    await db.insert('subtasks', {
      'task_id': groupTaskId,
      'title': 'Susun Bab 1 Pendahuluan & Metodologi',
      'assignee': 'Saya',
      'is_done': 1,
    });
    await db.insert('subtasks', {
      'task_id': groupTaskId,
      'title': 'Edit Foto Dokumentasi & Layout Slide',
      'assignee': 'Farelle',
      'is_done': 0,
    });
    await db.insert('subtasks', {
      'task_id': groupTaskId,
      'title': 'Proofreading & Cetak Jilid',
      'assignee': 'Khansa',
      'is_done': 0,
    });

    await db.insert('tasks', {
      'title': 'Soal Latihan Gerak Parabola No. 1-15',
      'subject_name': 'Fisika',
      'deadline': inFiveDaysStr,
      'priority': 'Sedang',
      'is_completed': 0,
      'is_group': 0,
    });

    await db.insert('flashcards', {
      'subject_name': 'Fisika',
      'title': 'Rumus Gerak Lurus Berubah Beraturan (GLBB)',
      'image_path': '',
      'notes': 'v_t = v_0 + a.t | s = v_0.t + 1/2.a.t^2 | v_t^2 = v_0^2 + 2.a.s',
      'next_review_date': todayStr,
      'interval_days': 1,
    });

    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final endOfWeek = startOfWeek.add(const Duration(days: 6));
    await db.insert('budget_config', {
      'id': 1,
      'period_name': 'Mingguan',
      'total_budget': 210000.0,
      'start_date': fmt.format(startOfWeek),
      'end_date': fmt.format(endOfWeek),
    });

    await db.insert('envelopes', {
      'name': 'Servis & Ganti Oli Motor',
      'target_amount': 150000.0,
      'current_amount': 85000.0,
      'icon_name': 'two_wheeler',
    });
    await db.insert('envelopes', {
      'name': 'Komponen & Gear Hobi',
      'target_amount': 300000.0,
      'current_amount': 120000.0,
      'icon_name': 'build',
    });
    await db.insert('envelopes', {
      'name': 'Dana Darurat Pelajar',
      'target_amount': 200000.0,
      'current_amount': 100000.0,
      'icon_name': 'shield',
    });

    await db.insert('transactions', {
      'title': 'Makan Siang Kantin + Es Teh',
      'amount': 15000.0,
      'category': 'Makan/Minum',
      'date': DateFormat('yyyy-MM-dd HH:mm').format(now),
      'unpaid_notes': '',
      'is_settled': 1,
    });
    await db.insert('transactions', {
      'title': 'Print & Jilid Makalah Kelompok',
      'amount': 24000.0,
      'category': 'Print/Fotokopi',
      'date': DateFormat('yyyy-MM-dd HH:mm').format(now),
      'unpaid_notes': 'Patungan Rp8.000/orang (Denish belum bayar)',
      'is_settled': 0,
    });

    await db.insert('events', {
      'title': 'Ulangan Harian Fisika & Matematika',
      'category': 'Ujian',
      'deadline_date': inTwoDaysStr,
      'event_date': inTwoDaysStr,
      'notes': 'Materi Kinematika dan Logaritma',
    });
    await db.insert('events', {
      'title': 'Submit Karya Lomba Fotografi Pelajar 2026',
      'category': 'Lomba',
      'deadline_date': inThreeDaysStr,
      'event_date': inFiveDaysStr,
      'notes': 'Upload 2 foto human interest + caption',
    });

    await db.insert('setlists', {
      'song_title': 'Tafsir Mistik',
      'artist': 'The Panturas',
      'bpm': 142,
      'status': 'Siap Tampil',
      'notes': 'Jaga tempo snare di bagian bridge',
    });
    await db.insert('setlists', {
      'song_title': 'Bahas Bahasa',
      'artist': 'Barasuara',
      'bpm': 128,
      'status': 'Lumayan',
      'notes': 'Sinkronisasi dinamika drum & bass di intro',
    });

    await db.insert('bom_items', {
      'project_name': 'DIY Drum Module & Pad',
      'item_name': 'Sensor Piezo 27mm + Kabel Shielded',
      'estimated_price': 35000.0,
      'status': 'Sudah Ada',
      'store_link': 'Toko Elektronik Pasar Lama',
    });
    await db.insert('bom_items', {
      'project_name': 'DIY Drum Module & Pad',
      'item_name': 'Multiplexer 74HC4051 & Soket DB25',
      'estimated_price': 48000.0,
      'status': 'Belum Beli',
      'store_link': 'Tokopedia - Komponen MCU',
    });
  }

  Future<String> getActiveScheduleProfile() async {
    final db = await database;
    final res = await db.query(
      'app_settings',
      where: 'key = ?',
      whereArgs: ['active_schedule_profile'],
    );
    if (res.isNotEmpty) {
      return res.first['value'] as String;
    }
    return 'Reguler';
  }

  Future<void> setActiveScheduleProfile(String profile) async {
    final db = await database;
    await db.insert(
      'app_settings',
      {'key': 'active_schedule_profile', 'value': profile},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<bool> isPackingItemChecked(String itemKey) async {
    final db = await database;
    final res = await db.query(
      'packing_checks',
      where: 'item_key = ?',
      whereArgs: [itemKey],
    );
    if (res.isEmpty) return false;
    return (res.first['is_checked'] as int) == 1;
  }

  Future<void> togglePackingItem(String itemKey, bool checked) async {
    final db = await database;
    await db.insert(
      'packing_checks',
      {'item_key': itemKey, 'is_checked': checked ? 1 : 0},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<dynamic> queryAll(
    String table, {
    String? where,
    List<Object?>? whereArgs,
    String? orderBy,
  }) async {
    final db = await database;
    return await db.query(
      table,
      where: where,
      whereArgs: whereArgs,
      orderBy: orderBy,
    );
  }

  Future<int> insertRow(String table, Map<String, dynamic> values) async {
    final db = await database;
    return await db.insert(table, values);
  }

  Future<int> updateRow(
    String table,
    Map<String, dynamic> values,
    String where,
    List<Object?> whereArgs,
  ) async {
    final db = await database;
    return await db.update(table, values, where: where, whereArgs: whereArgs);
  }

  Future<int> deleteRow(
    String table,
    String where,
    List<Object?> whereArgs,
  ) async {
    final db = await database;
    return await db.delete(table, where: where, whereArgs: whereArgs);
  }
}
