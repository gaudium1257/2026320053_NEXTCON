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
}
