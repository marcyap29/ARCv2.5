import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';

import 'package:my_app/shared/app_colors.dart';
import 'package:my_app/shared/ui/home/home_view.dart';
import 'package:my_app/mira/store/arcx/ui/arcx_import_progress_screen.dart';
import 'package:my_app/arc/chat/ui/lumara_splash_screen.dart';

// Global repo + cubit
import 'package:my_app/arc/core/journal_repository.dart';
import 'package:my_app/arc/ui/timeline/timeline_cubit.dart';
import 'package:my_app/arc/core/journal_capture_cubit.dart';
import 'package:my_app/arc/core/keyword_extraction_cubit.dart';
import 'package:my_app/core/a11y/a11y_flags.dart';
import 'package:my_app/prism/atlas/rivet/rivet_provider.dart';
import 'package:my_app/core/services/app_lifecycle_manager.dart';
import 'package:my_app/echo/echo_module.dart';
import 'package:my_app/shared/ui/settings/settings_cubit.dart';
import 'package:hive/hive.dart';

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
  }
  
  /// Setup ARCX import handler for iOS open-in events
  void _setupARCXHandler() {
    _arcxChannel.setMethodCallHandler((call) async {
      if (call.method == 'onOpenARCX') {
        final String arcxPath = call.arguments['arcxPath'];
        final String? manifestPath = call.arguments['manifestPath'];
        
        // Navigate to import screen
        if (mounted) {
          Navigator.of(context).push(
            MaterialPageRoute(
              fullscreenDialog: true,
              builder: (_) => ARCXImportProgressScreen(
                arcxPath: arcxPath,
                manifestPath: manifestPath,
              ),
            ),
          );
        }
      }
    });
  }

  @override
  void dispose() {
    _lifecycleManager.dispose();
    super.dispose();
  }

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
              const scope = LumaraScope.defaultScope;
              final contextProvider = ContextProvider(scope);
              return LumaraAssistantCubit(
                contextProvider: contextProvider,
              )..initialize();
            },
          ),
        ],
        child: MaterialApp(
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
          routes: {
          },
        ),
      ),
    );
  }
}
