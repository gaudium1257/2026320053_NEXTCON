/// 'yyyy-MM-dd' key used as DB primary key and map index.
String dayKey(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

bool isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// Korean short weekday name from [DateTime.weekday] (Mon=1 … Sun=7).
/// Returns '월'~'일'.
String koreanWeekday(DateTime d) {
  const labels = ['월', '화', '수', '목', '금', '토', '일'];
  return labels[d.weekday - 1];
}

String fmtMonthYear(int year, int month) => '$year년 $month월';

String fmtWeekRange(DateTime s, DateTime e) => s.month == e.month
    ? '${s.month}월 ${s.day}~${e.day}일'
    : '${s.month}월 ${s.day}일 ~ ${e.month}월 ${e.day}일';

/// '2026년 5월 15일 금요일' — full Korean date with year and weekday suffix.
String fmtFullKoreanDate(DateTime d) =>
    '${d.year}년 ${d.month}월 ${d.day}일 ${koreanWeekday(d)}요일';

/// '5월 15일 금요일' — short Korean date without year, with weekday suffix.
String fmtShortKoreanDate(DateTime d) =>
    '${d.month}월 ${d.day}일 ${koreanWeekday(d)}요일';

/// 'yyyy.MM.dd' — zero-padded numeric date.
String fmtNumericDate(DateTime d) =>
    '${d.year}.${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')}';
