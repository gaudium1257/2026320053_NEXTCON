import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/event.dart';
import '../models/diary.dart';

class DatabaseService {
  static final DatabaseService _i = DatabaseService._();
  factory DatabaseService() => _i;

  DatabaseService._() {
    _dbFuture = _init();
  }

  late final Future<Database> _dbFuture;

  Future<Database> _init() async {
    final dbPath = await getDatabasesPath();
    return openDatabase(
      join(dbPath, 'dayce.db'),
      version: 3,
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('ALTER TABLE diaries ADD COLUMN mood TEXT');
        }
        if (oldVersion < 3) {
          await db.execute('ALTER TABLE events ADD COLUMN color INTEGER');
        }
      },
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE events (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT NOT NULL,
            startDate TEXT NOT NULL,
            startTimeMinutes INTEGER,
            endDate TEXT NOT NULL,
            endTimeMinutes INTEGER,
            memo TEXT,
            isAllDay INTEGER NOT NULL DEFAULT 0,
            isRecurring INTEGER NOT NULL DEFAULT 0,
            recurrenceType TEXT,
            recurrenceEndDate TEXT,
            color INTEGER
          )
        ''');
        await db.execute(
            'CREATE INDEX idx_events_startDate ON events(startDate)');
        await db.execute('''
          CREATE TABLE diaries (
            dateKey TEXT PRIMARY KEY,
            content TEXT NOT NULL,
            mood TEXT,
            createdAt TEXT NOT NULL,
            updatedAt TEXT NOT NULL
          )
        ''');
      },
    );
  }

  // ── Events ─────────────────────────────────────────────────────────────────

  Future<List<Event>> getAllEvents() async {
    final db = await _dbFuture;
    final rows = await db.query('events', orderBy: 'startDate ASC');
    return rows.map(Event.fromMap).toList();
  }

  /// Inserts event and returns it with the assigned [id].
  Future<Event> addEvent(Event event) async {
    final db = await _dbFuture;
    final id = await db.insert('events', event.toMap());
    return Event.fromMap({...event.toMap(), 'id': id});
  }

  Future<void> updateEvent(Event event) async {
    assert(event.id != null, 'updateEvent called with null id');
    final db = await _dbFuture;
    await db.update(
      'events',
      event.toMap(),
      where: 'id = ?',
      whereArgs: [int.parse(event.id!)],
    );
  }

  Future<void> deleteEvent(String id) async {
    final db = await _dbFuture;
    await db.delete('events', where: 'id = ?', whereArgs: [int.parse(id)]);
  }

  // ── Diaries ────────────────────────────────────────────────────────────────

  Future<List<Diary>> getAllDiaries() async {
    final db = await _dbFuture;
    final rows = await db.query('diaries', orderBy: 'dateKey DESC');
    return rows.map(Diary.fromMap).toList();
  }

  Future<Diary?> getDiaryByDateKey(String dateKey) async {
    final db = await _dbFuture;
    final rows = await db.query(
      'diaries',
      where: 'dateKey = ?',
      whereArgs: [dateKey],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Diary.fromMap(rows.first);
  }

  Future<void> saveDiary(Diary diary) async {
    final db = await _dbFuture;
    await db.insert(
      'diaries',
      diary.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteDiary(String dateKey) async {
    final db = await _dbFuture;
    await db.delete('diaries', where: 'dateKey = ?', whereArgs: [dateKey]);
  }

  Future<void> seedMayData() async {
    final db = await _dbFuture;
    final existing = await db.query('events',
        where: "startDate LIKE '2026-05%'", limit: 1);
    if (existing.isNotEmpty) return;

    final rows = [
      {'title': '근로자의 날', 'startDate': '2026-05-01', 'endDate': '2026-05-01', 'isAllDay': 1, 'color': 0xFFE53935},
      {'title': '가족 여행', 'startDate': '2026-05-03', 'endDate': '2026-05-06', 'isAllDay': 1, 'color': 0xFF00ACC1},
      {'title': '어린이날', 'startDate': '2026-05-05', 'endDate': '2026-05-05', 'isAllDay': 1, 'color': 0xFFFB8C00},
      {'title': '어버이날', 'startDate': '2026-05-08', 'endDate': '2026-05-08', 'isAllDay': 1, 'color': 0xFFE91E8C},
      {'title': '건강검진', 'startDate': '2026-05-09', 'endDate': '2026-05-09', 'startTime': 10 * 60, 'endTime': 11 * 60 + 30, 'color': 0xFF3D5AFE},
      {'title': '팀 프로젝트 회의', 'startDate': '2026-05-12', 'endDate': '2026-05-12', 'startTime': 14 * 60, 'endTime': 15 * 60 + 30, 'color': 0xFF9C27B0},
      {'title': '점심 약속', 'startDate': '2026-05-13', 'endDate': '2026-05-13', 'startTime': 12 * 60, 'endTime': 13 * 60, 'color': 0xFF43A047},
      {'title': '스승의 날', 'startDate': '2026-05-15', 'endDate': '2026-05-15', 'isAllDay': 1, 'color': 0xFFFB8C00},
      {'title': '생일 파티', 'startDate': '2026-05-16', 'endDate': '2026-05-16', 'startTime': 18 * 60, 'endTime': 21 * 60, 'color': 0xFF9C27B0},
      {'title': 'PT 트레이닝', 'startDate': '2026-05-20', 'endDate': '2026-05-20', 'startTime': 7 * 60, 'endTime': 8 * 60, 'isRecurring': 1, 'recurrenceType': 'weekly', 'color': 0xFF009688},
      {'title': '부모님 저녁식사', 'startDate': '2026-05-22', 'endDate': '2026-05-22', 'startTime': 19 * 60, 'endTime': 21 * 60, 'color': 0xFFE91E8C},
      {'title': '부처님오신날', 'startDate': '2026-05-25', 'endDate': '2026-05-25', 'isAllDay': 1, 'color': 0xFFFB8C00},
      {'title': '영화 관람', 'startDate': '2026-05-27', 'endDate': '2026-05-27', 'startTime': 15 * 60, 'endTime': 17 * 60 + 30, 'color': 0xFF546E7A},
      {'title': '여름 여행', 'startDate': '2026-05-29', 'endDate': '2026-06-01', 'isAllDay': 1, 'color': 0xFF00ACC1},
      {'title': '월간 정리', 'startDate': '2026-05-31', 'endDate': '2026-05-31', 'startTime': 10 * 60, 'endTime': 12 * 60, 'color': 0xFF6D4C41},
    ];

    for (final r in rows) {
      await db.insert('events', {
        'title': r['title'],
        'startDate': r['startDate'],
        'endDate': r['endDate'],
        'startTimeMinutes': r['startTime'],
        'endTimeMinutes': r['endTime'],
        'memo': null,
        'isAllDay': r['isAllDay'] ?? 0,
        'isRecurring': r['isRecurring'] ?? 0,
        'recurrenceType': r['recurrenceType'],
        'recurrenceEndDate': null,
        'color': r['color'],
      });
    }
  }
}
