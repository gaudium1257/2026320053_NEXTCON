import 'package:flutter/material.dart';
import '../models/diary.dart';
import '../services/database_service.dart';
import '../theme/app_theme.dart';
import 'diary_form_screen.dart';

class DiaryListScreen extends StatefulWidget {
  const DiaryListScreen({super.key});

  @override
  State<DiaryListScreen> createState() => DiaryListScreenState();
}

class DiaryListScreenState extends State<DiaryListScreen> {
  final _db = DatabaseService();

  List<Diary> _diaries = [];
  List<String> _months = [];             // 캐시: 월별 키 목록
  List<Diary> _filtered = [];           // 캐시: 필터 결과
  Map<String, List<Diary>> _grouped = {}; // 캐시: 월별 그룹

  bool _loading = true;
  bool _hasMultipleYears = false;
  String? _selectedMonth;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void refresh() => _loadData();

  Future<void> _loadData() async {
    final diaries = await _db.getAllDiaries();
    if (!mounted) return;
    _applyData(diaries);
  }

  void _applyData(List<Diary> diaries) {
    final months = _extractMonths(diaries);
    final month =
        (months.contains(_selectedMonth)) ? _selectedMonth : null;
    final hasMultipleYears =
        months.map((m) => m.split('-')[0]).toSet().length > 1;
    setState(() {
      _diaries = diaries;
      _months = months;
      _hasMultipleYears = hasMultipleYears;
      _selectedMonth = month;
      _filtered = _filter(diaries, month);
      _grouped = _group(_filtered);
      _loading = false;
    });
  }

  void _selectMonth(String? month) {
    setState(() {
      _selectedMonth = month;
      _filtered = _filter(_diaries, month);
      _grouped = _group(_filtered);
    });
  }

  static List<String> _extractMonths(List<Diary> diaries) {
    final keys = <String>{};
    for (final d in diaries) {
      final parts = d.dateKey.split('-');
      if (parts.length >= 2) keys.add('${parts[0]}-${parts[1]}');
    }
    return keys.toList()..sort((a, b) => b.compareTo(a));
  }

  static List<Diary> _filter(List<Diary> diaries, String? month) {
    if (month == null) return diaries;
    return diaries.where((d) => d.dateKey.startsWith(month)).toList();
  }

  static Map<String, List<Diary>> _group(List<Diary> diaries) {
    final map = <String, List<Diary>>{};
    for (final d in diaries) {
      final parts = d.dateKey.split('-');
      if (parts.length < 2) continue;
      final key = '${parts[0]}년 ${int.parse(parts[1])}월';
      map.putIfAbsent(key, () => []).add(d);
    }
    return map;
  }

  String _fmtDateLabel(String dateKey) {
    final parts = dateKey.split('-');
    if (parts.length != 3) return dateKey;
    final dt = DateTime(
        int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
    const wd = ['월', '화', '수', '목', '금', '토', '일'];
    return '${dt.month}월 ${dt.day}일 ${wd[dt.weekday - 1]}요일';
  }

  String _fmtChipLabel(String monthKey) {
    final parts = monthKey.split('-');
    if (parts.length < 2) return monthKey;
    if (_hasMultipleYears) return '${parts[0]}년 ${int.parse(parts[1])}월';
    return '${int.parse(parts[1])}월';
  }

  Future<void> _openDiary(Diary d) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
          builder: (_) =>
              DiaryFormScreen(date: Diary.dateFromKey(d.dateKey))),
    );
    if (changed == true) _loadData();
  }

  @override
  Widget build(BuildContext context) {
    final groupKeys = _grouped.keys.toList();

    return Scaffold(
      appBar: AppBar(title: const Text('일기')),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'diary_fab',
        onPressed: () async {
          final changed = await Navigator.push<bool>(
            context,
            MaterialPageRoute(
              builder: (_) => DiaryFormScreen(date: DateTime.now()),
            ),
          );
          if (changed == true) _loadData();
        },
        icon: const Icon(Icons.edit_rounded),
        label: const Text('오늘 일기'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // ── Month filter chips ─────────────────────────────────────
                if (_diaries.isNotEmpty)
                  Container(
                    color: AppTheme.surface,
                    padding:
                        const EdgeInsets.fromLTRB(12, 10, 12, 10),
                    child: SizedBox(
                      height: 36,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          _MonthChip(
                            label: '전체',
                            selected: _selectedMonth == null,
                            onTap: () => _selectMonth(null),
                          ),
                          ..._months.map((m) => _MonthChip(
                                label: _fmtChipLabel(m),
                                selected: _selectedMonth == m,
                                onTap: () => _selectMonth(m),
                              )),
                        ],
                      ),
                    ),
                  ),

                // ── Diary list ─────────────────────────────────────────────
                Expanded(
                  child: _filtered.isEmpty
                      ? const _EmptyState()
                      : ListView.builder(
                          padding:
                              const EdgeInsets.fromLTRB(16, 12, 16, 88),
                          itemCount: groupKeys.length,
                          itemBuilder: (ctx, gi) {
                            final groupKey = groupKeys[gi];
                            final diaries = _grouped[groupKey]!;
                            return Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: EdgeInsets.only(
                                      top: gi == 0 ? 4 : 20,
                                      bottom: 10),
                                  child: Row(children: [
                                    Container(
                                      width: 3,
                                      height: 16,
                                      decoration: BoxDecoration(
                                        color: AppTheme.diaryAccent,
                                        borderRadius:
                                            BorderRadius.circular(2),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(groupKey,
                                        style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight:
                                                FontWeight.w700,
                                            color:
                                                AppTheme.textPrimary)),
                                    const SizedBox(width: 8),
                                    Text('${diaries.length}편',
                                        style: const TextStyle(
                                            fontSize: 12,
                                            color:
                                                AppTheme.textLight)),
                                  ]),
                                ),
                                ...diaries.map((d) => Padding(
                                      padding: const EdgeInsets.only(
                                          bottom: 10),
                                      child: _DiaryCard(
                                        diary: d,
                                        dateLabel:
                                            _fmtDateLabel(d.dateKey),
                                        onTap: () => _openDiary(d),
                                      ),
                                    )),
                              ],
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}

// ── Month Chip ────────────────────────────────────────────────────────────────

class _MonthChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _MonthChip(
      {required this.label,
      required this.selected,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(right: 8),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primaryLight : AppTheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color:
                selected ? AppTheme.primary : AppTheme.divider,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight:
                selected ? FontWeight.w600 : FontWeight.w400,
            color: selected
                ? AppTheme.primary
                : AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }
}

// ── Diary Card ────────────────────────────────────────────────────────────────

class _DiaryCard extends StatelessWidget {
  final Diary diary;
  final String dateLabel;
  final VoidCallback onTap;

  const _DiaryCard({
    required this.diary,
    required this.dateLabel,
    required this.onTap,
  });

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
              color: AppTheme.diaryAccent.withValues(alpha: 0.12),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: IntrinsicHeight(
          child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
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
            const SizedBox(width: 14),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      if (diary.mood != null) ...[
                        Text(diary.mood!,
                            style: const TextStyle(fontSize: 16)),
                        const SizedBox(width: 6),
                      ] else ...[
                        const Icon(Icons.auto_stories_outlined,
                            size: 13, color: AppTheme.diaryAccent),
                        const SizedBox(width: 5),
                      ],
                      Text(dateLabel,
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimary)),
                    ]),
                    const SizedBox(height: 6),
                    Text(
                      diary.content,
                      style: const TextStyle(
                          fontSize: 13,
                          color: AppTheme.textSecondary,
                          height: 1.5),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(right: 12),
              child: Icon(Icons.chevron_right_rounded,
                  size: 18, color: AppTheme.textLight),
            ),
          ]),
        ),
      ),
    );
  }
}

// ── Empty State ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 72,
          height: 72,
          decoration: const BoxDecoration(
              color: AppTheme.diaryAccentBg, shape: BoxShape.circle),
          child: const Icon(Icons.auto_stories_outlined,
              size: 34, color: AppTheme.diaryAccent),
        ),
        const SizedBox(height: 16),
        const Text('아직 작성된 일기가 없어요',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary)),
        const SizedBox(height: 6),
        const Text('캘린더에서 날짜를 탭해 일기를 써보세요',
            style: TextStyle(
                fontSize: 13, color: AppTheme.textLight)),
      ]),
    );
  }
}
