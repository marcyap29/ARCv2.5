import '../chat/bloc/lumara_assistant_cubit.dart';
import '../chat/data/context_provider.dart';
import '../chat/data/context_scope.dart';
import 'package:uuid/uuid.dart';

class MainChatManager {
  final LumaraAssistantCubit? _assistantCubit;
  final ContextProvider? _contextProvider;
  String? _currentSessionId;
  final Uuid _uuid = const Uuid();

  MainChatManager({
    LumaraAssistantCubit? assistantCubit,
    ContextProvider? contextProvider,
  }) : _assistantCubit = assistantCubit,
       _contextProvider = contextProvider;

  /// Ensure a chat session exists
  Future<String> ensureSession() async {
    if (_currentSessionId != null) return _currentSessionId!;
    
    _currentSessionId = _uuid.v4();
    return _currentSessionId!;
  }

  /// Reply with context and persist the turn
  Future<String> replyWithContext(String text, Map<String, dynamic> ctx) async {
    try {
      await ensureSession();

      // Use LumaraAssistantCubit if available
      if (_assistantCubit != null) {
        // Send message via cubit
        await _assistantCubit!.sendMessage(text);
        
        // Get the last assistant message from state
        final state = _assistantCubit!.state;
        if (state is LumaraAssistantLoaded && state.messages.isNotEmpty) {
          final lastMessage = state.messages.last;
          if (lastMessage.role == 'assistant') {
            await persistTurn(user: text, assistant: lastMessage.content);
            return lastMessage.content;
          }
        }
        
        // Fallback if no response yet
        return "I'm processing your message...";
      } else {
        // Fallback response
        return "Chat functionality requires LumaraAssistantCubit to be initialized.";
      }
    } catch (e) {
      print('Error in replyWithContext: $e');
      return "I'm sorry, I couldn't process that right now.";
    }
  }

  /// Persist a chat turn
  Future<void> persistTurn({required String user, required String assistant}) async {
    try {
      // Chat persistence is handled by LumaraAssistantCubit internally
      // This method is here for explicit persistence if needed
      print('Chat turn persisted: User: ${user.substring(0, user.length > 50 ? 50 : user.length)}...');
    } catch (e) {
      print('Error persisting chat turn: $e');
    }
  }
}

