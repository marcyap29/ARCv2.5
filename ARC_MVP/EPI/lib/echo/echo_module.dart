// ECHO Module - Expressive Contextual Heuristic Output layer (voice of LUMARA)
// Externalized safety, dignity, and phase-aware response generation

// Core ECHO service
export 'echo_service.dart';
export 'echo_integration.dart';

// ECHO system prompts and templates
export 'prompts/echo_system_prompt.dart';
export 'prompts/phase_templates.dart';

// Core integration layers
export 'core/atlas_phase_integration.dart';
export 'core/mira_memory_grounding.dart';

// Voice and style management
export 'voice/lumara_voice_controller.dart';

// Safety and validation
export 'safety/rivet_lite_validator.dart';

// Response management and generation (legacy)
export 'response/lumara_assistant_cubit.dart';
export 'response/prompts/lumara_system_prompt.dart';
export 'response/prompts/prompt_library.dart';

// Provider-agnostic LLM interfaces
export 'providers/llm/rule_based_adapter.dart';
export 'providers/llm/prompt_templates.dart';
// TODO: Re-enable after fixing QwenModel dependencies
// export 'providers/llm/qwen_adapter.dart';
// export 'providers/llm/lumara_native.dart';

// Context and data models
export 'models/data/context_scope.dart';
export 'models/data/context_provider.dart';
export 'models/data/models/lumara_message.dart';