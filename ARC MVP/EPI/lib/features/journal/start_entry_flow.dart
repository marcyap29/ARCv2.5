import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:my_app/features/journal/journal_capture_view.dart';
import 'package:my_app/features/journal/journal_capture_cubit.dart';
import 'package:my_app/features/journal/keyword_extraction_cubit.dart';
import 'package:my_app/repositories/journal_repository.dart';

class StartEntryFlow extends StatelessWidget {
  const StartEntryFlow({super.key});

  @override
  Widget build(BuildContext context) {
    // Navigate directly to New Entry screen
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (context) => JournalCaptureCubit(context.read<JournalRepository>()),
        ),
        BlocProvider(
          create: (context) => KeywordExtractionCubit()..initialize(),
        ),
      ],
      child: const JournalCaptureView(),
    );
  }
}