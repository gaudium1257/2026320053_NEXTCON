import 'package:flutter/material.dart';
import '../utils/date_utils.dart';

class Event {
  int? id;        // SQLite INTEGER PRIMARY KEY — was String? before
  String title;
  DateTime startDate;
  int? startTimeMinutes;
  DateTime endDate;
  int? endTimeMinutes;
  String? memo;
  bool isAllDay;
  bool isRecurring;
  String? recurrenceType; // 'daily' | 'weekly' | 'monthly' | 'yearly'
  DateTime? recurrenceEndDate;
  int? colorValue; // ARGB int; null = default primary

  Event({
    this.id,
    required this.title,
    required this.startDate,
    this.startTimeMinutes,
    required this.endDate,
    this.endTimeMinutes,
    this.memo,
    this.isAllDay = false,
    this.isRecurring = false,
    this.recurrenceType,
    this.recurrenceEndDate,
    this.colorValue,
  });

  Color get displayColor => Color(colorValue ?? 0xFF3D5AFE);

  TimeOfDay? get startTime => startTimeMinutes != null
      ? TimeOfDay(hour: startTimeMinutes! ~/ 60, minute: startTimeMinutes! % 60)
      : null;

  TimeOfDay? get endTime => endTimeMinutes != null
      ? TimeOfDay(hour: endTimeMinutes! ~/ 60, minute: endTimeMinutes! % 60)
      : null;

  String get timeDisplay {
    if (isAllDay) return '종일';
    if (startTime == null) return '';
    final s = _fmtTime(startTime!);
    if (endTime == null) return s;
    return '$s ~ ${_fmtTime(endTime!)}';
  }

  String get recurrenceLabel {
    switch (recurrenceType) {
      case 'daily': return '매일';
      case 'weekly': return '매주';
      case 'monthly': return '매달';
      case 'yearly': return '매년';
      default: return '';
    }
  }

  static String _fmtTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  /// 'yyyy-MM-dd' string for [date] — delegates to the shared utility.
  static String dateKey(DateTime date) => dayKey(date);

  // ── SQLite ─────────────────────────────────────────────────────────────────

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'title': title,
      'startDate': dayKey(startDate),
      'startTimeMinutes': startTimeMinutes,
      'endDate': dayKey(endDate),
      'endTimeMinutes': endTimeMinutes,
      'memo': memo,
      'isAllDay': isAllDay ? 1 : 0,
      'isRecurring': isRecurring ? 1 : 0,
      'recurrenceType': recurrenceType,
      'recurrenceEndDate':
          recurrenceEndDate != null ? dayKey(recurrenceEndDate!) : null,
      'color': colorValue,
    };
    if (id != null) map['id'] = id;
    return map;
  }

  factory Event.fromMap(Map<String, dynamic> map) {
    try {
      final title = map['title'] as String?;
      if (title == null || title.trim().isEmpty) {
        throw FormatException('Event title cannot be null or empty');
      }

      final startDateStr = map['startDate'] as String?;
      final endDateStr = map['endDate'] as String?;
      if (startDateStr == null || endDateStr == null) {
        throw FormatException('Event dates cannot be null');
      }

      final startDate = DateTime.parse(startDateStr);
      final endDate = DateTime.parse(endDateStr);

      if (endDate.isBefore(startDate)) {
        throw FormatException('End date cannot be before start date');
      }

      final startTimeMinutes = map['startTimeMinutes'] as int?;
      final endTimeMinutes = map['endTimeMinutes'] as int?;

      // 시간 값 범위 검증
      if (startTimeMinutes != null && (startTimeMinutes < 0 || startTimeMinutes >= 24 * 60)) {
        throw FormatException('Invalid start time minutes');
      }
      if (endTimeMinutes != null && (endTimeMinutes < 0 || endTimeMinutes >= 24 * 60)) {
        throw FormatException('Invalid end time minutes');
      }

      final isAllDay = (map['isAllDay'] as int?) == 1;
      final isRecurring = (map['isRecurring'] as int?) == 1;

      return Event(
        id: map['id'] as int?,
        title: title.trim(),
        startDate: startDate,
        startTimeMinutes: startTimeMinutes,
        endDate: endDate,
        endTimeMinutes: endTimeMinutes,
        memo: (map['memo'] as String?)?.trim(),
        isAllDay: isAllDay,
        isRecurring: isRecurring,
        recurrenceType: map['recurrenceType'] as String?,
        recurrenceEndDate: map['recurrenceEndDate'] != null
            ? DateTime.parse(map['recurrenceEndDate'] as String)
            : null,
        colorValue: map['color'] as int?,
      );
    } catch (e) {
      throw FormatException('Invalid event data: $e');
    }
  }

  // ── Logic ──────────────────────────────────────────────────────────────────

  bool occursOn(DateTime date) {
    // startDate, endDate, recurrenceEndDate come from DateTime.parse('yyyy-MM-dd')
    // and are always date-only (midnight). Only the argument needs normalizing.
    final d = DateTime(date.year, date.month, date.day);

    if (!isRecurring) return !d.isBefore(startDate) && !d.isAfter(endDate);

    if (d.isBefore(startDate)) return false;
    if (recurrenceEndDate != null && d.isAfter(recurrenceEndDate!)) return false;
    switch (recurrenceType) {
      case 'daily': return true;
      case 'weekly': return d.weekday == startDate.weekday;
      case 'monthly': return d.day == startDate.day;
      case 'yearly': return d.month == startDate.month && d.day == startDate.day;
      default: return false;
    }
  }

  bool get isMultiDay => endDate.isAfter(startDate);
}
