import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';

import 'multimodal_orchestrator_commands.dart';
import 'multimodal_mcp_orchestrator.dart';

/// Events for the Multimodal Orchestrator BLoC
abstract class MultimodalOrchestratorEvent extends Equatable {
  const MultimodalOrchestratorEvent();

  @override
  List<Object?> get props => [];
}

/// User tapped photo icon in journal entry
class UserTappedPhotoIcon extends MultimodalOrchestratorEvent {
  const UserTappedPhotoIcon();
}

/// User tapped video icon in journal entry
class UserTappedVideoIcon extends MultimodalOrchestratorEvent {
  const UserTappedVideoIcon();
}

/// User tapped audio icon in journal entry
class UserTappedAudioIcon extends MultimodalOrchestratorEvent {
  const UserTappedAudioIcon();
}

/// Execute custom command envelope
class ExecuteCommandEnvelope extends MultimodalOrchestratorEvent {
  final OrchestratorCommandEnvelope envelope;

  const ExecuteCommandEnvelope({required this.envelope});

  @override
  List<Object?> get props => [envelope];
}

/// Command execution completed
class CommandExecutionCompleted extends MultimodalOrchestratorEvent {
  final CommandExecutionResult result;

  const CommandExecutionCompleted({required this.result});

  @override
  List<Object?> get props => [result];
}

/// Reset orchestrator state
class ResetOrchestrator extends MultimodalOrchestratorEvent {
  const ResetOrchestrator();
}

/// States for the Multimodal Orchestrator BLoC
abstract class MultimodalOrchestratorState extends Equatable {
  const MultimodalOrchestratorState();

  @override
  List<Object?> get props => [];
}

/// Initial state
class MultimodalOrchestratorInitial extends MultimodalOrchestratorState {
  const MultimodalOrchestratorInitial();
}

/// Processing user intent
class MultimodalOrchestratorProcessing extends MultimodalOrchestratorState {
  final String intent;

  const MultimodalOrchestratorProcessing({required this.intent});

  @override
  List<Object?> get props => [intent];
}

/// Commands generated and ready for execution
class MultimodalOrchestratorCommandsReady extends MultimodalOrchestratorState {
  final OrchestratorCommandEnvelope envelope;

  const MultimodalOrchestratorCommandsReady({required this.envelope});

  @override
  List<Object?> get props => [envelope];
}

/// Executing commands
class MultimodalOrchestratorExecuting extends MultimodalOrchestratorState {
  final List<CommandResult> completedResults;
  final OrchestratorCommand? currentCommand;
  final int totalCommands;
  final int completedCommands;

  const MultimodalOrchestratorExecuting({
    required this.completedResults,
    this.currentCommand,
    required this.totalCommands,
    required this.completedCommands,
  });

  @override
  List<Object?> get props => [
    completedResults,
    currentCommand,
    totalCommands,
    completedCommands,
  ];

  double get progress => totalCommands > 0 ? completedCommands / totalCommands : 0.0;
}

/// Execution completed successfully
class MultimodalOrchestratorSuccess extends MultimodalOrchestratorState {
  final CommandExecutionResult result;

  const MultimodalOrchestratorSuccess({required this.result});

  @override
  List<Object?> get props => [result];
}

/// Execution failed
class MultimodalOrchestratorFailure extends MultimodalOrchestratorState {
  final String error;
  final CommandExecutionResult? partialResult;

  const MultimodalOrchestratorFailure({
    required this.error,
    this.partialResult,
  });

  @override
  List<Object?> get props => [error, partialResult];
}

/// BLoC for Multimodal Orchestrator
class MultimodalOrchestratorBloc extends Bloc<MultimodalOrchestratorEvent, MultimodalOrchestratorState> {
  final MultimodalMcpOrchestrator _orchestrator;

  MultimodalOrchestratorBloc({
    MultimodalMcpOrchestrator? orchestrator,
  }) : _orchestrator = orchestrator ?? MultimodalMcpOrchestrator(),
        super(const MultimodalOrchestratorInitial()) {
    
    on<UserTappedPhotoIcon>(_onUserTappedPhotoIcon);
    on<UserTappedVideoIcon>(_onUserTappedVideoIcon);
    on<UserTappedAudioIcon>(_onUserTappedAudioIcon);
    on<ExecuteCommandEnvelope>(_onExecuteCommandEnvelope);
    on<CommandExecutionCompleted>(_onCommandExecutionCompleted);
    on<ResetOrchestrator>(_onResetOrchestrator);
  }

  /// Handle photo icon tap
  Future<void> _onUserTappedPhotoIcon(
    UserTappedPhotoIcon event,
    Emitter<MultimodalOrchestratorState> emit,
  ) async {
    emit(const MultimodalOrchestratorProcessing(intent: 'user tapped photo icon in journal entry'));
    
    try {
      final envelope = await _orchestrator.processUserIntent('user tapped photo icon in journal entry');
      emit(MultimodalOrchestratorCommandsReady(envelope: envelope));
      
      // Auto-execute the commands
      await _executeCommands(envelope, emit);
    } catch (e) {
      emit(MultimodalOrchestratorFailure(error: e.toString()));
    }
  }

  /// Handle video icon tap
  Future<void> _onUserTappedVideoIcon(
    UserTappedVideoIcon event,
    Emitter<MultimodalOrchestratorState> emit,
  ) async {
    emit(const MultimodalOrchestratorProcessing(intent: 'user tapped video icon in journal entry'));
    
    try {
      final envelope = await _orchestrator.processUserIntent('user tapped video icon in journal entry');
      emit(MultimodalOrchestratorCommandsReady(envelope: envelope));
      
      // Auto-execute the commands
      await _executeCommands(envelope, emit);
    } catch (e) {
      emit(MultimodalOrchestratorFailure(error: e.toString()));
    }
  }

  /// Handle audio icon tap
  Future<void> _onUserTappedAudioIcon(
    UserTappedAudioIcon event,
    Emitter<MultimodalOrchestratorState> emit,
  ) async {
    emit(const MultimodalOrchestratorProcessing(intent: 'user tapped audio icon in journal entry'));
    
    try {
      final envelope = await _orchestrator.processUserIntent('user tapped audio icon in journal entry');
      emit(MultimodalOrchestratorCommandsReady(envelope: envelope));
      
      // Auto-execute the commands
      await _executeCommands(envelope, emit);
    } catch (e) {
      emit(MultimodalOrchestratorFailure(error: e.toString()));
    }
  }

  /// Handle custom command envelope execution
  Future<void> _onExecuteCommandEnvelope(
    ExecuteCommandEnvelope event,
    Emitter<MultimodalOrchestratorState> emit,
  ) async {
    emit(MultimodalOrchestratorCommandsReady(envelope: event.envelope));
    await _executeCommands(event.envelope, emit);
  }

  /// Handle command execution completion
  void _onCommandExecutionCompleted(
    CommandExecutionCompleted event,
    Emitter<MultimodalOrchestratorState> emit,
  ) {
    if (event.result.overallSuccess) {
      emit(MultimodalOrchestratorSuccess(result: event.result));
    } else {
      emit(MultimodalOrchestratorFailure(
        error: 'Command execution failed',
        partialResult: event.result,
      ));
    }
  }

  /// Reset orchestrator state
  void _onResetOrchestrator(
    ResetOrchestrator event,
    Emitter<MultimodalOrchestratorState> emit,
  ) {
    emit(const MultimodalOrchestratorInitial());
  }

  /// Execute commands with progress tracking
  Future<void> _executeCommands(
    OrchestratorCommandEnvelope envelope,
    Emitter<MultimodalOrchestratorState> emit,
  ) async {
    final results = <CommandResult>[];
    final totalCommands = envelope.commands.length;
    
    for (int i = 0; i < envelope.commands.length; i++) {
      final command = envelope.commands[i];
      
      emit(MultimodalOrchestratorExecuting(
        completedResults: List.from(results),
        currentCommand: command,
        totalCommands: totalCommands,
        completedCommands: i,
      ));
      
      try {
        final result = await _orchestrator.executeCommands(
          OrchestratorCommandEnvelope(commands: [command]),
        );
        
        if (result.results.isNotEmpty) {
          results.add(result.results.first);
        }
        
        // Stop if critical command failed
        if (result.results.isNotEmpty && 
            !result.results.first.success && 
            result.results.first.critical) {
          break;
        }
      } catch (e) {
        results.add(CommandResult(
          command: command,
          success: false,
          error: e.toString(),
          critical: true,
          data: {},
        ));
        break;
      }
    }
    
    final executionResult = CommandExecutionResult(
      results: results,
      overallSuccess: results.every((r) => r.success),
    );
    
    emit(MultimodalOrchestratorSuccess(result: executionResult));
  }
}

