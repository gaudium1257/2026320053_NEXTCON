import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static final SettingsService _i = SettingsService._();
  factory SettingsService() => _i;
  SettingsService._();

  SharedPreferences? _p;

  Future<void> init() async {
    try {
      _p = await SharedPreferences.getInstance();
    } catch (e, st) {
      if (kDebugMode) debugPrint('SettingsService.init failed: $e\n$st');
      _p = null;
    }
  }

  Future<void> _safeWrite(Future<bool> Function() action) async {
    try {
      await action();
    } catch (e, st) {
      debugPrint('SettingsService write failed: $e\n$st');
    }
  }

  // ── 캘린더 ────────────────────────────────────────────────────────────────

  /// 기본 보기: 0=월, 1=주, 2=일, 3=년
  int get defaultViewMode => _p?.getInt('defaultViewMode') ?? 0;
  Future<void> setDefaultViewMode(int v) async {
    if (v < 0 || v > 3) return; // 범위 검증
    await _safeWrite(() => _p?.setInt('defaultViewMode', v) ?? Future.value(false));
  }

  /// 주 시작 요일: true=일요일, false=월요일
  bool get weekStartsOnSunday => _p?.getBool('weekStartsOnSunday') ?? true;
  Future<void> setWeekStartsOnSunday(bool v) async =>
      _safeWrite(() => _p?.setBool('weekStartsOnSunday', v) ?? Future.value(false));

  // ── 일정 ──────────────────────────────────────────────────────────────────

  /// 기본 일정 색상 (ARGB int)
  int get defaultEventColor =>
      _p?.getInt('defaultEventColor') ?? 0xFF3D5AFE;
  Future<void> setDefaultEventColor(int v) async {
    if (v < 0 || v > 0xFFFFFFFF) return; // ARGB 범위 검증
    await _safeWrite(() => _p?.setInt('defaultEventColor', v) ?? Future.value(false));
  }

  // ── 일기 ──────────────────────────────────────────────────────────────────

  /// 글쓰기 창에 눈금선 표시
  bool get showRuledLines => _p?.getBool('showRuledLines') ?? true;
  Future<void> setShowRuledLines(bool v) async =>
      _safeWrite(() => _p?.setBool('showRuledLines', v) ?? Future.value(false));

  /// 기본 기분 이모지 (null = 선택 안 함)
  String? get defaultMood => _p?.getString('defaultMood');
  Future<void> setDefaultMood(String? v) async {
    if (v != null && v.length > 10) return; // 길이 제한
    if (v == null) {
      await _safeWrite(() => _p?.remove('defaultMood') ?? Future.value(false));
    } else {
      await _safeWrite(() => _p?.setString('defaultMood', v) ?? Future.value(false));
    }
  }

  /// 일기 알림 ON/OFF
  bool get diaryReminderEnabled =>
      _p?.getBool('diaryReminderEnabled') ?? false;
  Future<void> setDiaryReminderEnabled(bool v) async =>
      _safeWrite(() => _p?.setBool('diaryReminderEnabled', v) ?? Future.value(false));

  /// 일기 알림 시간 (hour)
  int get diaryReminderHour => _p?.getInt('diaryReminderHour') ?? 21;
  Future<void> setDiaryReminderHour(int v) async {
    if (v < 0 || v > 23) return; // 시간 범위 검증
    await _safeWrite(() => _p?.setInt('diaryReminderHour', v) ?? Future.value(false));
  }

  /// 일기 알림 시간 (minute)
  int get diaryReminderMinute => _p?.getInt('diaryReminderMinute') ?? 0;
  Future<void> setDiaryReminderMinute(int v) async {
    if (v < 0 || v > 59) return; // 분 범위 검증
    await _safeWrite(() => _p?.setInt('diaryReminderMinute', v) ?? Future.value(false));
  }
}
