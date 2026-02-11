import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';

import 'package:my_app/shared/app_colors.dart';
import 'package:my_app/shared/ui/home/home_view.dart';
import 'package:my_app/arc/chat/ui/lumara_splash_screen.dart';
import 'package:my_app/mira/store/arcx/services/arcx_import_service_v2.dart';
import 'package:my_app/arc/chat/chat/chat_repo_impl.dart';
import 'package:my_app/services/phase_regime_service.dart';
import 'package:my_app/services/rivet_sweep_service.dart';
import 'package:my_app/services/analytics_service.dart';
import 'package:my_app/services/user_phase_service.dart';
import 'package:my_app/ui/auth/sign_in_screen.dart';

// Global repo + cubit
import 'package:my_app/arc/core/journal_repository.dart';
import 'package:my_app/core/models/entry_mode.dart';
import 'package:my_app/arc/chat/data/context_scope.dart' as arc_scope;
import 'package:my_app/arc/chat/data/context_provider.dart' as arc_context;
import 'package:my_app/arc/chat/bloc/lumara_assistant_cubit.dart' as arc_cubit;
import 'package:my_app/arc/ui/timeline/timeline_cubit.dart';
import 'package:my_app/arc/core/journal_capture_cubit.dart';
import 'package:my_app/arc/core/keyword_extraction_cubit.dart';
import 'package:my_app/core/a11y/a11y_flags.dart';
import 'package:my_app/prism/atlas/rivet/rivet_provider.dart';
import 'package:my_app/core/services/app_lifecycle_manager.dart';
import 'package:my_app/echo/echo_module.dart';
import 'package:my_app/shared/ui/settings/settings_cubit.dart';
import 'package:my_app/services/pending_conversation_service.dart';
import 'package:my_app/mira/store/arcx/import_progress_cubit.dart';
import 'package:hive/hive.dart';

// Global navigator key for deep linking from notifications
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class App extends StatefulWidget {
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  final AppLifecycleManager _lifecycleManager = AppLifecycleManager();
  static const MethodChannel _arcxChannel = MethodChannel('arcx/import');

  @override
  void initState() {
    super.initState();
    _lifecycleManager.initialize();
    _setupARCXHandler();
    // Initialize crash detection on app start
    PendingConversationService.initialize();
  }
  
  /// Setup ARCX import handler for iOS open-in events.
  /// Runs import in background and shows mini status bar on HomeView.
  void _setupARCXHandler() {
    _arcxChannel.setMethodCallHandler((call) async {
      if (call.method == 'onOpenARCX') {
        final String arcxPath = call.arguments['arcxPath'];
        final ctx = navigatorKey.currentContext;
        if (!mounted || ctx == null) return;
        final progressCubit = ctx.read<ImportProgressCubit>();
        final journalRepo = ctx.read<JournalRepository>();
        progressCubit.start();
        Navigator.of(ctx).pushNamedAndRemoveUntil('/home', (route) => false);
        // Run import in background; mini bar on HomeView shows progress
        Future(() async {
          try {
            final chatRepo = ChatRepoImpl.instance;
            await chatRepo.initialize();
            PhaseRegimeService? phaseRegimeService;
            try {
              final analyticsService = AnalyticsService();
              final rivetSweepService = RivetSweepService(analyticsService);
              phaseRegimeService = PhaseRegimeService(analyticsService, rivetSweepService);
              await phaseRegimeService.initialize();
            } catch (_) {}
            final importService = ARCXImportServiceV2(
              journalRepo: journalRepo,
              chatRepo: chatRepo,
              phaseRegimeService: phaseRegimeService,
            );
            final result = await importService.import(
              arcxPath: arcxPath,
              options: ARCXImportOptions(
                validateChecksums: true,
                dedupeMedia: true,
                skipExisting: true,
                resolveLinks: true,
              ),
              password: null,
              onProgress: (message, [fraction = 0.0]) {
                progressCubit.update(message, fraction);
              },
            );
            if (result.success) {
              // Notify phase preview and Gantt to refresh after import
              PhaseRegimeService.regimeChangeNotifier.value = DateTime.now();
              UserPhaseService.phaseChangeNotifier.value = DateTime.now();
              progressCubit.complete(result);
            } else {
              progressCubit.fail(result.error);
            }
          } catch (e) {
            progressCubit.fail(e.toString());
          }
        });
      }
    });
  }

  @override

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        // One shared instance, available everywhere
        RepositoryProvider(create: (_) => JournalRepository()),
      ],
      child: MultiBlocProvider(
        providers: [
          // Long‑lived cubit used by multiple screens (timeline, etc.)
          BlocProvider(
            create: (context) {
              final cubit = TimelineCubit(journalRepository: context.read<JournalRepository>());
              // Defer loading to avoid blocking UI during startup
              Future.microtask(() => cubit.loadEntries());
              return cubit;
            },
          ),
          // Journal capture cubit for creating new entries
          BlocProvider(
            create: (context) => JournalCaptureCubit(context.read<JournalRepository>()),
          ),
          // Keyword extraction cubit for analyzing text
          BlocProvider(
            create: (context) => KeywordExtractionCubit(),
          ),
          // Accessibility cubit for accessibility features
          BlocProvider(
            create: (context) => A11yCubit(),
          ),
          // Settings cubit used by settings screens (DataView, export/delete)
          BlocProvider(
            create: (context) => SettingsCubit(),
          ),
          // RIVET provider for phase stability gating
          Provider(
            create: (context) => RivetProvider(),
          ),
          // LUMARA Assistant cubit
          BlocProvider(
            create: (context) {
              final scope = arc_scope.LumaraScope.defaultScope;
              final contextProvider = arc_context.ContextProvider(scope);

              return arc_cubit.LumaraAssistantCubit(
                contextProvider: contextProvider,
              )..initialize();
            },
          ),
          // Global import progress (mini status bar in HomeView)
          BlocProvider(create: (_) => ImportProgressCubit()),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          navigatorKey: navigatorKey,
          title: 'EPI',
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: kcPrimaryGradient.colors.first,
              brightness: Brightness.light,
            ),
            scaffoldBackgroundColor: kcBackgroundColor,
            useMaterial3: true,
          ),
          darkTheme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: kcPrimaryGradient.colors.first,
              brightness: Brightness.dark,
            ),
            scaffoldBackgroundColor: kcBackgroundColor,
            useMaterial3: true,
          ),
          themeMode: ThemeMode.dark,
          home: const LumaraSplashScreen(),
          onGenerateRoute: (settings) {
            switch (settings.name) {
              case '/home':
                final args = settings.arguments;
                final EntryMode? mode = args is EntryMode ? args : null;
                return MaterialPageRoute(
                  builder: (context) => HomeView(initialMode: mode),
                  settings: settings,
                );
              case '/sign-in':
                return MaterialPageRoute(
                  builder: (context) => const SignInScreen(),
                  settings: settings,
                );
              default:
                return MaterialPageRoute(
                  builder: (context) => HomeView(),
                  settings: settings,
                );
            }
          },
        ),
      ),
    );
  }
}
