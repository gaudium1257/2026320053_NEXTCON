import 'dart:math';
import 'package:flutter/material.dart';
import '../models/event.dart';
import '../models/diary.dart';
import '../services/database_service.dart';
import '../theme/app_theme.dart';
import 'event_form_screen.dart';
import 'diary_form_screen.dart';

enum _ViewMode { day, week, month, year }

bool _isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

// ── Layout helpers ────────────────────────────────────────────────────────────

class _PlacedEvent {
  final Event event;
  final int track;
  final int startCol;
  final int endCol;
  final bool clipLeft;
  final bool clipRight;
  const _PlacedEvent({
    required this.event,
    required this.track,
    required this.startCol,
    required this.endCol,
    this.clipLeft = false,
    this.clipRight = false,
  });
}

class _LaneEvent {
  final Event event;
  final int lane;
  const _LaneEvent({required this.event, required this.lane});
}

// ── Screen ────────────────────────────────────────────────────────────────────

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  final _db = DatabaseService();

  _ViewMode _viewMode = _ViewMode.month;
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();

  List<Event> _allEvents = [];
  Map<String, Diary> _diaryByDate = {};
  List<Event> _selectedEvents = [];
  Diary? _selectedDiary;

  Set<String> _eventDateSet = {};
  int _eventDateSetYear = -1;

  bool _loading = true;
  late final ScrollController _timelineScrollCtrl;

  static const _wdLabels = ['월', '화', '수', '목', '금', '토', '일'];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _timelineScrollCtrl = ScrollController(
      initialScrollOffset: (now.hour * 64.0 - 80).clamp(0, double.infinity),
    );
    _loadData();
  }

  @override
  void dispose() {
    _timelineScrollCtrl.dispose();
    super.dispose();
  }

  // ── Data ───────────────────────────────────────────────────────────────────

  Future<void> _loadData() async {
    final events = await _db.getAllEvents();
    final diaries = await _db.getAllDiaries();
    if (!mounted) return;
    _setData(events, diaries);
  }

  void _setData(List<Event> events, List<Diary> diaries) {
    final diaryMap = {for (final d in diaries) d.dateKey: d};
    setState(() {
      _allEvents = events;
      _diaryByDate = diaryMap;
      _selectedEvents = _eventsForDay(_selectedDay, events);
      _selectedDiary = diaryMap[Diary.keyFrom(_selectedDay)];
      _loading = false;
    });
    if (_viewMode == _ViewMode.year) _ensureEventDateSet();
  }

  List<Event> _eventsForDay(DateTime day, List<Event> events) =>
      events.where((e) => e.occursOn(day)).toList();

  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    setState(() {
      _selectedDay = selectedDay;
      _focusedDay = focusedDay;
      _selectedEvents = _eventsForDay(selectedDay, _allEvents);
      _selectedDiary = _diaryByDate[Diary.keyFrom(selectedDay)];
    });
    if (_viewMode == _ViewMode.day && _timelineScrollCtrl.hasClients) {
      final now = DateTime.now();
      final mins = _isSameDay(selectedDay, now)
          ? now.hour * 60 + now.minute
          : 8 * 60;
      _timelineScrollCtrl.animateTo(
        (mins / 60.0 * 64.0 - 80).clamp(0, double.infinity),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _changeDay(int delta) {
    final d = _selectedDay.add(Duration(days: delta));
    _onDaySelected(d, d);
  }

  void _setViewMode(_ViewMode mode) {
    if (mode == _ViewMode.year) _ensureEventDateSet();
    setState(() => _viewMode = mode);
  }

  void _ensureEventDateSet() {
    final year = _focusedDay.year;
    if (_eventDateSetYear == year) return;
    final set = <String>{};
    for (var m = 1; m <= 12; m++) {
      final days = DateTime(year, m + 1, 0).day;
      for (var d = 1; d <= days; d++) {
        final date = DateTime(year, m, d);
        if (_allEvents.any((e) => e.occursOn(date))) {
          set.add(Diary.keyFrom(date));
        }
      }
    }
    _eventDateSet = set;
    _eventDateSetYear = year;
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

  // ── Formatting ─────────────────────────────────────────────────────────────

  String _fmtSelectedDate(DateTime d) =>
      '${d.month}월 ${d.day}일 ${_wdLabels[d.weekday - 1]}요일';

  String _fmtFullDate(DateTime d) =>
      '${d.year}년 ${d.month}월 ${d.day}일 (${_wdLabels[d.weekday - 1]})';

  String _fmtMonthYear(int y, int m) => '$y년 $m월';

  String _fmtWeekRange(DateTime s, DateTime e) {
    if (s.month == e.month) {
      return '${s.year}년 ${s.month}월 ${s.day}~${e.day}일';
    }
    return '${s.month}월 ${s.day}일 ~ ${e.month}월 ${e.day}일';
  }

  // ── Scaffold ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dayce'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(36),
          child: _buildViewModeBar(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.today_rounded, size: 22),
            tooltip: '오늘로 이동',
            onPressed: () {
              final today = DateTime.now();
              _onDaySelected(today, today);
            },
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _buildBody(),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showModeSelection(_selectedDay),
        child: const Icon(Icons.add_rounded, size: 28),
      ),
    );
  }

  Widget _buildViewModeBar() {
    const labels = {
      _ViewMode.day: '일',
      _ViewMode.week: '주',
      _ViewMode.month: '월',
      _ViewMode.year: '년',
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: _ViewMode.values.map((mode) {
          final selected = _viewMode == mode;
          return GestureDetector(
            onTap: () => _setViewMode(mode),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
              decoration: BoxDecoration(
                color: selected ? Colors.white : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                labels[mode]!,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight:
                      selected ? FontWeight.w700 : FontWeight.w400,
                  color: selected ? AppTheme.primary : Colors.white70,
                ),
              ),
            ),
          );
        }).toList(),
      ),
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
    final timed = _selectedEvents
        .where((e) => !e.isAllDay && !e.isMultiDay && e.startTimeMinutes != null)
        .toList();
    final banners = _selectedEvents
        .where((e) => e.isAllDay || e.isMultiDay || e.startTimeMinutes == null)
        .toList();

    return Column(children: [
      // Date navigation
      Container(
        color: AppTheme.surface,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Row(children: [
          IconButton(
            icon: const Icon(Icons.chevron_left, color: AppTheme.textSecondary),
            onPressed: () => _changeDay(-1),
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
                if (picked != null) _onDaySelected(picked, picked);
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
            icon: const Icon(Icons.chevron_right,
                color: AppTheme.textSecondary),
            onPressed: () => _changeDay(1),
          ),
        ]),
      ),
      const Divider(height: 1),

      // All-day / multi-day / diary banners
      if (banners.isNotEmpty || _selectedDiary != null)
        _buildDayBanners(banners),

      // Timeline
      Expanded(child: _buildTimeline(timed)),
    ]);
  }

  Widget _buildDayBanners(List<Event> banners) {
    return Container(
      color: AppTheme.surface,
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          ...banners.map((e) => GestureDetector(
                onTap: () => _navigateTo(EventFormScreen(event: e)),
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
          if (_selectedDiary != null)
            GestureDetector(
              onTap: () => _navigateTo(DiaryFormScreen(date: _selectedDay)),
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
                      _selectedDiary!.content,
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

    final lanes = _assignLanes(timedEvents);
    final numLanes = lanes.isEmpty ? 1 : lanes.map((l) => l.lane).reduce(max) + 1;

    final now = DateTime.now();
    final isToday = _isSameDay(_selectedDay, now);
    final currentMins =
        isToday ? now.hour * 60.0 + now.minute : null;

    return SingleChildScrollView(
      controller: _timelineScrollCtrl,
      child: SizedBox(
        height: totalH + 24,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hour labels
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

            // Grid + events
            Expanded(
              child: LayoutBuilder(builder: (ctx, constraints) {
                final availW = constraints.maxWidth;
                final laneW = availW / numLanes;

                return SizedBox(
                  height: totalH,
                  child: Stack(children: [
                    // Hour lines
                    ...List.generate(
                        24,
                        (h) => Positioned(
                              top: h * hourH,
                              left: 0,
                              right: 0,
                              height: 0.5,
                              child: ColoredBox(color: AppTheme.divider),
                            )),
                    // Half-hour lines
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

                    // Event blocks
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
                          onTap: () =>
                              _navigateTo(EventFormScreen(event: e)),
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

                    // Current time line
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
                                color: Colors.red,
                                shape: BoxShape.circle),
                          ),
                          Expanded(
                              child: Container(
                                  height: 1.5, color: Colors.red)),
                        ]),
                      ),

                    if (timedEvents.isEmpty)
                      Positioned(
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

  List<_LaneEvent> _assignLanes(List<Event> events) {
    if (events.isEmpty) return [];
    final sorted = [...events]
      ..sort((a, b) => a.startTimeMinutes!.compareTo(b.startTimeMinutes!));
    final laneEnds = <int>[];
    final result = <_LaneEvent>[];
    for (final e in sorted) {
      final start = e.startTimeMinutes!;
      final end = e.endTimeMinutes ?? (start + 60);
      int lane = laneEnds.indexWhere((le) => le <= start);
      if (lane == -1) {
        lane = laneEnds.length;
        laneEnds.add(end);
      } else {
        laneEnds[lane] = end;
      }
      result.add(_LaneEvent(event: e, lane: lane));
    }
    return result;
  }

  // ── Month View — Custom with Spanning Bars ─────────────────────────────────

  Widget _buildMonthView() {
    final year = _focusedDay.year;
    final month = _focusedDay.month;
    final weeks = _buildWeeks(year, month);
    final hasContent = _selectedEvents.isNotEmpty || _selectedDiary != null;

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Container(
            color: AppTheme.surface,
            child: Column(children: [
              // Month navigation
              Row(children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left,
                      color: AppTheme.textSecondary),
                  onPressed: () => setState(() => _focusedDay =
                      DateTime(_focusedDay.year, _focusedDay.month - 1, 1)),
                ),
                Expanded(
                  child: Text(
                    _fmtMonthYear(year, month),
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
                  onPressed: () => setState(() => _focusedDay =
                      DateTime(_focusedDay.year, _focusedDay.month + 1, 1)),
                ),
              ]),
              _buildDowHeader(),
              const Divider(height: 1),
              ...weeks.map((week) {
                final placed = _computeWeekLayout(week);
                return _buildWeekRow(week, placed);
              }),
            ]),
          ),
        ),
        SliverToBoxAdapter(child: const Divider(height: 1)),
        SliverToBoxAdapter(child: _buildSelectedBar()),
        if (!hasContent)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: _EmptyDayState(),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 80),
            sliver: SliverList.list(
              children: [
                ..._selectedEvents.map((e) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _EventCard(
                        event: e,
                        onTap: () =>
                            _navigateTo(EventFormScreen(event: e)),
                      ),
                    )),
                if (_selectedDiary != null)
                  _DiaryPreviewCard(
                    diary: _selectedDiary!,
                    onTap: () =>
                        _navigateTo(DiaryFormScreen(date: _selectedDay)),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  // ── Week View — 1-week custom with Spanning Bars ───────────────────────────

  Widget _buildWeekView() {
    final ws = _focusedDay.subtract(Duration(days: _focusedDay.weekday - 1));
    final week =
        List<DateTime?>.generate(7, (i) => ws.add(Duration(days: i)));
    final placed = _computeWeekLayout(week);
    final hasContent = _selectedEvents.isNotEmpty || _selectedDiary != null;

    return Column(children: [
      Container(
        color: AppTheme.surface,
        child: Column(children: [
          // Week navigation
          Row(children: [
            IconButton(
              icon: const Icon(Icons.chevron_left,
                  color: AppTheme.textSecondary),
              onPressed: () {
                final prev = _focusedDay.subtract(const Duration(days: 7));
                setState(() {
                  _focusedDay = prev;
                  _selectedDay = prev;
                  _selectedEvents =
                      _eventsForDay(_selectedDay, _allEvents);
                  _selectedDiary =
                      _diaryByDate[Diary.keyFrom(_selectedDay)];
                });
              },
            ),
            Expanded(
              child: Text(
                _fmtWeekRange(ws, ws.add(const Duration(days: 6))),
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
              onPressed: () {
                final next = _focusedDay.add(const Duration(days: 7));
                setState(() {
                  _focusedDay = next;
                  _selectedDay = next;
                  _selectedEvents =
                      _eventsForDay(_selectedDay, _allEvents);
                  _selectedDiary =
                      _diaryByDate[Diary.keyFrom(_selectedDay)];
                });
              },
            ),
          ]),
          _buildDowHeader(),
          const Divider(height: 1),
          _buildWeekRow(week, placed),
        ]),
      ),
      const Divider(height: 1),
      _buildSelectedBar(),
      Expanded(child: _buildBottomPanel(hasContent)),
    ]);
  }

  // ── Shared calendar helpers ────────────────────────────────────────────────

  List<List<DateTime?>> _buildWeeks(int year, int month) {
    final first = DateTime(year, month, 1);
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final offset = first.weekday - 1; // Mon=0

    final all = <DateTime?>[
      ...List.filled(offset, null),
      ...List.generate(daysInMonth, (i) => DateTime(year, month, i + 1)),
    ];
    while (all.length % 7 != 0) { all.add(null); }
    return [for (int i = 0; i < all.length; i += 7) all.sublist(i, i + 7)];
  }

  Widget _buildDowHeader() {
    const labels = ['월', '화', '수', '목', '금', '토', '일'];
    return Row(
      children: labels.asMap().entries.map((e) {
        final i = e.key;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Text(e.value,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: i == 5
                      ? AppTheme.primary
                      : i == 6
                          ? Colors.red.shade400
                          : AppTheme.textSecondary,
                )),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildWeekRow(List<DateTime?> week, List<_PlacedEvent> placed) {
    const dateCellH = 34.0;
    const trackH = 18.0;
    const trackGap = 2.0;
    const maxTracks = 3;
    const bottomPad = 4.0;

    final maxTrack =
        placed.isEmpty ? -1 : placed.map((p) => p.track).reduce(max);
    final visibleTracks = min(maxTrack + 1, maxTracks);
    final rowH =
        dateCellH + visibleTracks * (trackH + trackGap) + bottomPad;
    final today = DateTime.now();

    return LayoutBuilder(builder: (ctx, constraints) {
      final cellW = constraints.maxWidth / 7;
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapUp: (details) {
          final col =
              (details.localPosition.dx / cellW).floor().clamp(0, 6);
          final day = week[col];
          if (day != null) _onDaySelected(day, day);
        },
        child: SizedBox(
          height: rowH,
          child: Stack(clipBehavior: Clip.none, children: [
            // Date cells
            Row(
              children: week.asMap().entries.map((entry) {
                final i = entry.key;
                final day = entry.value;
                if (day == null) {
                  return Expanded(
                      child: SizedBox(height: dateCellH));
                }
                final isSel = _isSameDay(day, _selectedDay);
                final isToday = _isSameDay(day, today);
                return Expanded(
                  child: Container(
                    height: dateCellH,
                    color: isSel ? AppTheme.primaryLight : null,
                    child: Center(
                      child: Container(
                        width: 26,
                        height: 26,
                        decoration: isToday
                            ? const BoxDecoration(
                                color: AppTheme.primary,
                                shape: BoxShape.circle)
                            : null,
                        child: Center(
                          child: Text(
                            '${day.day}',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: (isToday || isSel)
                                  ? FontWeight.w700
                                  : FontWeight.w400,
                              color: isToday
                                  ? Colors.white
                                  : i == 5
                                      ? AppTheme.primary
                                      : i == 6
                                          ? Colors.red.shade500
                                          : AppTheme.textPrimary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),

            // Spanning event bars
            ...placed.where((p) => p.track < maxTracks).map((p) {
              final left =
                  p.startCol * cellW + (p.clipLeft ? 0 : 2);
              final right = constraints.maxWidth -
                  (p.endCol + 1) * cellW +
                  (p.clipRight ? 0 : 2);
              final top =
                  dateCellH + p.track * (trackH + trackGap);
              return Positioned(
                left: left,
                right: right,
                top: top,
                height: trackH,
                child: GestureDetector(
                  onTap: () =>
                      _navigateTo(EventFormScreen(event: p.event)),
                  child: _buildEventBar(p),
                ),
              );
            }),

            // "+N more" overflow
            ...List.generate(7, (col) {
              final day = week[col];
              if (day == null) return const SizedBox.shrink();
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
                height: trackH,
                child: Center(
                  child: Text('+$overflow',
                      style: const TextStyle(
                          fontSize: 9,
                          color: AppTheme.textSecondary)),
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
      color: AppTheme.surface,
      padding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(children: [
        Text(_fmtSelectedDate(_selectedDay),
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary)),
        const Spacer(),
        if (_selectedEvents.isNotEmpty)
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: AppTheme.primaryLight,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text('일정 ${_selectedEvents.length}',
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primary)),
          ),
      ]),
    );
  }

  Widget _buildEventBar(_PlacedEvent p) {
    final isTimed = !p.event.isAllDay && !p.event.isMultiDay;
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

  // ── Week layout algorithm ──────────────────────────────────────────────────

  static DateTime _d(DateTime dt) =>
      DateTime(dt.year, dt.month, dt.day);

  List<_PlacedEvent> _computeWeekLayout(List<DateTime?> week) {
    final realDays = week.whereType<DateTime>().toList();
    if (realDays.isEmpty) return [];
    final ws = _d(realDays.first);
    final we = _d(realDays.last);

    final candidates = <Event>[];
    for (final event in _allEvents) {
      if (event.isRecurring) {
        if (realDays.any((d) => event.occursOn(d))) candidates.add(event);
      } else {
        final s = _d(event.startDate);
        final e = _d(event.endDate);
        if (!e.isBefore(ws) && !s.isAfter(we)) candidates.add(event);
      }
    }

    // Sort: longer non-recurring first
    candidates.sort((a, b) {
      if (a.isRecurring != b.isRecurring) return a.isRecurring ? 1 : -1;
      final da = _d(a.endDate).difference(_d(a.startDate)).inDays;
      final db = _d(b.endDate).difference(_d(b.startDate)).inDays;
      if (da != db) return db.compareTo(da);
      return _d(a.startDate).compareTo(_d(b.startDate));
    });

    final placed = <_PlacedEvent>[];
    // track → occupied [startCol, endCol] ranges
    final trackRanges = <int, List<List<int>>>{};

    for (final event in candidates) {
      if (event.isRecurring) {
        for (int col = 0; col < 7; col++) {
          final day = week[col];
          if (day == null || !event.occursOn(day)) continue;
          final track = _findTrack(trackRanges, col, col);
          trackRanges.putIfAbsent(track, () => []).add([col, col]);
          placed.add(_PlacedEvent(
              event: event, track: track, startCol: col, endCol: col));
        }
      } else {
        final s = _d(event.startDate);
        final e = _d(event.endDate);
        final clipLeft = s.isBefore(ws);
        final clipRight = e.isAfter(we);
        final sc =
            (clipLeft ? 0 : s.difference(ws).inDays).clamp(0, 6);
        final ec =
            (clipRight ? 6 : e.difference(ws).inDays).clamp(0, 6);
        final track = _findTrack(trackRanges, sc, ec);
        trackRanges.putIfAbsent(track, () => []).add([sc, ec]);
        placed.add(_PlacedEvent(
          event: event,
          track: track,
          startCol: sc,
          endCol: ec,
          clipLeft: clipLeft,
          clipRight: clipRight,
        ));
      }
    }
    return placed;
  }

  int _findTrack(Map<int, List<List<int>>> ranges, int sc, int ec) {
    int track = 0;
    while (true) {
      final list = ranges[track] ?? [];
      if (!list.any((r) => sc <= r[1] && ec >= r[0])) {
        return track;
      }
      track++;
    }
  }

  // ── Year View ──────────────────────────────────────────────────────────────

  Widget _buildYearView() {
    final year = _focusedDay.year;
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
              onPressed: () {
                setState(() {
                  _focusedDay = DateTime(
                      _focusedDay.year - 1, _focusedDay.month);
                  _eventDateSetYear = -1;
                });
                _ensureEventDateSet();
              },
            ),
            Text('$year년',
                style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary)),
            IconButton(
              icon: const Icon(Icons.chevron_right,
                  color: AppTheme.textSecondary),
              onPressed: () {
                setState(() {
                  _focusedDay = DateTime(
                      _focusedDay.year + 1, _focusedDay.month);
                  _eventDateSetYear = -1;
                });
                _ensureEventDateSet();
              },
            ),
          ],
        ),
      ),
      const Divider(height: 1),
      Expanded(
        child: GridView.builder(
          padding: const EdgeInsets.all(12),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
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
              eventDateSet: _eventDateSet,
              diaryByDate: _diaryByDate,
              isCurrentMonth: DateTime.now().year == year &&
                  DateTime.now().month == month,
              onTap: () {
                final d = DateTime(year, month, 1);
                _onDaySelected(d, d);
                _setViewMode(_ViewMode.month);
              },
            );
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
  final Set<String> eventDateSet;
  final Map<String, Diary> diaryByDate;
  final bool isCurrentMonth;
  final VoidCallback onTap;

  const _MiniMonth({
    required this.year,
    required this.month,
    required this.eventDateSet,
    required this.diaryByDate,
    required this.isCurrentMonth,
    required this.onTap,
  });

  static const _monthNames = [
    '1월', '2월', '3월', '4월', '5월', '6월',
    '7월', '8월', '9월', '10월', '11월', '12월',
  ];
  static const _dowLabels = ['월', '화', '수', '목', '금', '토', '일'];

  @override
  Widget build(BuildContext context) {
    final firstDay = DateTime(year, month, 1);
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final startOffset = firstDay.weekday - 1;
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
              children: _dowLabels
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
                    final dk = Diary.keyFrom(date);
                    final hasEvent = eventDateSet.contains(dk);
                    final hasDiary = diaryByDate.containsKey(dk);
                    final isToday = date.year == today.year &&
                        date.month == today.month &&
                        date.day == today.day;
                    return Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
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
                        ),
                        if (hasEvent || hasDiary)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (hasEvent)
                                Container(
                                  width: 3,
                                  height: 3,
                                  margin: const EdgeInsets.only(right: 1),
                                  decoration: const BoxDecoration(
                                      color: AppTheme.primary,
                                      shape: BoxShape.circle),
                                ),
                              if (hasDiary)
                                Container(
                                  width: 3,
                                  height: 3,
                                  decoration: const BoxDecoration(
                                      color: AppTheme.diaryAccent,
                                      shape: BoxShape.circle),
                                ),
                            ],
                          ),
                      ],
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
  }
}

// ── Mode Selection Sheet ──────────────────────────────────────────────────────

class _ModeSelectionSheet extends StatelessWidget {
  final DateTime day;
  const _ModeSelectionSheet({required this.day});

  String _fmtDate(DateTime d) {
    const wd = ['월', '화', '수', '목', '금', '토', '일'];
    return '${d.month}월 ${d.day}일 (${wd[d.weekday - 1]})';
  }

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
