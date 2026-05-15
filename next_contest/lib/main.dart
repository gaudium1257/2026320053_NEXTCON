import 'dart:ui' show PlatformDispatcher;
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/calendar_screen.dart';
import 'screens/diary_list_screen.dart';
import 'screens/splash_screen.dart';
import 'services/settings_service.dart';
import 'theme/app_theme.dart';

void _onError(Object error, StackTrace stack) {
  // 릴리즈: Crashlytics / Sentry 등 연동 지점
  if (kDebugMode) debugPrint('[ERROR] $error\n$stack');
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (details) {
    _onError(details.exception, details.stack ?? StackTrace.empty);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    _onError(error, stack);
    return true;
  };

  try {
    await SettingsService().init();
  } catch (e, st) {
    if (kDebugMode) debugPrint('SettingsService.init failed: $e\n$st');
  }
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarContrastEnforced: false,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );
  runApp(const DayceApp());
}

class DayceApp extends StatelessWidget {
  const DayceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Dayce',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      home: const SplashScreen(),
    );
  }
}

// ── Main Shell ────────────────────────────────────────────────────────────────

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;
  final _calendarKey = GlobalKey<CalendarScreenState>();
  final _diaryKey = GlobalKey<DiaryListScreenState>();
  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      CalendarScreen(key: _calendarKey),
      DiaryListScreen(key: _diaryKey),
    ];
  }

  void _onTabSelected(int i) {
    if (i == 1 && _currentIndex != 1) {
      // Entering diary tab — refresh list in case events were added
      _diaryKey.currentState?.refresh();
    } else if (i == 0 && _currentIndex != 0) {
      // Returning to calendar tab — sync diary indicators
      _calendarKey.currentState?.refresh();
    }
    setState(() => _currentIndex = i);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppTheme.surface,
          boxShadow: [
            BoxShadow(
              color: AppTheme.primary.withValues(alpha: 0.08),
              blurRadius: 16,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: _onTabSelected,
          backgroundColor: AppTheme.surface,
          elevation: 0,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.calendar_month_outlined),
              selectedIcon: Icon(Icons.calendar_month),
              label: '캘린더',
            ),
            NavigationDestination(
              icon: Icon(Icons.auto_stories_outlined),
              selectedIcon: Icon(Icons.auto_stories),
              label: '일기',
            ),
          ],
        ),
      ),
    );
  }
}
