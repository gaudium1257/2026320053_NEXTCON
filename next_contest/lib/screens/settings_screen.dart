import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import '../services/settings_service.dart';
import '../theme/app_theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _s = SettingsService();

  static const _palette = [
    0xFF3D5AFE,
    0xFFE53935,
    0xFFE91E8C,
    0xFF9C27B0,
    0xFF00ACC1,
    0xFF009688,
    0xFF43A047,
    0xFFFB8C00,
    0xFF6D4C41,
    0xFF546E7A,
  ];
  static const _moods = ['😊', '😄', '😢', '😤', '😴', '🤗'];
  static const _kAppVersion = '1.0.0';

  static const _viewLabels = ['일', '주', '월', '년'];

  Future<void> _applySetting(Future<void> Function() action) async {
    try {
      await action();
    } catch (e, st) {
      if (kDebugMode) debugPrint('SettingsScreen update failed: $e\n$st');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('설정 저장 중 오류가 발생했습니다.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('설정')),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
          children: [
            // ── 캘린더 ──────────────────────────────────────────────────────
            _SectionLabel('캘린더'),
            _SettingCard(
              children: [
                _TilePicker(
                  icon: Icons.calendar_month_rounded,
                  iconColor: AppTheme.primary,
                  label: '기본 보기',
                  value: _viewLabels[_s.defaultViewMode],
                  onTap: () => _pickFromList(
                    title: '기본 보기',
                    items: _viewLabels,
                    currentIndex: _s.defaultViewMode,
                    onSelected: (i) async {
                      await _applySetting(() => _s.setDefaultViewMode(i));
                      setState(() {});
                    },
                  ),
                ),

                const _Divider(),

                _TileSwitch(
                  icon: Icons.view_week_rounded,
                  iconColor: AppTheme.primary,
                  label: '주 시작 요일',
                  subtitle: _s.weekStartsOnSunday ? '일요일' : '월요일',
                  value: _s.weekStartsOnSunday,
                  onChanged: (v) async {
                    await _applySetting(() => _s.setWeekStartsOnSunday(v));
                    setState(() {});
                  },
                  trueLabel: '일요일 시작',
                  falseLabel: '월요일 시작',
                ),
              ],
            ),

            const SizedBox(height: 20),

            // ── 일정 ──────────────────────────────────────────────────────
            _SectionLabel('일정'),
            _SettingCard(
              children: [
                _TileWidget(
                  icon: Icons.palette_rounded,
                  iconColor: AppTheme.primary,
                  label: '기본 색상',
                  child: Wrap(
                    spacing: 8,
                    children: _palette.map((c) {
                      final selected = _s.defaultEventColor == c;
                      return GestureDetector(
                        onTap: () async {
                          await _applySetting(() => _s.setDefaultEventColor(c));
                          setState(() {});
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 120),
                          width: selected ? 28 : 24,
                          height: selected ? 28 : 24,
                          decoration: BoxDecoration(
                            color: Color(c),
                            shape: BoxShape.circle,
                            border: selected
                                ? Border.all(color: Color(c), width: 3)
                                : null,
                            boxShadow: selected
                                ? [
                                    BoxShadow(
                                      color: Color(c).withValues(alpha: 0.5),
                                      blurRadius: 6,
                                      spreadRadius: 1,
                                    ),
                                  ]
                                : null,
                          ),
                          child: selected
                              ? const Icon(
                                  Icons.check,
                                  size: 14,
                                  color: Colors.white,
                                )
                              : null,
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // ── 일기 ──────────────────────────────────────────────────────
            _SectionLabel('일기'),
            _SettingCard(
              children: [
                _TileSwitch(
                  icon: Icons.format_list_bulleted_rounded,
                  iconColor: AppTheme.diaryAccent,
                  label: '눈금선 표시',
                  subtitle: '글쓰기 영역에 줄을 표시해요',
                  value: _s.showRuledLines,
                  onChanged: (v) async {
                    await _applySetting(() => _s.setShowRuledLines(v));
                    setState(() {});
                  },
                ),

                const _Divider(),

                _TileWidget(
                  icon: Icons.mood_rounded,
                  iconColor: AppTheme.diaryAccent,
                  label: '기본 기분',
                  child: Row(
                    children: [
                      // "없음" option
                      GestureDetector(
                        onTap: () async {
                          await _applySetting(() => _s.setDefaultMood(null));
                          setState(() {});
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 120),
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: _s.defaultMood == null
                                ? AppTheme.primaryLight
                                : AppTheme.background,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: _s.defaultMood == null
                                  ? AppTheme.primary
                                  : AppTheme.divider,
                              width: _s.defaultMood == null ? 2 : 1,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              '없음',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: _s.defaultMood == null
                                    ? FontWeight.w700
                                    : FontWeight.w400,
                                color: _s.defaultMood == null
                                    ? AppTheme.primary
                                    : AppTheme.textLight,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      ..._moods.map((e) {
                        final selected = _s.defaultMood == e;
                        return GestureDetector(
                          onTap: () async {
                            await _applySetting(() => _s.setDefaultMood(e));
                            setState(() {});
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 120),
                            width: 36,
                            height: 36,
                            margin: const EdgeInsets.only(right: 6),
                            decoration: BoxDecoration(
                              color: selected
                                  ? AppTheme.diaryAccentBg
                                  : AppTheme.background,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: selected
                                    ? AppTheme.diaryAccent
                                    : Colors.transparent,
                                width: 2,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                e,
                                style: TextStyle(fontSize: selected ? 20 : 17),
                              ),
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),

                const _Divider(),

                _TileSwitch(
                  icon: Icons.notifications_rounded,
                  iconColor: AppTheme.diaryAccent,
                  label: '일기 알림',
                  subtitle: _s.diaryReminderEnabled
                      ? '매일 ${_s.diaryReminderHour.toString().padLeft(2, '0')}:'
                            '${_s.diaryReminderMinute.toString().padLeft(2, '0')} 알림'
                      : '꺼짐',
                  value: _s.diaryReminderEnabled,
                  onChanged: (v) async {
                    await _applySetting(() => _s.setDiaryReminderEnabled(v));
                    setState(() {});
                  },
                ),

                if (_s.diaryReminderEnabled) ...[
                  const _Divider(),
                  _TilePicker(
                    icon: Icons.access_time_rounded,
                    iconColor: AppTheme.diaryAccent,
                    label: '알림 시간',
                    value:
                        '${_s.diaryReminderHour.toString().padLeft(2, '0')}:'
                        '${_s.diaryReminderMinute.toString().padLeft(2, '0')}',
                    onTap: () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay(
                          hour: _s.diaryReminderHour,
                          minute: _s.diaryReminderMinute,
                        ),
                        builder: (ctx, child) => Theme(
                          data: Theme.of(ctx).copyWith(
                            colorScheme: Theme.of(
                              ctx,
                            ).colorScheme.copyWith(primary: AppTheme.primary),
                          ),
                          child: child!,
                        ),
                      );
                      if (picked == null) return;
                      await _applySetting(() async {
                        await _s.setDiaryReminderHour(picked.hour);
                        await _s.setDiaryReminderMinute(picked.minute);
                      });
                      setState(() {});
                    },
                  ),
                ],
              ],
            ),

            const SizedBox(height: 20),

            // ── 앱 정보 ────────────────────────────────────────────────────
            _SectionLabel('앱 정보'),
            _SettingCard(
              children: [
                _TileInfo(
                  icon: Icons.auto_stories_rounded,
                  iconColor: AppTheme.primary,
                  label: 'Dayce',
                  value: '일정과 일기를 한 곳에',
                ),
                const _Divider(),
                _TileInfo(
                  icon: Icons.info_outline_rounded,
                  iconColor: AppTheme.textSecondary,
                  label: '버전',
                  value: _kAppVersion,
                ),
                const _Divider(),
                _TileInfo(
                  icon: Icons.storage_rounded,
                  iconColor: AppTheme.diaryAccent,
                  label: '저장 위치',
                  value: '기기 내부 저장소',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── 헬퍼 ────────────────────────────────────────────────────────────────────

  Future<void> _pickFromList({
    required String title,
    required List<String> items,
    required int currentIndex,
    required Future<void> Function(int) onSelected,
  }) async {
    final picked = await showDialog<int>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
        children: items.asMap().entries.map((entry) {
          final selected = entry.key == currentIndex;
          return SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, entry.key),
            child: Row(
              children: [
                if (selected)
                  const Icon(
                    Icons.check_rounded,
                    size: 16,
                    color: AppTheme.primary,
                  )
                else
                  const SizedBox(width: 16),
                const SizedBox(width: 8),
                Text(
                  entry.value,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                    color: selected ? AppTheme.primary : AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
    if (picked != null) await onSelected(picked);
  }
}

// ── Layout Widgets ────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 0, 8),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AppTheme.textSecondary,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class _SettingCard extends StatelessWidget {
  final List<Widget> children;
  const _SettingCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 0),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) =>
      const Divider(height: 1, indent: 56, endIndent: 0);
}

// ── Tile Variants ─────────────────────────────────────────────────────────────

class _TileInfo extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  const _TileInfo({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          _IconBox(icon: icon, color: iconColor),
          const SizedBox(width: 14),
          Text(
            label,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: AppTheme.textPrimary,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _TilePicker extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final VoidCallback onTap;
  const _TilePicker({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            _IconBox(icon: icon, color: iconColor),
            const SizedBox(width: 14),
            Text(
              label,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: AppTheme.textPrimary,
              ),
            ),
            const Spacer(),
            Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: AppTheme.textLight,
            ),
          ],
        ),
      ),
    );
  }
}

class _TileSwitch extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final String? trueLabel;
  final String? falseLabel;
  const _TileSwitch({
    required this.icon,
    required this.iconColor,
    required this.label,
    this.subtitle,
    required this.value,
    required this.onChanged,
    this.trueLabel,
    this.falseLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          _IconBox(icon: icon, color: iconColor),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textPrimary,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: AppTheme.primary,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ],
      ),
    );
  }
}

class _TileWidget extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final Widget child;
  const _TileWidget({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _IconBox(icon: icon, color: iconColor),
              const SizedBox(width: 14),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Padding(padding: const EdgeInsets.only(left: 50), child: child),
        ],
      ),
    );
  }
}

class _IconBox extends StatelessWidget {
  final IconData icon;
  final Color color;
  const _IconBox({required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: AppTheme.primaryLight,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: color, size: 18),
    );
  }
}
