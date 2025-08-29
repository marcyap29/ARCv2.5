import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:my_app/shared/app_colors.dart';
import 'package:my_app/features/startup/startup_view.dart';

// Global repo + cubit
import 'package:my_app/repositories/journal_repository.dart';
import 'package:my_app/features/timeline/timeline_cubit.dart';

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
        ),
      ),
    );
  }
}
