import 'package:flutter/material.dart';

class Event {
  String? id;
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

  static String dateKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  // ── SQLite ─────────────────────────────────────────────────────────────────

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'title': title,
      'startDate': dateKey(startDate),
      'startTimeMinutes': startTimeMinutes,
      'endDate': dateKey(endDate),
      'endTimeMinutes': endTimeMinutes,
      'memo': memo,
      'isAllDay': isAllDay ? 1 : 0,
      'isRecurring': isRecurring ? 1 : 0,
      'recurrenceType': recurrenceType,
      'recurrenceEndDate':
          recurrenceEndDate != null ? dateKey(recurrenceEndDate!) : null,
      'color': colorValue,
    };
    if (id != null) map['id'] = int.parse(id!);
    return map;
  }

  factory Event.fromMap(Map<String, dynamic> map) {
    return Event(
      id: map['id']?.toString(),
      title: map['title'] as String,
      startDate: DateTime.parse(map['startDate'] as String),
      startTimeMinutes: map['startTimeMinutes'] as int?,
      endDate: DateTime.parse(map['endDate'] as String),
      endTimeMinutes: map['endTimeMinutes'] as int?,
      memo: map['memo'] as String?,
      isAllDay: (map['isAllDay'] as int) == 1,
      isRecurring: (map['isRecurring'] as int) == 1,
      recurrenceType: map['recurrenceType'] as String?,
      recurrenceEndDate: map['recurrenceEndDate'] != null
          ? DateTime.parse(map['recurrenceEndDate'] as String)
          : null,
      colorValue: map['color'] as int?,
    );
  }

  // ── Logic ──────────────────────────────────────────────────────────────────

  bool occursOn(DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    final start = DateTime(startDate.year, startDate.month, startDate.day);
    final end = DateTime(endDate.year, endDate.month, endDate.day);

    if (!isRecurring) return !d.isBefore(start) && !d.isAfter(end);

    if (d.isBefore(start)) return false;
    if (recurrenceEndDate != null) {
      final re = DateTime(recurrenceEndDate!.year,
          recurrenceEndDate!.month, recurrenceEndDate!.day);
      if (d.isAfter(re)) return false;
    }
    switch (recurrenceType) {
      case 'daily': return true;
      case 'weekly': return d.weekday == start.weekday;
      case 'monthly': return d.day == start.day;
      case 'yearly': return d.month == start.month && d.day == start.day;
      default: return false;
    }
  }

  bool get isMultiDay {
    final s = DateTime(startDate.year, startDate.month, startDate.day);
    final e = DateTime(endDate.year, endDate.month, endDate.day);
    return e.isAfter(s);
  }
}
