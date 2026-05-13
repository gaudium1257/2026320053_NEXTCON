import 'package:flutter/material.dart';

class AppTheme {
  // ── Palette ──────────────────────────────────────────────────────────────
  static const Color primary       = Color(0xFF3D5AFE); // 인디고 블루
  static const Color primaryDark   = Color(0xFF0031CA);
  static const Color primaryLight  = Color(0xFFE8EAFF); // 인디고 연
  static const Color accent        = Color(0xFF00BFA5); // 민트/틸
  static const Color background    = Color(0xFFF5F6FF); // 연 라벤더 화이트
  static const Color surface       = Color(0xFFFFFFFF);
  static const Color diaryAccent   = Color(0xFFFFD600); // 따뜻한 노란빛
  static const Color diaryAccentBg = Color(0xFFFFFDE7); // 연한 노란 배경
  static const Color textPrimary   = Color(0xFF1A1A2E);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textLight     = Color(0xFF9CA3AF);
  static const Color divider       = Color(0xFFE8EAF6);
  static const Color errorRed      = Color(0xFFEF5350);

  // ── Shadow ───────────────────────────────────────────────────────────────
  static const Color _shadow = Color(0x263D5AFE);

  // ── Theme ────────────────────────────────────────────────────────────────
  static ThemeData get theme {
    return ThemeData(
      useMaterial3: true,
      // Pretendard 폰트 사용 — pubspec.yaml에 폰트 asset 추가 필요
      // 없으면 시스템 폰트로 자동 fallback
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

      // ── AppBar: 파란 배경 / 흰 텍스트 ──────────────────────────────────
      appBarTheme: const AppBarTheme(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontFamily: 'Pretendard',
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: Colors.white,
          letterSpacing: -0.3,
        ),
        iconTheme: IconThemeData(color: Colors.white),
      ),

      // ── Card: 흰 배경 + 인디고 그림자 ─────────────────────────────────
      cardTheme: const CardThemeData(
        color: surface,
        elevation: 2,
        shadowColor: _shadow,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
      ),

      // ── Input ─────────────────────────────────────────────────────────
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
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

      // ── FilledButton ───────────────────────────────────────────────────
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: Color(0x663D5AFE),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(vertical: 14),
          textStyle: const TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 15,
              fontWeight: FontWeight.w600),
        ),
      ),

      // ── OutlinedButton ─────────────────────────────────────────────────
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

      // ── TextButton ────────────────────────────────────────────────────
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          textStyle: const TextStyle(fontSize: 14),
        ),
      ),

      // ── FAB: Extended 스타일 ───────────────────────────────────────────
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 3,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(16))),
        extendedPadding:
            EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        extendedTextStyle: TextStyle(
            fontFamily: 'Pretendard',
            fontSize: 15,
            fontWeight: FontWeight.w600),
      ),

      // ── NavigationBar ─────────────────────────────────────────────────
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

      // ── Switch ────────────────────────────────────────────────────────
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

      // ── Divider ───────────────────────────────────────────────────────
      dividerTheme: const DividerThemeData(
        color: divider,
        thickness: 1,
        space: 0,
      ),

      // ── Dialog ───────────────────────────────────────────────────────
      dialogTheme: const DialogThemeData(
        backgroundColor: surface,
        elevation: 4,
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

      // ── SnackBar ──────────────────────────────────────────────────────
      snackBarTheme: SnackBarThemeData(
        backgroundColor: textPrimary,
        contentTextStyle:
            const TextStyle(color: Colors.white, fontSize: 13),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10)),
        behavior: SnackBarBehavior.floating,
      ),

      // ── Chip (월별 필터 등) ────────────────────────────────────────────
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
