import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';

import 'package:my_app/shared/app_colors.dart';
import 'package:my_app/features/startup/startup_view.dart';
import 'package:my_app/arc/core/widgets/journal_edit_view.dart';

// Global repo + cubit
import 'package:my_app/arc/core/journal_repository.dart';
import 'package:my_app/features/timeline/timeline_cubit.dart';
import 'package:my_app/arc/core/journal_capture_cubit.dart';
import 'package:my_app/arc/core/keyword_extraction_cubit.dart';
import 'package:my_app/core/a11y/a11y_flags.dart';
import 'package:my_app/rivet/rivet_module.dart';
import 'package:my_app/core/services/app_lifecycle_manager.dart';
import 'package:my_app/mode/first_responder/fr_settings_cubit.dart';
import 'package:my_app/mode/coach/coach_mode_cubit.dart';
import 'package:my_app/mode/coach/coach_droplet_service.dart';
import 'package:my_app/mode/coach/coach_share_service.dart';
import 'package:my_app/echo/echo_module.dart';
import 'package:my_app/features/settings/settings_cubit.dart';
import 'package:hive/hive.dart';

class App extends StatefulWidget {
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  final AppLifecycleManager _lifecycleManager = AppLifecycleManager();

  @override
  void initState() {
    super.initState();
    _lifecycleManager.initialize();
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
            create: (context) =>
                TimelineCubit(journalRepository: context.read<JournalRepository>())
                  ..loadEntries(),
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
          // First Responder settings cubit
          BlocProvider(
            create: (context) => FRSettingsCubit(),
          ),
          // Coach Mode cubit
          BlocProvider(
            create: (context) {
              final dropletService = CoachDropletService(
                dropletTemplatesBox: Hive.box('coach_droplet_templates'),
                dropletResponsesBox: Hive.box('coach_droplet_responses'),
              );
              return CoachModeCubit(
                dropletService: dropletService,
                shareService: CoachShareService(
                  dropletService: dropletService,
                  shareBundlesBox: Hive.box('coach_share_bundles'),
                ),
                settingsBox: Hive.box('settings'),
              );
            },
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
          home: const StartupView(),
          routes: {
            '/journal-edit': (context) {
              final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
              return JournalEditView(
                entry: args['entry'],
                entryIndex: args['entryIndex'],
              );
            },
          },
        ),
      ),
    );
  }
}
