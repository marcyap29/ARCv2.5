import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';

import 'package:my_app/shared/app_colors.dart';
import 'package:my_app/features/startup/startup_view.dart';
import 'package:my_app/features/journal/widgets/journal_edit_view.dart';

// Global repo + cubit
import 'package:my_app/repositories/journal_repository.dart';
import 'package:my_app/features/timeline/timeline_cubit.dart';
import 'package:my_app/features/journal/journal_capture_cubit.dart';
import 'package:my_app/features/journal/keyword_extraction_cubit.dart';
import 'package:my_app/core/a11y/a11y_flags.dart';
import 'package:my_app/core/rivet/rivet_provider.dart';

class App extends StatelessWidget {
  const App({super.key});

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
          // RIVET provider for phase stability gating
          Provider(
            create: (context) => RivetProvider(),
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
