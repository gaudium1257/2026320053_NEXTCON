import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/event.dart';
import '../models/diary.dart';
import '../services/database_service.dart';
import '../theme/app_theme.dart';
import '../services/settings_service.dart';
import '../utils/date_utils.dart';
import '../utils/calendar_layout.dart';
import 'event_form_screen.dart';
import 'diary_form_screen.dart';
import 'settings_screen.dart';

enum _ViewMode { day, week, month, year }
enum _MonthMode { expanded, compact }

class _DragState {
  bool active = false;
  DateTime? startDay;
  DateTime? endDay;
  int? startRow;
  List<List<DateTime>>? weeks;
  double? rowH;

  void clear() {
    active = false;
    startDay = null;
    endDay = null;
    startRow = null;
    weeks = null;
    rowH = null;
  }
}

// ── Screen ────────────────────────────────────────────────────────────────────

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => CalendarScreenState();
}

class CalendarScreenState extends State<CalendarScreen>
    with TickerProviderStateMixin {
  final _db = DatabaseService();

  late _ViewMode _viewMode;
  _MonthMode _monthMode = _MonthMode.expanded;
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();

  List<Event> _allEvents = [];
  Map<String, List<Event>> _dateIndex = {}; // dayKey → non-recurring events
  Map<String, Diary> _diaryByDate = {};
  List<Event> _selectedEvents = [];
  Diary? _selectedDiary;

  bool _loading = true;

  final _drag = _DragState();

  static const int _kPageMid = 10000;
  late final DateTime _monthOrigin;
  late final DateTime _weekOrigin;
  late final DateTime _dayOrigin;

  // 성능 최적화: PageController를 lazy하게 생성
  PageController? _monthPageCtrl;
  PageController? _weekPageCtrl;
  PageController? _dayPageCtrl;
  PageController? _yearPageCtrl;

  // 성능 최적화: 데이터 로딩 취소 토큰
  bool _isLoadingData = false;

  // 성능 최적화: 현재 뷰 모드의 PageController를 lazy하게 생성
  PageController _getCurrentPageController() {
    switch (_viewMode) {
      case _ViewMode.month:
        _monthPageCtrl ??= PageController(initialPage: _kPageMid);
        return _monthPageCtrl!;
      case _ViewMode.week:
        _weekPageCtrl ??= PageController(initialPage: _kPageMid);
        return _weekPageCtrl!;
      case _ViewMode.day:
        _dayPageCtrl ??= PageController(initialPage: _kPageMid);
        return _dayPageCtrl!;
      case _ViewMode.year:
        _yearPageCtrl ??= PageController(initialPage: _kPageMid);
        return _yearPageCtrl!;
    }
  }

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _monthOrigin = DateTime(now.year, now.month, 1);
    final ws = now.subtract(Duration(days: now.weekday % 7));
    _weekOrigin = DateTime(ws.year, ws.month, ws.day);
    _dayOrigin = DateTime(now.year, now.month, now.day);

    // 현재 뷰 모드에 해당하는 PageController만 생성
    _viewMode = _ViewMode.values[SettingsService().defaultViewMode];
    _getCurrentPageController(); // 현재 뷰 모드의 컨트롤러 생성

    _loadData();
  }

  @override
  void dispose() {
    _monthPageCtrl?.dispose();
    _weekPageCtrl?.dispose();
    _dayPageCtrl?.dispose();
    _yearPageCtrl?.dispose();
    super.dispose();
  }

  // ── Public API (used by MainShell for cross-tab sync) ──────────────────────

  void refresh() => _loadData();

  // ── Data ───────────────────────────────────────────────────────────────────

  Future<void> _loadData() async {
    // 이미 로딩 중이면 중복 호출 방지
    if (_isLoadingData) return;
    _isLoadingData = true;

    try {
      final (events, diaries) = await (
        _db.getAllEvents(),
        _db.getAllDiaries(),
      ).wait;
      if (!mounted) return;
      _setData(events, diaries);
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('데이터를 불러오지 못했어요. 다시 시도해 주세요.')),
      );
    } finally {
      _isLoadingData = false;
    }
  }

  void _setData(List<Event> events, List<Diary> diaries) {
    final diaryMap = {for (final d in diaries) d.dateKey: d};
    final index = _buildDateIndex(events);

    // 성능 최적화: 한 번에 모든 상태 업데이트
    setState(() {
      _allEvents = events;
      _dateIndex = index;
      _diaryByDate = diaryMap;
      _selectedEvents = _eventsForDay(_selectedDay);
      _selectedDiary = diaryMap[dayKey(_selectedDay)];
      _loading = false;
    });
  }

  /// Pre-builds a date-key → events map for non-recurring events so that
  /// day lookups are O(1) instead of O(n).
  // Max days to index for a single multi-day event (covers the app's 2020–2035 range).
  static const _kMaxIndexSpan = 5845;

  Map<String, List<Event>> _buildDateIndex(List<Event> events) {
    final index = <String, List<Event>>{};
    for (final e in events) {
      if (e.isRecurring) continue;
      var d = DateTime(e.startDate.year, e.startDate.month, e.startDate.day);
      final end = DateTime(e.endDate.year, e.endDate.month, e.endDate.day);
      int span = 0;
      while (!d.isAfter(end) && span < _kMaxIndexSpan) {
        index.putIfAbsent(dayKey(d), () => []).add(e);
        d = d.add(const Duration(days: 1));
        span++;
      }
    }
    return index;
  }

  List<Event> _eventsForDay(DateTime day) {
    final result = List<Event>.from(_dateIndex[dayKey(day)] ?? []);
    for (final e in _allEvents) {
      if (e.isRecurring && e.occursOn(day)) result.add(e);
    }
    return result;
  }

  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    setState(() {
      _selectedDay = selectedDay;
      _focusedDay = focusedDay;
      _selectedEvents = _eventsForDay(selectedDay);
      _selectedDiary = _diaryByDate[dayKey(selectedDay)];
    });
  }

  // ── Page ↔ Date helpers ────────────────────────────────────────────────────

  DateTime _monthForPage(int page) => DateTime(
      _monthOrigin.year, _monthOrigin.month + (page - _kPageMid));

  DateTime _weekStartForPage(int page) {
    // _weekOrigin is always the Sunday of the launch week.
    // For Monday-start, shift forward 1 day so each page begins on Monday.
    final sunday = _weekOrigin.add(Duration(days: (page - _kPageMid) * 7));
    return SettingsService().weekStartsOnSunday
        ? sunday
        : sunday.add(const Duration(days: 1));
  }

  DateTime _dayForPage(int page) =>
      _dayOrigin.add(Duration(days: page - _kPageMid));

  int _pageForMonth(DateTime date) =>
      _kPageMid +
      (date.year - _monthOrigin.year) * 12 +
      (date.month - _monthOrigin.month);

  int _pageForWeek(DateTime weekStart) {
    // Normalize weekStart to Sunday before computing the page offset,
    // since _weekOrigin is always a Sunday.
    final sunday = SettingsService().weekStartsOnSunday
        ? weekStart
        : weekStart.subtract(const Duration(days: 1));
    return _kPageMid + sunday.difference(_weekOrigin).inDays ~/ 7;
  }

  int _pageForDay(DateTime day) =>
      _kPageMid +
      DateTime(day.year, day.month, day.day).difference(_dayOrigin).inDays;

  int _pageForYear(int year) => _kPageMid + year - _monthOrigin.year;

  void _setViewMode(_ViewMode mode) {
    setState(() => _viewMode = mode);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final controller = _getCurrentPageController();
      if (controller.hasClients) {
        if (mode == _ViewMode.month) {
          controller.jumpToPage(_pageForMonth(_focusedDay));
        } else if (mode == _ViewMode.week) {
          final sunStart = SettingsService().weekStartsOnSunday;
          final offset = sunStart ? _focusedDay.weekday % 7 : (_focusedDay.weekday - 1) % 7;
          final ws = _focusedDay.subtract(Duration(days: offset));
          controller.jumpToPage(_pageForWeek(DateTime(ws.year, ws.month, ws.day)));
        } else if (mode == _ViewMode.day) {
          controller.jumpToPage(_pageForDay(_focusedDay));
        } else if (mode == _ViewMode.year) {
          controller.jumpToPage(_pageForYear(_focusedDay.year));
        }
      }
    });
  }

  Future<void> _showModeSelection(DateTime day) async {
    final mode = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ModeSelectionSheet(day: day),
    );
    if (mode == null || !mounted) return;
    bool? changed;
    if (mode == 'event') {
      changed = await Navigator.push<bool>(context,
          MaterialPageRoute(builder: (_) => EventFormScreen(initialDate: day)));
    } else if (mode == 'diary') {
      changed = await Navigator.push<bool>(context,
          MaterialPageRoute(builder: (_) => DiaryFormScreen(date: day)));
    }
    if (changed == true) _loadData();
  }

  Future<void> _navigateTo(Widget screen) async {
    final changed = await Navigator.push<bool>(
        context, MaterialPageRoute(builder: (_) => screen));
    if (changed == true) _loadData();
  }

  bool _isInDragRange(DateTime day) {
    if (!_drag.active || _drag.startDay == null || _drag.endDay == null) return false;
    final s = _drag.startDay!.isBefore(_drag.endDay!) ? _drag.startDay! : _drag.endDay!;
    final e = _drag.startDay!.isBefore(_drag.endDay!) ? _drag.endDay! : _drag.startDay!;
    return !day.isBefore(s) && !day.isAfter(e);
  }

  void _endDragSelect() {
    if (!_drag.active || _drag.startDay == null || _drag.endDay == null) return;
    final s = _drag.startDay!.isBefore(_drag.endDay!) ? _drag.startDay! : _drag.endDay!;
    final e = _drag.startDay!.isBefore(_drag.endDay!) ? _drag.endDay! : _drag.startDay!;
    setState(() => _drag.clear());
    _navigateTo(EventFormScreen(initialDate: s, initialEndDate: e));
  }

  // ── Formatting ─────────────────────────────────────────────────────────────

  String _fmtFullDate(DateTime d) =>
      '${d.year}년 ${d.month}월 ${d.day}일 (${koreanWeekday(d)})';

  // ── Scaffold ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leadingWidth: 80,
        leading: _buildViewModeButton(),
        title: const Text('Dayce'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_rounded, size: 22),
            tooltip: '설정',
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
              if (mounted) setState(() {});
            },
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _buildBody(),
      floatingActionButton: FloatingActionButton(
        heroTag: 'calendar_fab',
        onPressed: () => _showModeSelection(_selectedDay),
        child: const Icon(Icons.add_rounded, size: 28),
      ),
    );
  }

  Widget _buildViewModeButton() {
    const labels = {
      _ViewMode.day: '일',
      _ViewMode.week: '주',
      _ViewMode.month: '월',
      _ViewMode.year: '년',
    };
    return PopupMenuButton<_ViewMode>(
      initialValue: _viewMode,
      onSelected: _setViewMode,
      offset: const Offset(0, 48),
      tooltip: '보기 변경',
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.calendar_month_rounded,
              color: AppTheme.primary, size: 20),
          const SizedBox(width: 4),
          Text(
            labels[_viewMode]!,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppTheme.primary,
            ),
          ),
          const Icon(Icons.expand_more_rounded,
              color: AppTheme.primary, size: 16),
        ]),
      ),
      itemBuilder: (ctx) => _ViewMode.values.map((mode) {
        final selected = mode == _viewMode;
        return PopupMenuItem(
          value: mode,
          child: Row(children: [
            if (selected)
              const Icon(Icons.check_rounded, size: 16, color: AppTheme.primary)
            else
              const SizedBox(width: 16),
            const SizedBox(width: 8),
            Text(
              labels[mode]!,
              style: TextStyle(
                fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                color: selected ? AppTheme.primary : AppTheme.textPrimary,
              ),
            ),
          ]),
        );
      }).toList(),
    );
  }

  Widget _buildBody() => switch (_viewMode) {
        _ViewMode.day => _buildDayView(),
        _ViewMode.week => _buildWeekView(),
        _ViewMode.month => _buildMonthView(),
        _ViewMode.year => _buildYearView(),
      };

  // ── Day View — 24h Timeline ────────────────────────────────────────────────

  Widget _buildDayView() {
    return Column(children: [
      Container(
        color: AppTheme.surface,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Row(children: [
          IconButton(
            icon: const Icon(Icons.chevron_left, color: AppTheme.textSecondary),
            onPressed: () => _getCurrentPageController().previousPage(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _selectedDay,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2035),
                );
                if (picked != null) {
                  _onDaySelected(picked, picked);
                  _getCurrentPageController().animateToPage(_pageForDay(picked),
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut);
                }
              },
              child: Text(
                _fmtFullDate(_selectedDay),
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
            onPressed: () => _getCurrentPageController().nextPage(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut),
          ),
        ]),
      ),
      const Divider(height: 1),
      Expanded(
        child: PageView.builder(
          controller: _getCurrentPageController(),
          itemBuilder: (_, page) {
            final day = _dayForPage(page);
            final events = _eventsForDay(day);
            final diary = _diaryByDate[dayKey(day)];
            return _DayPageContent(
              key: ValueKey(day),
              day: day,
              events: events,
              diary: diary,
              onEventTap: (e) => _navigateTo(EventFormScreen(event: e)),
              onDiaryTap: () => _navigateTo(DiaryFormScreen(date: day)),
            );
          },
          onPageChanged: (page) {
            final day = _dayForPage(page);
            setState(() {
              _selectedDay = day;
              _focusedDay = day;
              _selectedEvents = _eventsForDay(day);
              _selectedDiary = _diaryByDate[dayKey(day)];
            });
          },
        ),
      ),
    ]);
  }

  // ── Month View ─────────────────────────────────────────────────────────────

  Widget _buildMonthView() {
    return Column(children: [
      Container(
        color: AppTheme.surface,
        child: Column(children: [
          SizedBox(
            height: 48,
            child: Row(children: [
              IconButton(
                icon: const Icon(Icons.chevron_left,
                    color: AppTheme.textSecondary),
                onPressed: () => _getCurrentPageController().previousPage(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut),
              ),
              Expanded(
                child: Text(
                  fmtMonthYear(_focusedDay.year, _focusedDay.month),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right,
                    color: AppTheme.textSecondary),
                onPressed: () => _getCurrentPageController().nextPage(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut),
              ),
            ]),
          ),
          SizedBox(
            height: 28,
            child: _buildDowHeader(
                sunStart: SettingsService().weekStartsOnSunday)),
        ]),
      ),
      const Divider(height: 1),
      Expanded(
        child: PageView.builder(
          controller: _getCurrentPageController(),
          itemBuilder: (_, page) => _buildMonthPage(_monthForPage(page)),
          onPageChanged: (page) =>
              setState(() => _focusedDay = _monthForPage(page)),
        ),
      ),
    ]);
  }

  Widget _buildMonthPage(DateTime date) {
    final weeks = _buildWeeks(date.year, date.month);
    // Use the enum — not the animation value — to avoid a layout jump at 50%
    final isCompact = _monthMode == _MonthMode.compact;
    if (isCompact) {
      return Column(
        children: weeks.asMap().entries.map((entry) {
          final placed = CalendarLayout.computeWeekLayout(entry.value, _allEvents);
          return _buildCompactWeekRow(
              entry.value, placed, 48.0, date.month, entry.key, weeks);
        }).toList(),
      );
    }
    return LayoutBuilder(builder: (_, constraints) {
      final rowH = constraints.maxHeight / weeks.length;
      return Column(
        children: weeks.asMap().entries.map((entry) {
          final placed = CalendarLayout.computeWeekLayout(entry.value, _allEvents);
          return _buildWeekRow(entry.value, placed,
              fixedRowH: rowH,
              focusedMonth: date.month,
              rowIndex: entry.key,
              allWeeks: weeks);
        }).toList(),
      );
    });
  }

  // ── Shared gesture wrapper ─────────────────────────────────────────────────

  /// Wraps [child] with the tap / long-press gesture handling shared by
  /// both the compact and expanded week rows.
  Widget _wrapWithCalendarGestures({
    required Widget child,
    required List<DateTime> week,
    required double cellW,
    int? focusedMonth,
    int? rowIndex,
    List<List<DateTime>>? allWeeks,
    double? crossRowH,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapUp: (details) {
        if (_drag.active) return;
        final col = (details.localPosition.dx / cellW).floor().clamp(0, 6);
        final day = week[col];
        if (focusedMonth != null && day.month != focusedMonth) {
          _monthPageCtrl?.animateToPage(_pageForMonth(day),
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut);
          return;
        }
        // In week view, tapping the already-selected day opens the action sheet.
        // In month view, tapping a day only selects that date.
        if (isSameDay(day, _selectedDay) && allWeeks == null) {
          _showModeSelection(day);
        } else {
          _onDaySelected(day, day);
        }
      },
      onLongPressStart: (details) {
        final col = (details.localPosition.dx / cellW).floor().clamp(0, 6);
        final day = week[col];
        if (focusedMonth != null && day.month != focusedMonth) return;
        HapticFeedback.heavyImpact();
        setState(() {
          _drag.active = true;
          _drag.startDay = day;
          _drag.endDay = day;
          _drag.startRow = rowIndex;
          _drag.weeks = allWeeks;
          _drag.rowH = crossRowH;
        });
      },
      onLongPressMoveUpdate: (details) {
        if (!_drag.active) return;
        // Cross-row drag: use localPosition.dy to compute which week row the
        // pointer is now in, relative to the row where the drag started.
        if (_drag.weeks != null && _drag.startRow != null && _drag.rowH != null) {
          final rowOffset = (details.localPosition.dy / _drag.rowH!).floor();
          final targetRow =
              (_drag.startRow! + rowOffset).clamp(0, _drag.weeks!.length - 1);
          final col = (details.localPosition.dx / cellW).floor().clamp(0, 6);
          setState(() => _drag.endDay = _drag.weeks![targetRow][col]);
        } else {
          final col = (details.localPosition.dx / cellW).floor().clamp(0, 6);
          setState(() => _drag.endDay = week[col]);
        }
      },
      onLongPressEnd: (_) => _endDragSelect(),
      onLongPressCancel: () => setState(() => _drag.clear()),
      child: child,
    );
  }

  Widget _buildCompactWeekRow(
      List<DateTime> week, List<PlacedEvent> placed, double rowH,
      [int? focusedMonth, int? rowIndex, List<List<DateTime>>? allWeeks]) {
    const dateCellH = 30.0;
    const trackH = 4.0;
    const trackGap = 2.0;
    const maxTracks = 4;
    final today = DateTime.now();

    return LayoutBuilder(builder: (_, constraints) {
      final cellW = constraints.maxWidth / 7;
      return _wrapWithCalendarGestures(
        week: week,
        cellW: cellW,
        focusedMonth: focusedMonth,
        rowIndex: rowIndex,
        allWeeks: allWeeks,
        crossRowH: rowH,
        child: SizedBox(
          height: rowH,
          child: Stack(children: [
            // Date numbers
            Row(
              children: week.map((day) {
                final isOutOfMonth =
                    focusedMonth != null && day.month != focusedMonth;
                final isSel = isSameDay(day, _selectedDay);
                final isToday = isSameDay(day, today);
                final hasDiary = _diaryByDate.containsKey(dayKey(day));
                final isInDrag = _isInDragRange(day);
                return Expanded(
                  child: Stack(children: [
                    Container(
                      height: dateCellH,
                      color: (isInDrag || isSel) ? AppTheme.primaryLight : null,
                      child: Center(
                        child: Container(
                          width: 24,
                          height: 24,
                          decoration: isToday
                              ? BoxDecoration(
                                  color: AppTheme.primary,
                                  shape: BoxShape.circle,
                                  border: hasDiary
                                      ? Border.all(
                                          color: AppTheme.diaryAccent,
                                          width: 1.5)
                                      : null,
                                )
                              : hasDiary
                                  ? BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                          color: AppTheme.diaryAccent,
                                          width: 1.5),
                                    )
                                  : null,
                          child: Center(
                            child: Text(
                              '${day.day}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: (isToday || isSel || isInDrag)
                                    ? FontWeight.w700
                                    : FontWeight.w400,
                                color: isToday
                                    ? Colors.white
                                    : isOutOfMonth
                                        ? AppTheme.textLight
                                        : day.weekday == DateTime.sunday
                                            ? Colors.red.shade500
                                            : day.weekday == DateTime.saturday
                                                ? AppTheme.primary
                                                : AppTheme.textPrimary,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ]),
                );
              }).toList(),
            ),
            // Thin colored bars (no text)
            ...placed.where((p) => p.track < maxTracks).map((p) {
              final left = p.startCol * cellW + (p.clipLeft ? 0 : 1);
              final right = constraints.maxWidth -
                  (p.endCol + 1) * cellW +
                  (p.clipRight ? 0 : 1);
              final top = dateCellH + p.track * (trackH + trackGap);
              return Positioned(
                left: left,
                right: right,
                top: top,
                height: trackH,
                child: GestureDetector(
                  onTap: () => _navigateTo(EventFormScreen(event: p.event)),
                  child: p.event.isMultiDay
                      ? _buildMultiDayLine(p, trackH)
                      : Container(
                          decoration: BoxDecoration(
                            color: p.event.displayColor,
                            borderRadius: BorderRadius.horizontal(
                              left: p.clipLeft
                                  ? Radius.zero
                                  : const Radius.circular(2),
                              right: p.clipRight
                                  ? Radius.zero
                                  : const Radius.circular(2),
                            ),
                          ),
                        ),
                ),
              );
            }),
          ]),
        ),
      );
    });
  }

  // ── Week View ──────────────────────────────────────────────────────────────

  Widget _buildWeekView() {
    const weekRowH = 98.0;
    final sunStart = SettingsService().weekStartsOnSunday;
    final offset = sunStart ? _focusedDay.weekday % 7 : (_focusedDay.weekday - 1) % 7;
    final ws = _focusedDay.subtract(Duration(days: offset));
    final we = ws.add(const Duration(days: 6));
    final hasContent = _selectedEvents.isNotEmpty || _selectedDiary != null;

    return Column(children: [
      Container(
        color: AppTheme.surface,
        child: Column(children: [
          Row(children: [
            IconButton(
              icon: const Icon(Icons.chevron_left,
                  color: AppTheme.textSecondary),
              onPressed: () => _getCurrentPageController().previousPage(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut),
            ),
            Expanded(
              child: Text(
                fmtWeekRange(ws, we),
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right,
                  color: AppTheme.textSecondary),
              onPressed: () => _getCurrentPageController().nextPage(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut),
            ),
          ]),
          SizedBox(height: 28,
              child: _buildDowHeader(
                  sunStart: SettingsService().weekStartsOnSunday)),
          const Divider(height: 1),
          SizedBox(
            height: weekRowH,
            child: PageView.builder(
              controller: _getCurrentPageController(),
              itemBuilder: (_, page) {
                final weekStart = _weekStartForPage(page);
                final week = List<DateTime>.generate(
                    7, (i) => weekStart.add(Duration(days: i)));
                final placed = CalendarLayout.computeWeekLayout(week, _allEvents);
                return _buildWeekRow(week, placed, fixedRowH: weekRowH);
              },
              onPageChanged: (page) {
                final ws = _weekStartForPage(page);
                setState(() {
                  _focusedDay = ws;
                  _selectedDay = ws;
                  _selectedEvents = _eventsForDay(ws);
                  _selectedDiary = _diaryByDate[dayKey(ws)];
                });
              },
            ),
          ),
        ]),
      ),
      const Divider(height: 1),
      _buildSelectedBar(),
      Expanded(child: _buildBottomPanel(hasContent)),
    ]);
  }

  // ── Shared calendar helpers ────────────────────────────────────────────────

  List<List<DateTime>> _buildWeeks(int year, int month) {
    final first = DateTime(year, month, 1);
    final daysInMonth = DateTime(year, month + 1, 0).day;
    // Sun-start: weekday%7 → Sun=0, Mon=1 … Sat=6
    // Mon-start: (weekday-1)%7 → Mon=0, Tue=1 … Sun=6
    final offset = SettingsService().weekStartsOnSunday
        ? first.weekday % 7
        : (first.weekday - 1) % 7;

    final all = <DateTime>[];
    for (int i = offset; i > 0; i--) {
      all.add(first.subtract(Duration(days: i)));
    }
    for (int i = 1; i <= daysInMonth; i++) {
      all.add(DateTime(year, month, i));
    }
    int trailing = 1;
    while (all.length % 7 != 0) {
      all.add(DateTime(year, month, daysInMonth + trailing++));
    }
    return [for (int i = 0; i < all.length; i += 7) all.sublist(i, i + 7)];
  }

  Widget _buildDowHeader({bool sunStart = true}) {
    final labels = sunStart
        ? ['일', '월', '화', '수', '목', '금', '토']
        : ['월', '화', '수', '목', '금', '토', '일'];
    final sunLabel = sunStart ? labels.first : labels.last;
    return Row(
      children: labels.map((label) {
        final isSun = label == sunLabel;
        final isSat = label == '토';
        return Expanded(
          child: Center(
            child: Text(label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isSun
                      ? Colors.red.shade400
                      : isSat
                          ? AppTheme.primary
                          : AppTheme.textSecondary,
                )),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildWeekRow(List<DateTime> week, List<PlacedEvent> placed,
      {double? fixedRowH, int? focusedMonth, int? rowIndex, List<List<DateTime>>? allWeeks}) {
    const trackH = 18.0;
    const trackGap = 2.0;
    const maxTracks = 3;
    const bottomPad = 4.0;

    final maxTrack =
        placed.isEmpty ? -1 : placed.map((p) => p.track).reduce(max);
    final visibleTracks = min(maxTrack + 1, maxTracks);

    final double dateCellH;
    final double rowH;
    if (fixedRowH != null) {
      rowH = fixedRowH;
      dateCellH = (rowH - visibleTracks * (trackH + trackGap) - bottomPad)
          .clamp(28.0, double.infinity);
    } else {
      dateCellH = 34.0;
      rowH = dateCellH + visibleTracks * (trackH + trackGap) + bottomPad;
    }
    final today = DateTime.now();

    return LayoutBuilder(builder: (ctx, constraints) {
      final cellW = constraints.maxWidth / 7;
      return _wrapWithCalendarGestures(
        week: week,
        cellW: cellW,
        focusedMonth: focusedMonth,
        rowIndex: rowIndex,
        allWeeks: allWeeks,
        crossRowH: rowH,
        child: SizedBox(
          height: rowH,
          child: Stack(clipBehavior: Clip.none, children: [
            // Date cells
            Row(
              children: week.map((day) {
                final isOutOfMonth =
                    focusedMonth != null && day.month != focusedMonth;
                final isSel = isSameDay(day, _selectedDay);
                final isToday = isSameDay(day, today);
                final hasDiary = _diaryByDate.containsKey(dayKey(day));
                final isInDrag = _isInDragRange(day);
                return Expanded(
                  child: Stack(children: [
                    Container(
                      height: dateCellH,
                      color: (isInDrag || isSel) ? AppTheme.primaryLight : null,
                      child: Center(
                        child: Container(
                          width: 26,
                          height: 26,
                          decoration: isToday
                              ? BoxDecoration(
                                  color: AppTheme.primary,
                                  shape: BoxShape.circle,
                                  border: hasDiary
                                      ? Border.all(
                                          color: AppTheme.diaryAccent,
                                          width: 1.5)
                                      : null,
                                )
                              : hasDiary
                                  ? BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                          color: AppTheme.diaryAccent,
                                          width: 1.5),
                                    )
                                  : null,
                          child: Center(
                            child: Text(
                              '${day.day}',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: (isToday || isSel || isInDrag)
                                    ? FontWeight.w700
                                    : FontWeight.w400,
                                color: isToday
                                    ? Colors.white
                                    : isOutOfMonth
                                        ? AppTheme.textLight
                                        : day.weekday == DateTime.sunday
                                            ? Colors.red.shade500
                                            : day.weekday == DateTime.saturday
                                                ? AppTheme.primary
                                                : AppTheme.textPrimary,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ]),
                );
              }).toList(),
            ),

            // Spanning event bars
            ...placed.where((p) => p.track < maxTracks).map((p) {
              final left = p.startCol * cellW + (p.clipLeft ? 0 : 2);
              final right = constraints.maxWidth -
                  (p.endCol + 1) * cellW +
                  (p.clipRight ? 0 : 2);
              final top = dateCellH + p.track * (trackH + trackGap);
              return Positioned(
                left: left,
                right: right,
                top: top,
                height: trackH,
                child: GestureDetector(
                  onTap: () => _navigateTo(EventFormScreen(event: p.event)),
                  behavior: HitTestBehavior.opaque,
                  child: _buildEventBar(p),
                ),
              );
            }),

            // "+N more" — tapping switches to day view for that date
            ...List.generate(7, (col) {
              final day = week[col];
              if (focusedMonth != null && day.month != focusedMonth) {
                return const SizedBox.shrink();
              }
              final overflow = placed
                  .where((p) =>
                      p.track >= maxTracks &&
                      p.startCol <= col &&
                      p.endCol >= col)
                  .length;
              if (overflow == 0) return const SizedBox.shrink();
              return Positioned(
                left: col * cellW,
                width: cellW,
                top: dateCellH + maxTracks * (trackH + trackGap),
                height: trackH + 4,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    _onDaySelected(day, day);
                    _setViewMode(_ViewMode.day);
                  },
                  child: Center(
                    child: Text('+$overflow',
                        style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.primary)),
                  ),
                ),
              );
            }),
          ]),
        ),
      );
    });
  }

  Widget _buildSelectedBar() {
    return Container(
      color: AppTheme.background,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Text(fmtShortKoreanDate(_selectedDay),
          style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary)),
    );
  }

  Widget _buildEventBar(PlacedEvent p) {
    if (p.event.isMultiDay) return _buildMultiDayLine(p, 18.0, showText: true);
    final isTimed = !p.event.isAllDay;
    final radius = BorderRadius.horizontal(
      left: p.clipLeft ? Radius.zero : const Radius.circular(4),
      right: p.clipRight ? Radius.zero : const Radius.circular(4),
    );
    if (isTimed) {
      return Container(
        decoration: BoxDecoration(
          color: p.event.displayColor.withValues(alpha: 0.12),
          borderRadius: radius,
          border: Border(
            left: p.clipLeft
                ? BorderSide.none
                : BorderSide(color: p.event.displayColor, width: 2.5),
          ),
        ),
        padding: const EdgeInsets.only(left: 6, right: 4),
        child: Text(
          p.event.title,
          style: TextStyle(
              fontSize: 10,
              color: p.event.displayColor,
              fontWeight: FontWeight.w700),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
      );
    }
    return Container(
      decoration: BoxDecoration(
        color: p.event.displayColor,
        borderRadius: radius,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        p.event.title,
        style: const TextStyle(
            fontSize: 10, color: Colors.white, fontWeight: FontWeight.w600),
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
      ),
    );
  }

  Widget _buildMultiDayLine(PlacedEvent p, double trackH,
      {bool showText = false}) {
    const lineH = 2.5;
    final color = p.event.displayColor;
    return Stack(children: [
      Positioned(
        left: p.clipLeft ? 0.0 : trackH / 2,
        right: p.clipRight ? 0.0 : trackH / 2,
        top: (trackH - lineH) / 2,
        height: lineH,
        child: ColoredBox(color: color),
      ),
      if (!p.clipLeft)
        Positioned(
          left: 0, top: 0, width: trackH, height: trackH,
          child: DecoratedBox(
              decoration:
                  BoxDecoration(color: color, shape: BoxShape.circle)),
        ),
      if (!p.clipRight)
        Positioned(
          right: 0, top: 0, width: trackH, height: trackH,
          child: DecoratedBox(
              decoration:
                  BoxDecoration(color: color, shape: BoxShape.circle)),
        ),
      if (showText)
        Positioned.fill(
          left: p.clipLeft ? 4.0 : trackH + 2.0,
          right: p.clipRight ? 4.0 : trackH + 2.0,
          child: Center(
            child: Container(
              color: AppTheme.background,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                p.event.title,
                style: TextStyle(
                    fontSize: 10, color: color, fontWeight: FontWeight.w700),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ),
        ),
    ]);
  }

  // ── Year View ──────────────────────────────────────────────────────────────

  Widget _buildYearView() {
    return Column(children: [
      Container(
        color: AppTheme.surface,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left,
                  color: AppTheme.textSecondary),
              onPressed: () => _getCurrentPageController().previousPage(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut),
            ),
            Text('${_focusedDay.year}년',
                style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary)),
            IconButton(
              icon: const Icon(Icons.chevron_right,
                  color: AppTheme.textSecondary),
              onPressed: () => _getCurrentPageController().nextPage(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut),
            ),
          ],
        ),
      ),
      const Divider(height: 1),
      Expanded(
        child: PageView.builder(
          controller: _getCurrentPageController(),
          itemBuilder: (_, page) {
            final year = _monthOrigin.year + (page - _kPageMid);
            return GridView.builder(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
              gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 0.78,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemCount: 12,
              itemBuilder: (ctx, index) {
                final month = index + 1;
                return _MiniMonth(
                  year: year,
                  month: month,
                  isCurrentMonth: DateTime.now().year == year &&
                      DateTime.now().month == month,
                  sunStart: SettingsService().weekStartsOnSunday,
                  onTap: () {
                    final d = DateTime(year, month, 1);
                    _onDaySelected(d, d);
                    _setViewMode(_ViewMode.month);
                  },
                );
              },
            );
          },
          onPageChanged: (page) {
            final year = _monthOrigin.year + (page - _kPageMid);
            setState(() {
              _focusedDay = DateTime(year, _focusedDay.month);
            });
          },
        ),
      ),
    ]);
  }

  // ── Bottom panel ───────────────────────────────────────────────────────────

  Widget _buildBottomPanel(bool hasContent) {
    if (!hasContent) return const _EmptyDayState();
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 80),
      children: [
        ..._selectedEvents.map((e) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _EventCard(
                event: e,
                onTap: () => _navigateTo(EventFormScreen(event: e)),
              ),
            )),
        if (_selectedDiary != null)
          _DiaryPreviewCard(
            diary: _selectedDiary!,
            onTap: () => _navigateTo(DiaryFormScreen(date: _selectedDay)),
          ),
      ],
    );
  }
}

// ── Mini Month (year view) ────────────────────────────────────────────────────

class _MiniMonth extends StatelessWidget {
  final int year, month;
  final bool isCurrentMonth;
  final bool sunStart;
  final VoidCallback onTap;

  const _MiniMonth({
    required this.year,
    required this.month,
    required this.isCurrentMonth,
    required this.sunStart,
    required this.onTap,
  });

  static const _monthNames = [
    '1월', '2월', '3월', '4월', '5월', '6월',
    '7월', '8월', '9월', '10월', '11월', '12월',
  ];

  @override
  Widget build(BuildContext context) {
    final firstDay = DateTime(year, month, 1);
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final startOffset =
        sunStart ? firstDay.weekday % 7 : (firstDay.weekday - 1) % 7;
    final dowLabels = sunStart
        ? const ['일', '월', '화', '수', '목', '금', '토']
        : const ['월', '화', '수', '목', '금', '토', '일'];
    final today = DateTime.now();

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: isCurrentMonth
              ? Border.all(color: AppTheme.primary, width: 1.5)
              : Border.all(color: AppTheme.divider),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primary.withValues(alpha: 0.05),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(6, 8, 6, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 2, bottom: 4),
              child: Text(
                _monthNames[month - 1],
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isCurrentMonth
                      ? AppTheme.primary
                      : AppTheme.textPrimary,
                ),
              ),
            ),
            Row(
              children: dowLabels
                  .map((d) => Expanded(
                        child: Text(d,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                fontSize: 7, color: AppTheme.textLight)),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 2),
            Expanded(
              child: GridView.count(
                crossAxisCount: 7,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  ...List.generate(startOffset, (_) => const SizedBox.shrink()),
                  ...List.generate(daysInMonth, (i) {
                    final day = i + 1;
                    final date = DateTime(year, month, day);
                    final isToday = date.year == today.year &&
                        date.month == today.month &&
                        date.day == today.day;
                    return Container(
                      width: 14,
                      height: 14,
                      decoration: isToday
                          ? const BoxDecoration(
                              color: AppTheme.primary,
                              shape: BoxShape.circle)
                          : null,
                      child: Center(
                        child: Text('$day',
                            style: TextStyle(
                              fontSize: 7,
                              color: isToday
                                  ? Colors.white
                                  : AppTheme.textPrimary,
                              fontWeight: isToday
                                  ? FontWeight.w700
                                  : FontWeight.w400,
                            )),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Empty State ───────────────────────────────────────────────────────────────

class _EmptyDayState extends StatelessWidget {
  const _EmptyDayState();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (_, constraints) {
      if (constraints.maxHeight < 100) return const SizedBox.shrink();
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(
                color: AppTheme.primaryLight, shape: BoxShape.circle),
            child: const Icon(Icons.event_note_rounded,
                color: AppTheme.primary, size: 28),
          ),
          const SizedBox(height: 12),
          const Text('이날의 기록이 없어요',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textSecondary)),
        ]),
      );
    });
  }
}

// ── Mode Selection Sheet ──────────────────────────────────────────────────────

class _ModeSelectionSheet extends StatelessWidget {
  final DateTime day;
  const _ModeSelectionSheet({required this.day});

  String _fmtDate(DateTime d) =>
      '${d.month}월 ${d.day}일 (${koreanWeekday(d)})';

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                    color: AppTheme.divider,
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(_fmtDate(day),
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary)),
            ),
            const SizedBox(height: 4),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('무엇을 추가할까요?',
                  style: TextStyle(
                      fontSize: 13, color: AppTheme.textSecondary)),
            ),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(
                child: _ModeCard(
                  icon: Icons.calendar_month_rounded,
                  label: '일정',
                  description: '날짜·시간 기반 일정',
                  borderColor: AppTheme.primary,
                  iconBgColor: AppTheme.primaryLight,
                  iconColor: AppTheme.primary,
                  onTap: () => Navigator.of(context).pop('event'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ModeCard(
                  icon: Icons.auto_stories_rounded,
                  label: '일기',
                  description: '하루를 기록해요',
                  borderColor: AppTheme.diaryAccent,
                  iconBgColor: AppTheme.diaryAccentBg,
                  iconColor: const Color(0xFFB8860B),
                  onTap: () => Navigator.of(context).pop('diary'),
                ),
              ),
            ]),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String description;
  final Color borderColor;
  final Color iconBgColor;
  final Color iconColor;
  final VoidCallback onTap;

  const _ModeCard({
    required this.icon,
    required this.label,
    required this.description,
    required this.borderColor,
    required this.iconBgColor,
    required this.iconColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, width: 1.8),
          boxShadow: [
            BoxShadow(
              color: borderColor.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                  color: iconBgColor,
                  borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(height: 12),
            Text(label,
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary)),
            const SizedBox(height: 2),
            Text(description,
                style: const TextStyle(
                    fontSize: 12, color: AppTheme.textSecondary)),
          ],
        ),
      ),
    );
  }
}

// ── Event Card ────────────────────────────────────────────────────────────────

class _EventCard extends StatelessWidget {
  final Event event;
  final VoidCallback onTap;
  const _EventCard({required this.event, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: event.displayColor.withValues(alpha: 0.12),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: IntrinsicHeight(
          child: Row(children: [
            Container(
              width: 4,
              decoration: BoxDecoration(
                color: event.displayColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(14),
                  bottomLeft: Radius.circular(14),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(
                        child: Text(event.title,
                            style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.textPrimary)),
                      ),
                      if (event.isRecurring)
                        Container(
                          margin: const EdgeInsets.only(left: 6),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: event.displayColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(event.recurrenceLabel,
                              style: TextStyle(
                                  fontSize: 10,
                                  color: event.displayColor,
                                  fontWeight: FontWeight.w600)),
                        ),
                    ]),
                    const SizedBox(height: 3),
                    Row(children: [
                      const Icon(Icons.access_time_rounded,
                          size: 12, color: AppTheme.textLight),
                      const SizedBox(width: 3),
                      Text(event.timeDisplay,
                          style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondary)),
                      if (event.isMultiDay) ...[
                        const SizedBox(width: 8),
                        const Icon(Icons.date_range_rounded,
                            size: 12, color: AppTheme.textLight),
                        const SizedBox(width: 3),
                        Text(
                          '${event.startDate.month}/${event.startDate.day}'
                          ' ~ ${event.endDate.month}/${event.endDate.day}',
                          style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondary),
                        ),
                      ],
                    ]),
                  ],
                ),
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                size: 18, color: AppTheme.textLight),
            const SizedBox(width: 10),
          ]),
        ),
      ),
    );
  }
}

// ── Diary Preview Card ────────────────────────────────────────────────────────

class _DiaryPreviewCard extends StatelessWidget {
  final Diary diary;
  final VoidCallback onTap;
  const _DiaryPreviewCard({required this.diary, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: AppTheme.diaryAccent.withValues(alpha: 0.15),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: IntrinsicHeight(
          child: Row(children: [
            Container(
              width: 4,
              decoration: const BoxDecoration(
                color: AppTheme.diaryAccent,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(14),
                  bottomLeft: Radius.circular(14),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      if (diary.mood != null) ...[
                        Text(diary.mood!,
                            style: const TextStyle(fontSize: 16)),
                        const SizedBox(width: 6),
                      ],
                      const Text('일기',
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimary)),
                    ]),
                    const SizedBox(height: 3),
                    Text(
                      diary.content,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 13,
                          color: AppTheme.textSecondary,
                          height: 1.5),
                    ),
                  ],
                ),
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                size: 18, color: AppTheme.textLight),
            const SizedBox(width: 10),
          ]),
        ),
      ),
    );
  }
}

// ── Day Page Content (per-page StatefulWidget for PageView) ───────────────────

class _DayPageContent extends StatefulWidget {
  final DateTime day;
  final List<Event> events;
  final Diary? diary;
  final void Function(Event) onEventTap;
  final VoidCallback onDiaryTap;

  const _DayPageContent({
    super.key,
    required this.day,
    required this.events,
    required this.diary,
    required this.onEventTap,
    required this.onDiaryTap,
  });

  @override
  State<_DayPageContent> createState() => _DayPageContentState();
}

class _DayPageContentState extends State<_DayPageContent> {
  late final ScrollController _scrollCtrl;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final isToday = isSameDay(widget.day, now);
    final mins = isToday ? now.hour * 60 + now.minute : 8 * 60;
    _scrollCtrl = ScrollController(
      initialScrollOffset: (mins / 60.0 * 64.0 - 80).clamp(0, double.infinity),
    );
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final banners =
        widget.events.where((e) => e.isAllDay || e.isMultiDay).toList();
    final timedEvents = widget.events
        .where((e) => !e.isAllDay && !e.isMultiDay && e.startTimeMinutes != null)
        .toList();

    return Column(children: [
      if (banners.isNotEmpty || widget.diary != null) _buildBanners(banners),
      Expanded(child: _buildTimeline(timedEvents)),
    ]);
  }

  Widget _buildBanners(List<Event> banners) {
    return Container(
      color: AppTheme.surface,
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          ...banners.map((e) => GestureDetector(
                onTap: () => widget.onEventTap(e),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 4),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: e.displayColor,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(children: [
                    const Icon(Icons.event_rounded,
                        size: 13, color: Colors.white70),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(e.title,
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.white),
                          overflow: TextOverflow.ellipsis),
                    ),
                    Text(
                        e.isAllDay
                            ? '종일'
                            : e.isMultiDay
                                ? '여러 날'
                                : '',
                        style: const TextStyle(
                            fontSize: 11, color: Colors.white70)),
                  ]),
                ),
              )),
          if (widget.diary != null)
            GestureDetector(
              onTap: widget.onDiaryTap,
              child: Container(
                margin: const EdgeInsets.only(bottom: 4),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppTheme.diaryAccentBg,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppTheme.diaryAccent),
                ),
                child: Row(children: [
                  const Text('📓', style: TextStyle(fontSize: 13)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      widget.diary!.content,
                      style: const TextStyle(
                          fontSize: 13, color: AppTheme.textPrimary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ]),
              ),
            ),
          const Divider(height: 8),
        ],
      ),
    );
  }

  Widget _buildTimeline(List<Event> timedEvents) {
    const hourH = 64.0;
    const labelW = 52.0;
    const totalH = 24 * hourH;

    final lanes = CalendarLayout.assignLanes(timedEvents);
    final numLanes = CalendarLayout.maxLane(lanes);

    final now = DateTime.now();
    final isToday = isSameDay(widget.day, now);
    final currentMins = isToday ? now.hour * 60.0 + now.minute : null;

    return SingleChildScrollView(
      controller: _scrollCtrl,
      child: SizedBox(
        height: totalH + 88,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: labelW,
              height: totalH,
              child: Stack(
                children: List.generate(
                  24,
                  (h) => Positioned(
                    top: h * hourH - 7,
                    left: 0,
                    right: 4,
                    child: Text(
                      '${h.toString().padLeft(2, '0')}:00',
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                          fontSize: 10, color: AppTheme.textLight),
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: LayoutBuilder(builder: (ctx, constraints) {
                final availW = constraints.maxWidth;
                final laneW = availW / numLanes;

                return SizedBox(
                  height: totalH,
                  child: Stack(children: [
                    ...List.generate(
                        24,
                        (h) => Positioned(
                              top: h * hourH,
                              left: 0,
                              right: 0,
                              height: 0.5,
                              child: ColoredBox(color: AppTheme.divider),
                            )),
                    ...List.generate(
                        24,
                        (h) => Positioned(
                              top: h * hourH + hourH / 2,
                              left: 0,
                              right: 0,
                              height: 0.5,
                              child: ColoredBox(
                                  color: AppTheme.divider
                                      .withValues(alpha: 0.5)),
                            )),
                    ...lanes.map((lane) {
                      final e = lane.event;
                      final startMin = e.startTimeMinutes!.toDouble();
                      final endMin =
                          (e.endTimeMinutes ?? (e.startTimeMinutes! + 60))
                              .toDouble();
                      final top = startMin / 60 * hourH;
                      final h = ((endMin - startMin) / 60 * hourH)
                          .clamp(22.0, totalH);
                      return Positioned(
                        top: top,
                        left: lane.lane * laneW,
                        width: laneW,
                        height: h,
                        child: GestureDetector(
                          onTap: () => widget.onEventTap(e),
                          child: Container(
                            margin: const EdgeInsets.fromLTRB(2, 1, 4, 1),
                            decoration: BoxDecoration(
                              color: e.displayColor,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            padding:
                                const EdgeInsets.fromLTRB(7, 4, 4, 4),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(e.title,
                                    style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white),
                                    maxLines: h > 42 ? 2 : 1,
                                    overflow: TextOverflow.ellipsis),
                                if (h > 34)
                                  Text(e.timeDisplay,
                                      style: const TextStyle(
                                          fontSize: 10,
                                          color: Colors.white70)),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                    if (currentMins != null)
                      Positioned(
                        top: currentMins / 60 * hourH,
                        left: 0,
                        right: 0,
                        child: Row(children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                                color: Colors.red, shape: BoxShape.circle),
                          ),
                          Expanded(
                              child: Container(
                                  height: 1.5, color: Colors.red)),
                        ]),
                      ),
                    if (timedEvents.isEmpty)
                      const Positioned(
                        top: 180,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: Text('시간이 지정된 일정이 없어요',
                              style: TextStyle(
                                  fontSize: 13,
                                  color: AppTheme.textLight)),
                        ),
                      ),
                  ]),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}
