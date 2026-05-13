import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('설정')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 16),
        children: [
          // ── 앱 정보 섹션 ──────────────────────────────────────────────
          _SectionLabel('앱 정보'),
          _SettingCard(
            margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
            child: Column(children: [
              _InfoTile(
                icon: Icons.auto_stories_rounded,
                iconColor: AppTheme.primary,
                label: 'Dayce',
                value: '일정과 일기를 한 곳에',
              ),
              const Divider(height: 1, indent: 56),
              _InfoTile(
                icon: Icons.info_outline_rounded,
                iconColor: AppTheme.textSecondary,
                label: '버전',
                value: '1.0.0',
              ),
            ]),
          ),

          const SizedBox(height: 16),

          // ── 저장소 섹션 ───────────────────────────────────────────────
          _SectionLabel('저장소'),
          _SettingCard(
            margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
            child: _InfoTile(
              icon: Icons.storage_rounded,
              iconColor: AppTheme.accent,
              label: '저장 위치',
              value: '기기 내부 저장소',
            ),
          ),
        ],
      ),
    );
  }
}

// ── Shared Widgets ────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 16, 6),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: AppTheme.textSecondary,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _SettingCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets margin;
  const _SettingCard({required this.child, required this.margin});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
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
      child: child,
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;

  const _InfoTile({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppTheme.primaryLight,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: iconColor, size: 18),
        ),
        const SizedBox(width: 14),
        Text(label,
            style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: AppTheme.textPrimary)),
        const Spacer(),
        Text(value,
            style: const TextStyle(
                fontSize: 14, color: AppTheme.textSecondary)),
      ]),
    );
  }
}
