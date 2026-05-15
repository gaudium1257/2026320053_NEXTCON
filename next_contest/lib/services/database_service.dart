import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
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
    try {
      final db = await _dbFuture;
      final rows = await db.query('events', orderBy: 'startDate ASC');
      final events = <Event>[];
      for (final row in rows) {
        try {
          events.add(Event.fromMap(row));
        } catch (e) {
          if (kDebugMode) debugPrint('DatabaseService.getAllEvents: Invalid event data: $e');
          // 잘못된 데이터는 건너뜀
        }
      }
      return events;
    } catch (e, st) {
      if (kDebugMode) debugPrint('DatabaseService.getAllEvents failed: $e\n$st');
      rethrow;
    }
  }

  /// Inserts event and returns it with the assigned [id].
  Future<Event> addEvent(Event event) async {
    try {
      final db = await _dbFuture;
      final id = await db.insert('events', event.toMap());
      return Event.fromMap({...event.toMap(), 'id': id});
    } catch (e, st) {
      if (kDebugMode) debugPrint('DatabaseService.addEvent failed: $e\n$st');
      rethrow;
    }
  }

  Future<void> updateEvent(Event event) async {
    assert(event.id != null, 'updateEvent called with null id');
    try {
      final db = await _dbFuture;
      await db.update(
        'events',
        event.toMap(),
        where: 'id = ?',
        whereArgs: [event.id],
      );
    } catch (e, st) {
      if (kDebugMode) debugPrint('DatabaseService.updateEvent failed: $e\n$st');
      rethrow;
    }
  }

  Future<void> deleteEvent(int id) async {
    try {
      final db = await _dbFuture;
      await db.delete('events', where: 'id = ?', whereArgs: [id]);
    } catch (e, st) {
      if (kDebugMode) debugPrint('DatabaseService.deleteEvent failed: $e\n$st');
      rethrow;
    }
  }

  // ── Diaries ────────────────────────────────────────────────────────────────

  Future<List<Diary>> getAllDiaries() async {
    try {
      final db = await _dbFuture;
      final rows = await db.query('diaries', orderBy: 'dateKey DESC');
      final diaries = <Diary>[];
      for (final row in rows) {
        try {
          diaries.add(Diary.fromMap(row));
        } catch (e) {
          if (kDebugMode) debugPrint('DatabaseService.getAllDiaries: Invalid diary data: $e');
          // 잘못된 데이터는 건너뜀
        }
      }
      return diaries;
    } catch (e, st) {
      if (kDebugMode) debugPrint('DatabaseService.getAllDiaries failed: $e\n$st');
      rethrow;
    }
  }

  Future<Diary?> getDiaryByDateKey(String dateKey) async {
    try {
      final db = await _dbFuture;
      final rows = await db.query(
        'diaries',
        where: 'dateKey = ?',
        whereArgs: [dateKey],
        limit: 1,
      );
      if (rows.isEmpty) return null;
      try {
        return Diary.fromMap(rows.first);
      } catch (e) {
        if (kDebugMode) debugPrint('DatabaseService.getDiaryByDateKey: Invalid diary data: $e');
        return null;
      }
    } catch (e, st) {
      if (kDebugMode) debugPrint('DatabaseService.getDiaryByDateKey failed: $e\n$st');
      rethrow;
    }
  }

  Future<void> saveDiary(Diary diary) async {
    try {
      final db = await _dbFuture;
      await db.insert(
        'diaries',
        diary.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e, st) {
      if (kDebugMode) debugPrint('DatabaseService.saveDiary failed: $e\n$st');
      rethrow;
    }
  }

  Future<void> deleteDiary(String dateKey) async {
    try {
      final db = await _dbFuture;
      await db.delete('diaries', where: 'dateKey = ?', whereArgs: [dateKey]);
    } catch (e, st) {
      if (kDebugMode) debugPrint('DatabaseService.deleteDiary failed: $e\n$st');
      rethrow;
    }
  }

}
