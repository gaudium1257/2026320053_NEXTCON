import 'dart:math';
import '../models/event.dart';

/// A single event placed onto a 7-column weekly grid row.
class PlacedEvent {
  final Event event;
  final int track;
  final int startCol;
  final int endCol;
  final bool clipLeft;
  final bool clipRight;

  const PlacedEvent({
    required this.event,
    required this.track,
    required this.startCol,
    required this.endCol,
    this.clipLeft = false,
    this.clipRight = false,
  });
}

/// An event assigned to a horizontal lane in the day-timeline view.
class LaneEvent {
  final Event event;
  final int lane;
  const LaneEvent({required this.event, required this.lane});
}

class CalendarLayout {
  CalendarLayout._();

  static DateTime _d(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

  /// Places [allEvents] onto a 7-column weekly grid defined by [week].
  static List<PlacedEvent> computeWeekLayout(
      List<DateTime> week, List<Event> allEvents) {
    if (week.isEmpty) return [];
    final ws = _d(week.first);
    final we = _d(week.last);

    final candidates = <Event>[];
    for (final event in allEvents) {
      if (event.isRecurring) {
        if (week.any((d) => event.occursOn(d))) candidates.add(event);
      } else {
        final s = _d(event.startDate);
        final e = _d(event.endDate);
        if (!e.isBefore(ws) && !s.isAfter(we)) candidates.add(event);
      }
    }

    candidates.sort((a, b) {
      if (a.isRecurring != b.isRecurring) return a.isRecurring ? 1 : -1;
      final da = _d(a.endDate).difference(_d(a.startDate)).inDays;
      final db = _d(b.endDate).difference(_d(b.startDate)).inDays;
      if (da != db) return db.compareTo(da);
      return _d(a.startDate).compareTo(_d(b.startDate));
    });

    final placed = <PlacedEvent>[];
    final trackRanges = <int, List<List<int>>>{};

    for (final event in candidates) {
      if (event.isRecurring) {
        for (int col = 0; col < 7; col++) {
          final day = week[col];
          if (!event.occursOn(day)) continue;
          final track = _findTrack(trackRanges, col, col);
          trackRanges.putIfAbsent(track, () => []).add([col, col]);
          placed.add(PlacedEvent(
              event: event, track: track, startCol: col, endCol: col));
        }
      } else {
        final s = _d(event.startDate);
        final e = _d(event.endDate);
        final clipLeft = s.isBefore(ws);
        final clipRight = e.isAfter(we);
        final sc = (clipLeft ? 0 : s.difference(ws).inDays).clamp(0, 6);
        final ec = (clipRight ? 6 : e.difference(ws).inDays).clamp(0, 6);
        final track = _findTrack(trackRanges, sc, ec);
        trackRanges.putIfAbsent(track, () => []).add([sc, ec]);
        placed.add(PlacedEvent(
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

  static int _findTrack(Map<int, List<List<int>>> ranges, int sc, int ec) {
    int track = 0;
    while (true) {
      final list = ranges[track] ?? [];
      if (!list.any((r) => sc <= r[1] && ec >= r[0])) return track;
      track++;
    }
  }

  /// Assigns non-overlapping horizontal lanes to timed [events] sorted by start time.
  /// Events with null [startTimeMinutes] are silently skipped.
  static List<LaneEvent> assignLanes(List<Event> events) {
    if (events.isEmpty) return [];
    final sorted = [...events.where((e) => e.startTimeMinutes != null)]
      ..sort((a, b) => a.startTimeMinutes!.compareTo(b.startTimeMinutes!));
    final laneEnds = <int>[];
    final result = <LaneEvent>[];
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
      result.add(LaneEvent(event: e, lane: lane));
    }
    return result;
  }

  static int maxLane(List<LaneEvent> lanes) =>
      lanes.isEmpty ? 0 : lanes.map((l) => l.lane).reduce(max) + 1;
}
