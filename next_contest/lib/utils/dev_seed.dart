import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import '../models/event.dart';
import '../services/database_service.dart';

/// Inserts demo data for May 2026 when none exists.
/// Must only be called in debug builds.
Future<void> seedMayData() async {
  assert(kDebugMode, 'seedMayData must only be called in debug builds');
  final db = DatabaseService();
  try {
    final existing = await db.getAllEvents();
    if (existing.any((e) => e.startDate.year == 2026 && e.startDate.month == 5)) return;

    final seeds = [
      Event(title: '근로자의 날', startDate: DateTime(2026, 5, 1), endDate: DateTime(2026, 5, 1), isAllDay: true, colorValue: 0xFFE53935),
      Event(title: '가족 여행', startDate: DateTime(2026, 5, 3), endDate: DateTime(2026, 5, 6), isAllDay: true, colorValue: 0xFF00ACC1),
      Event(title: '어린이날', startDate: DateTime(2026, 5, 5), endDate: DateTime(2026, 5, 5), isAllDay: true, colorValue: 0xFFFB8C00),
      Event(title: '어버이날', startDate: DateTime(2026, 5, 8), endDate: DateTime(2026, 5, 8), isAllDay: true, colorValue: 0xFFE91E8C),
      Event(title: '건강검진', startDate: DateTime(2026, 5, 9), endDate: DateTime(2026, 5, 9), startTimeMinutes: 10 * 60, endTimeMinutes: 11 * 60 + 30, colorValue: 0xFF3D5AFE),
      Event(title: '팀 프로젝트 회의', startDate: DateTime(2026, 5, 12), endDate: DateTime(2026, 5, 12), startTimeMinutes: 14 * 60, endTimeMinutes: 15 * 60 + 30, colorValue: 0xFF9C27B0),
      Event(title: '점심 약속', startDate: DateTime(2026, 5, 13), endDate: DateTime(2026, 5, 13), startTimeMinutes: 12 * 60, endTimeMinutes: 13 * 60, colorValue: 0xFF43A047),
      Event(title: '스승의 날', startDate: DateTime(2026, 5, 15), endDate: DateTime(2026, 5, 15), isAllDay: true, colorValue: 0xFFFB8C00),
      Event(title: '생일 파티', startDate: DateTime(2026, 5, 16), endDate: DateTime(2026, 5, 16), startTimeMinutes: 18 * 60, endTimeMinutes: 21 * 60, colorValue: 0xFF9C27B0),
      Event(title: 'PT 트레이닝', startDate: DateTime(2026, 5, 20), endDate: DateTime(2026, 5, 20), startTimeMinutes: 7 * 60, endTimeMinutes: 8 * 60, isRecurring: true, recurrenceType: 'weekly', colorValue: 0xFF009688),
      Event(title: '부모님 저녁식사', startDate: DateTime(2026, 5, 22), endDate: DateTime(2026, 5, 22), startTimeMinutes: 19 * 60, endTimeMinutes: 21 * 60, colorValue: 0xFFE91E8C),
      Event(title: '부처님오신날', startDate: DateTime(2026, 5, 25), endDate: DateTime(2026, 5, 25), isAllDay: true, colorValue: 0xFFFB8C00),
      Event(title: '영화 관람', startDate: DateTime(2026, 5, 27), endDate: DateTime(2026, 5, 27), startTimeMinutes: 15 * 60, endTimeMinutes: 17 * 60 + 30, colorValue: 0xFF546E7A),
      Event(title: '여름 여행', startDate: DateTime(2026, 5, 29), endDate: DateTime(2026, 6, 1), isAllDay: true, colorValue: 0xFF00ACC1),
      Event(title: '월간 정리', startDate: DateTime(2026, 5, 31), endDate: DateTime(2026, 5, 31), startTimeMinutes: 10 * 60, endTimeMinutes: 12 * 60, colorValue: 0xFF6D4C41),
    ];

    for (final event in seeds) {
      await db.addEvent(event);
    }
  } catch (e, st) {
    if (kDebugMode) debugPrint('seedMayData failed: $e\n$st');
    rethrow;
  }
}
