import 'package:flutter/material.dart';

class AppTheme {
  // ── Palette ───────────────────────────────────────────────────────────────
  static const Color primary       = Color(0xFF7C5CFC); // 바이올렛 퍼플
  static const Color primaryDark   = Color(0xFF5B3DD8); // 딥 퍼플
  static const Color primaryLight  = Color(0xFFEDE8FF); // 연 라벤더
  static const Color accent        = Color(0xFFF59E0B); // 웜 앰버 (일기 포인트)
  static const Color background    = Color(0xFFF8F7FC); // 아이보리·퍼플 크림
  static const Color surface       = Color(0xFFFFFFFF); // 카드/시트 순백
  static const Color diaryAccent   = Color(0xFFF59E0B); // 앰버
  static const Color diaryAccentBg = Color(0xFFFFF8E6); // 연 앰버 배경
  static const Color textPrimary   = Color(0xFF1D1640); // 거의 검정·퍼플 베이스
  static const Color textSecondary = Color(0xFF6B6485); // 뮤트 라벤더-그레이
  static const Color textLight     = Color(0xFFA8A3BF); // 연 라벤더-그레이
  static const Color divider       = Color(0xFFECEAF5); // 아주 연한 퍼플 구분선
  static const Color errorRed      = Color(0xFFEF5350);

  // ── Shadow ────────────────────────────────────────────────────────────────
  static const Color _shadow = Color(0x147C5CFC); // 8% 퍼플 그림자

  // ── BoxShadow 헬퍼 ────────────────────────────────────────────────────────
  static List<BoxShadow> get cardShadow => const [
        BoxShadow(color: _shadow, blurRadius: 14, offset: Offset(0, 3)),
      ];
  static List<BoxShadow> get softShadow => const [
        BoxShadow(color: _shadow, blurRadius: 8, offset: Offset(0, 2)),
      ];

  // ── Theme ─────────────────────────────────────────────────────────────────
  static ThemeData get theme {
    return ThemeData(
      useMaterial3: true,
      fontFamily: 'Pretendard',
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        brightness: Brightness.light,
      ).copyWith(
        primary: primary,
        onPrimary: Colors.white,
        primaryContainer: primaryLight,
        secondary: accent,
        onSecondary: Colors.white,
        surface: surface,
        onSurface: textPrimary,
        error: errorRed,
      ),
      scaffoldBackgroundColor: background,

      // ── AppBar: 흰 배경 + 연한 하단 그림자 (밝은 미니멀) ─────────────────
      appBarTheme: AppBarTheme(
        backgroundColor: surface,
        foregroundColor: textPrimary,
        elevation: 0,
        scrolledUnderElevation: 1,
        shadowColor: _shadow,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        titleTextStyle: const TextStyle(
          fontFamily: 'Pretendard',
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: textPrimary,
          letterSpacing: -0.3,
        ),
        iconTheme: const IconThemeData(color: primary),
        shape: Border(
          bottom: BorderSide(
            color: divider,
            width: 1,
          ),
        ),
      ),

      // ── Card ──────────────────────────────────────────────────────────────
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shadowColor: _shadow,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
      ),

      // ── Input ─────────────────────────────────────────────────────────────
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: background,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primary, width: 1.8),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: errorRed),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: errorRed, width: 1.8),
        ),
        hintStyle: const TextStyle(color: textLight, fontSize: 15),
        labelStyle: const TextStyle(color: textSecondary),
      ),

      // ── FilledButton ──────────────────────────────────────────────────────
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: const Color(0x667C5CFC),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(vertical: 14),
          textStyle: const TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 15,
              fontWeight: FontWeight.w600),
        ),
      ),

      // ── OutlinedButton ────────────────────────────────────────────────────
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          side: const BorderSide(color: divider),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          textStyle: const TextStyle(fontSize: 14),
        ),
      ),

      // ── TextButton ────────────────────────────────────────────────────────
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          textStyle: const TextStyle(fontSize: 14),
        ),
      ),

      // ── FAB ───────────────────────────────────────────────────────────────
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(16))),
        extendedPadding:
            EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        extendedTextStyle: TextStyle(
            fontFamily: 'Pretendard',
            fontSize: 15,
            fontWeight: FontWeight.w600),
      ),

      // ── NavigationBar ─────────────────────────────────────────────────────
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        elevation: 0,
        indicatorColor: primaryLight,
        height: 64,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final sel = states.contains(WidgetState.selected);
          return TextStyle(
            fontFamily: 'Pretendard',
            fontSize: 11,
            fontWeight: sel ? FontWeight.w600 : FontWeight.w400,
            color: sel ? primary : textLight,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final sel = states.contains(WidgetState.selected);
          return IconThemeData(
              color: sel ? primary : textLight, size: 22);
        }),
      ),

      // ── Switch ────────────────────────────────────────────────────────────
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected)
                ? primary
                : Colors.grey[400]),
        trackColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected)
                ? primaryLight
                : Colors.grey[200]),
      ),

      // ── Divider ───────────────────────────────────────────────────────────
      dividerTheme: const DividerThemeData(
        color: divider,
        thickness: 1,
        space: 0,
      ),

      // ── Dialog ────────────────────────────────────────────────────────────
      dialogTheme: const DialogThemeData(
        backgroundColor: surface,
        elevation: 8,
        shadowColor: _shadow,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(20))),
        titleTextStyle: TextStyle(
            fontFamily: 'Pretendard',
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: textPrimary),
        contentTextStyle:
            TextStyle(fontSize: 14, color: textSecondary),
      ),

      // ── SnackBar ──────────────────────────────────────────────────────────
      snackBarTheme: SnackBarThemeData(
        backgroundColor: textPrimary,
        contentTextStyle:
            const TextStyle(color: Colors.white, fontSize: 13),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10)),
        behavior: SnackBarBehavior.floating,
      ),

      // ── Chip ──────────────────────────────────────────────────────────────
      chipTheme: ChipThemeData(
        backgroundColor: surface,
        selectedColor: primaryLight,
        side: const BorderSide(color: divider),
        labelStyle:
            const TextStyle(fontSize: 13, color: textSecondary),
        secondaryLabelStyle: const TextStyle(
            fontSize: 13,
            color: primary,
            fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        showCheckmark: false,
      ),
    );
  }
}
