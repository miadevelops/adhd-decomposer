import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'core/theme/app_theme.dart';
import 'data/services/settings_service.dart';
import 'data/services/stats_service.dart';
import 'data/services/achievements_service.dart';
import 'data/services/widget_service.dart';
import 'data/services/notification_service.dart';
import 'data/services/analytics_service.dart';
import 'data/services/calendar_service.dart';
import 'data/services/routine_service.dart';
import 'data/services/purchase_service.dart';
import 'data/services/siri_service.dart';
import 'data/services/xp_service.dart';
import 'presentation/providers/task_provider.dart';
import 'presentation/providers/theme_provider.dart';
import 'presentation/screens/home_screen.dart';
import 'presentation/screens/onboarding/onboarding_screen.dart';
import 'presentation/screens/decompose_screen.dart';
import 'presentation/screens/execute_screen.dart';
import 'presentation/screens/stats_screen.dart';
import 'presentation/screens/routines_screen.dart';
import 'presentation/screens/body_double_screen.dart';

// Global navigator key for deep linking
final GlobalKey<NavigatorState> globalNavigatorKey =
    GlobalKey<NavigatorState>();

/// Runs one startup step without letting its failure block app launch.
Future<void> _initStep(String name, Future<void> Function() step) async {
  try {
    await step();
  } catch (e, stack) {
    debugPrint('Startup step "$name" failed: $e\n$stack');
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Fonts ship in assets/google_fonts, so never fetch them from Google at
  // runtime (works offline and avoids a third-party request on launch).
  GoogleFonts.config.allowRuntimeFetching = false;
  LicenseRegistry.addLicense(() async* {
    for (final family in const ['Nunito', 'Inter']) {
      final license =
          await rootBundle.loadString('assets/google_fonts/$family-OFL.txt');
      yield LicenseEntryWithLineBreaks(['google_fonts', family], license);
    }
  });

  // Initialize Hive for local storage
  await _initStep('hive', Hive.initFlutter);

  final settings = SettingsService();
  final themeProvider = ThemeProvider();
  final stats = StatsService();
  final achievements = AchievementsService();
  final notifications = NotificationService();
  final analytics = AnalyticsService();
  final calendar = CalendarService();
  final routines = RoutineService();
  final purchases = PurchaseService();
  final siri = SiriService();
  final xpService = XPService();

  // Settings first: other screens read it immediately.
  await _initStep('settings', settings.initialize);

  // Independent services start in parallel; a failure in one doesn't stop
  // the others or leave the user on a blank screen.
  await Future.wait([
    _initStep('theme', themeProvider.initialize),
    _initStep('stats+achievements', () async {
      await stats.initialize();
      await achievements.initialize(stats);
    }),
    _initStep('widgets', WidgetService.initialize),
    _initStep('notifications', notifications.initialize),
    _initStep('analytics', analytics.initialize),
    _initStep('calendar', calendar.initialize),
    _initStep('routines', routines.initialize),
    _initStep('purchases', purchases.initialize),
    _initStep('siri', siri.initialize),
    _initStep('xp', xpService.initialize),
    _initStep(
      'orientation',
      () => SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]),
    ),
  ]);
  runApp(ADHDDecomposerApp(
    settings: settings,
    stats: stats,
    achievements: achievements,
    notifications: notifications,
    calendar: calendar,
    routines: routines,
    purchases: purchases,
    xpService: xpService,
    themeProvider: themeProvider,
  ));
}

class ADHDDecomposerApp extends StatefulWidget {
  final SettingsService settings;
  final StatsService stats;
  final AchievementsService achievements;
  final NotificationService notifications;
  final CalendarService calendar;
  final RoutineService routines;
  final PurchaseService purchases;
  final XPService xpService;
  final ThemeProvider themeProvider;

  const ADHDDecomposerApp({
    super.key,
    required this.settings,
    required this.stats,
    required this.achievements,
    required this.notifications,
    required this.calendar,
    required this.routines,
    required this.purchases,
    required this.xpService,
    required this.themeProvider,
  });

  @override
  State<ADHDDecomposerApp> createState() => _ADHDDecomposerAppState();
}

class _ADHDDecomposerAppState extends State<ADHDDecomposerApp> {
  late bool _showOnboarding;

  /// A deep link that arrived during onboarding; it runs once that's done.
  VoidCallback? _pendingDeepLink;

  StreamSubscription<Uri?>? _widgetClickSubscription;

  @override
  void initState() {
    super.initState();
    _showOnboarding = !widget.settings.onboardingComplete;
    _handleWidgetLaunch();
    _listenToWidgetClicks();
    _setupNotificationHandling();
    _setupSiriHandlers();
  }

  @override
  void dispose() {
    _widgetClickSubscription?.cancel();
    super.dispose();
  }

  /// Single entry point for widget, notification and Siri navigation.
  /// Runs after the current frame so the navigator is ready, and waits until
  /// onboarding is finished so nothing is pushed on top of it.
  void _runDeepLink(VoidCallback action) {
    if (!mounted) return;
    if (_showOnboarding) {
      _pendingDeepLink = action;
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) action();
    });
  }

  /// Set up Siri Shortcuts navigation handlers
  void _setupSiriHandlers() {
    final siri = SiriService();

    siri.onStartNewTask = () => _runDeepLink(() => _navigateToRoute('decompose'));
    siri.onContinueTask = () => _runDeepLink(() => _navigateToRoute('execute'));
    siri.onShowProgress = () => _runDeepLink(() => _navigateToRoute('stats'));
    siri.onStartRoutine =
        (routineName) => _runDeepLink(() => _navigateToRoutine(routineName));
  }

  /// Starts the routine with this name, or opens the routines list if
  /// there's no exact match.
  void _navigateToRoutine(String routineName) {
    final context = globalNavigatorKey.currentContext;
    if (context == null) return;

    final wanted = routineName.trim().toLowerCase();
    final matches = context
        .read<RoutineService>()
        .routines
        .where((r) => r.name.trim().toLowerCase() == wanted);
    if (wanted.isNotEmpty && matches.isNotEmpty) {
      startRoutineFlow(context, matches.first);
    } else {
      _navigateToRoute('routines');
    }
  }

  Future<void> _handleWidgetLaunch() async {
    final uri = await WidgetService.getInitialUri();
    if (uri != null) {
      _runDeepLink(() => _navigateToRoute(uri.host));
    }
  }

  void _listenToWidgetClicks() {
    _widgetClickSubscription = WidgetService.widgetClicked.listen(
      (uri) {
        if (uri != null) {
          _runDeepLink(() => _navigateToRoute(uri.host));
        }
      },
      onError: (Object e) => debugPrint('Widget click stream error: $e'),
    );
  }

  void _setupNotificationHandling() {
    NotificationService.onNotificationTap = (payload) {
      if (payload != null) {
        _runDeepLink(() => _handleNotificationNavigation(payload));
      }
    };
  }

  void _handleNotificationNavigation(String payload) {
    final context = globalNavigatorKey.currentContext;
    if (context == null) return;

    switch (payload) {
      case NotificationService.payloadHome:
        // Navigate to home (pop all routes)
        Navigator.of(context).popUntil((route) => route.isFirst);
        break;

      case NotificationService.payloadExecute:
        // Navigate to execute screen
        _navigateToRoute('execute');
        break;

      case NotificationService.payloadStats:
        _navigateToRoute('stats');
        break;
    }
  }

  void _navigateToRoute(String route) {
    final context = globalNavigatorKey.currentContext;
    if (context == null) return;
    final navigator = Navigator.of(context);

    // Don't stack a second copy of the screen that's already on top.
    String? topRouteName;
    navigator.popUntil((r) {
      topRouteName = r.settings.name;
      return true;
    });
    if (topRouteName == route) return;
    final settings = RouteSettings(name: route);

    switch (route) {
      case 'decompose':
        Navigator.of(context).push(
          MaterialPageRoute(settings: settings, builder: (_) => const DecomposeScreen()),
        );
        break;
      case 'execute':
        // Navigate to execute screen if there's an active task
        final taskProvider = Provider.of<TaskProvider>(context, listen: false);
        if (taskProvider.activeTask != null) {
          Navigator.of(context).push(
            MaterialPageRoute(settings: settings, builder: (_) => const ExecuteScreen()),
          );
        } else if (taskProvider.activeTasks.isNotEmpty) {
          // Set the first active task as active and navigate
          final task = taskProvider.activeTasks.first;
          taskProvider.setActiveTask(task);
          Navigator.of(context).push(
            MaterialPageRoute(settings: settings, builder: (_) => const ExecuteScreen()),
          );
        }
        break;
      case 'stats':
        Navigator.of(context).push(
          MaterialPageRoute(settings: settings, builder: (_) => const StatsScreen()),
        );
        break;
      case 'routines':
        Navigator.of(context).push(
          MaterialPageRoute(settings: settings, builder: (_) => const RoutinesScreen()),
        );
        break;
      case 'bodydouble':
        Navigator.of(context).push(
          MaterialPageRoute(settings: settings, builder: (_) => const BodyDoubleScreen()),
        );
        break;
    }
  }

  void _completeOnboarding() {
    setState(() {
      _showOnboarding = false;
    });
    final pending = _pendingDeepLink;
    _pendingDeepLink = null;
    if (pending != null) _runDeepLink(pending);
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => TaskProvider(
            settings: widget.settings,
            stats: widget.stats,
            achievements: widget.achievements,
            notifications: widget.notifications,
            purchases: widget.purchases,
            xpService: widget.xpService,
          )..initialize(),
        ),
        Provider.value(value: widget.settings),
        Provider.value(value: widget.stats),
        ChangeNotifierProvider.value(value: widget.achievements),
        Provider.value(value: widget.notifications),
        Provider.value(value: widget.calendar),
        ChangeNotifierProvider.value(value: widget.routines),
        ChangeNotifierProvider.value(value: widget.purchases),
        ChangeNotifierProvider.value(value: widget.xpService),
        ChangeNotifierProvider.value(value: widget.themeProvider),
      ],
      child: Consumer2<ThemeProvider, XPService>(
        builder: (context, themeProvider, xpService, _) {
          return MaterialApp(
            title: 'Tiny Steps',
            navigatorKey: globalNavigatorKey,
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightThemeFor(xpService.selectedTheme),
            darkTheme: AppTheme.darkThemeFor(xpService.selectedTheme),
            themeMode: themeProvider.themeMode,
            home: _showOnboarding
                ? OnboardingScreen(onComplete: _completeOnboarding)
                : const HomeScreen(),
          );
        },
      ),
    );
  }
}
