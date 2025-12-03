/**
 * LUMARA Closing Statement Engine
 * 
 * Provides a pool of 75 closing lines across 5 categories with preference learning support.
 * Each closing is designed to avoid repetition and adapt to user preferences over time.
 */

export type ClosingCategory = 
  | "reflection_emotion"
  | "planning_action"
  | "identity_phase"
  | "regulation_overwhelm"
  | "neutral_light";

export type ClosingStyle = 
  | "soft_question"
  | "reflective_echo"
  | "gentle_prompt"
  | "non_prompt_closure"
  | "pause_affirmation"
  | "next_step_suggestion"
  | "user_led_turn";

export type AtlasPhase = 
  | "Discovery"
  | "Expansion"
  | "Transition"
  | "Consolidation"
  | "Recovery"
  | "Breakthrough"
  | "Any";

export interface ClosingPattern {
  id: string;
  text: string;
  category: ClosingCategory;
  style: ClosingStyle;
  phase_bias: AtlasPhase[];
  energy_level: "low" | "medium" | "high";
  tags?: string[];
}

/**
 * Pool of 75 closing lines organized by category
 */
export const CLOSING_PATTERNS: ClosingPattern[] = [
  // Reflection / Emotion Processing (1-15)
  {
    id: "ref_001",
    text: "Do you want to stay with this feeling a bit longer or let it rest here for now?",
    category: "reflection_emotion",
    style: "soft_question",
    phase_bias: ["Recovery", "Consolidation"],
    energy_level: "low",
    tags: ["gentle", "emotion-focused"]
  },
  {
    id: "ref_002",
    text: "Is this something you want to unpack more, or is naming it enough for today?",
    category: "reflection_emotion",
    style: "soft_question",
    phase_bias: ["Discovery", "Transition"],
    energy_level: "medium",
    tags: ["exploratory"]
  },
  {
    id: "ref_003",
    text: "Would it help to follow this thread a little further, or pause and come back later?",
    category: "reflection_emotion",
    style: "gentle_prompt",
    phase_bias: ["Discovery", "Expansion"],
    energy_level: "medium",
    tags: ["thread-following"]
  },
  {
    id: "ref_004",
    text: "Do you want to describe this in more detail, or is this level of clarity sufficient?",
    category: "reflection_emotion",
    style: "soft_question",
    phase_bias: ["Consolidation", "Any"],
    energy_level: "medium",
    tags: ["detail-oriented"]
  },
  {
    id: "ref_005",
    text: "Is there one more angle you want to explore, or does this feel complete for now?",
    category: "reflection_emotion",
    style: "soft_question",
    phase_bias: ["Discovery", "Expansion"],
    energy_level: "medium",
    tags: ["exploratory"]
  },
  {
    id: "ref_006",
    text: "Would you rather deepen into this emotion or just mark that it is here?",
    category: "reflection_emotion",
    style: "soft_question",
    phase_bias: ["Recovery", "Consolidation"],
    energy_level: "low",
    tags: ["gentle", "acceptance"]
  },
  {
    id: "ref_007",
    text: "Do you want to explore where this feeling comes from, or simply acknowledge it and pause?",
    category: "reflection_emotion",
    style: "soft_question",
    phase_bias: ["Discovery", "Transition"],
    energy_level: "medium",
    tags: ["root-cause", "acknowledgment"]
  },
  {
    id: "ref_008",
    text: "Is this a moment to stay with the feeling, or to give your system a break?",
    category: "reflection_emotion",
    style: "pause_affirmation",
    phase_bias: ["Recovery", "Consolidation"],
    energy_level: "low",
    tags: ["self-care", "gentle"]
  },
  {
    id: "ref_009",
    text: "Would it help to name what this emotion is asking for, or leave it unnamed for now?",
    category: "reflection_emotion",
    style: "soft_question",
    phase_bias: ["Discovery", "Transition"],
    energy_level: "medium",
    tags: ["naming", "needs-focused"]
  },
  {
    id: "ref_010",
    text: "Do you want to track how this feeling shifts, or just note that it showed up today?",
    category: "reflection_emotion",
    style: "soft_question",
    phase_bias: ["Consolidation", "Any"],
    energy_level: "medium",
    tags: ["tracking", "observation"]
  },
  {
    id: "ref_011",
    text: "Is there anything unsaid about this emotion that you want to put into words?",
    category: "reflection_emotion",
    style: "gentle_prompt",
    phase_bias: ["Discovery", "Expansion"],
    energy_level: "medium",
    tags: ["expression", "unspoken"]
  },
  {
    id: "ref_012",
    text: "Would it help to link this feeling to a past moment, or keep it grounded in today?",
    category: "reflection_emotion",
    style: "soft_question",
    phase_bias: ["Consolidation", "Transition"],
    energy_level: "medium",
    tags: ["temporal-linking", "present-focused"]
  },
  {
    id: "ref_013",
    text: "Do you want to explore what this emotion might be protecting, or leave that for later?",
    category: "reflection_emotion",
    style: "soft_question",
    phase_bias: ["Discovery", "Breakthrough"],
    energy_level: "medium",
    tags: ["protective-function", "depth"]
  },
  {
    id: "ref_014",
    text: "Is this a feeling you want to revisit soon, or one you simply needed to record?",
    category: "reflection_emotion",
    style: "soft_question",
    phase_bias: ["Consolidation", "Any"],
    energy_level: "low",
    tags: ["recording", "future-reference"]
  },
  {
    id: "ref_015",
    text: "Do you want to write one more line about how this feels in your body, or stop here?",
    category: "reflection_emotion",
    style: "soft_question",
    phase_bias: ["Recovery", "Consolidation"],
    energy_level: "low",
    tags: ["somatic", "embodied"]
  },

  // Planning / Action (16-30)
  {
    id: "plan_001",
    text: "Do you want to identify one concrete next step, or is reflection enough for now?",
    category: "planning_action",
    style: "next_step_suggestion",
    phase_bias: ["Expansion", "Breakthrough"],
    energy_level: "medium",
    tags: ["action-oriented", "concrete"]
  },
  {
    id: "plan_002",
    text: "Should we distill this into a single action, or keep it as a note to yourself?",
    category: "planning_action",
    style: "next_step_suggestion",
    phase_bias: ["Expansion", "Transition"],
    energy_level: "medium",
    tags: ["distillation", "action"]
  },
  {
    id: "plan_003",
    text: "Would a tiny next move help you feel less stuck, or does holding the insight feel better?",
    category: "planning_action",
    style: "soft_question",
    phase_bias: ["Transition", "Breakthrough"],
    energy_level: "medium",
    tags: ["unstuck", "small-steps"]
  },
  {
    id: "plan_004",
    text: "Do you want to turn this into a checklist item, or leave it as context for later you?",
    category: "planning_action",
    style: "soft_question",
    phase_bias: ["Expansion", "Consolidation"],
    energy_level: "medium",
    tags: ["organization", "future-reference"]
  },
  {
    id: "plan_005",
    text: "Is it useful to set a small experiment here, or just recognize the pattern for now?",
    category: "planning_action",
    style: "soft_question",
    phase_bias: ["Discovery", "Expansion"],
    energy_level: "medium",
    tags: ["experimentation", "pattern-recognition"]
  },
  {
    id: "plan_006",
    text: "Should we define a specific time to revisit this, or trust that it will resurface when needed?",
    category: "planning_action",
    style: "soft_question",
    phase_bias: ["Consolidation", "Any"],
    energy_level: "low",
    tags: ["scheduling", "trust"]
  },
  {
    id: "plan_007",
    text: "Would a one-sentence plan help, or is today about understanding rather than doing?",
    category: "planning_action",
    style: "soft_question",
    phase_bias: ["Discovery", "Consolidation"],
    energy_level: "low",
    tags: ["planning", "understanding"]
  },
  {
    id: "plan_008",
    text: "Do you want to choose a next step you can take in the next 24 hours, or keep this open?",
    category: "planning_action",
    style: "next_step_suggestion",
    phase_bias: ["Expansion", "Breakthrough"],
    energy_level: "medium",
    tags: ["time-bound", "immediate"]
  },
  {
    id: "plan_009",
    text: "Is this the moment to decide on a direction, or to let the idea simmer longer?",
    category: "planning_action",
    style: "soft_question",
    phase_bias: ["Discovery", "Transition"],
    energy_level: "medium",
    tags: ["decision", "patience"]
  },
  {
    id: "plan_010",
    text: "Would writing a simple 'do next' line help you, or would that add pressure today?",
    category: "planning_action",
    style: "soft_question",
    phase_bias: ["Recovery", "Consolidation"],
    energy_level: "low",
    tags: ["pressure-aware", "gentle"]
  },
  {
    id: "plan_011",
    text: "Do you want to mark a priority here, or leave everything as a free-form reflection?",
    category: "planning_action",
    style: "soft_question",
    phase_bias: ["Expansion", "Transition"],
    energy_level: "medium",
    tags: ["prioritization", "flexibility"]
  },
  {
    id: "plan_012",
    text: "Should we separate what you can control from what you cannot, or is that too much right now?",
    category: "planning_action",
    style: "soft_question",
    phase_bias: ["Recovery", "Any"],
    energy_level: "low",
    tags: ["control", "boundaries"]
  },
  {
    id: "plan_013",
    text: "Would a tiny commitment to yourself feel supportive, or does non-commitment feel safer?",
    category: "planning_action",
    style: "soft_question",
    phase_bias: ["Recovery", "Consolidation"],
    energy_level: "low",
    tags: ["commitment", "safety"]
  },
  {
    id: "plan_014",
    text: "Do you want to define what 'good enough' looks like for this, or avoid goals for now?",
    category: "planning_action",
    style: "soft_question",
    phase_bias: ["Consolidation", "Recovery"],
    energy_level: "low",
    tags: ["standards", "flexibility"]
  },
  {
    id: "plan_015",
    text: "Is this a place to choose momentum, or a place to accept where things currently stand?",
    category: "planning_action",
    style: "soft_question",
    phase_bias: ["Transition", "Consolidation"],
    energy_level: "medium",
    tags: ["momentum", "acceptance"]
  },

  // Identity / Phase Insight (31-45)
  {
    id: "id_001",
    text: "Do you want to connect this to how you see yourself changing, or leave it as a snapshot?",
    category: "identity_phase",
    style: "reflective_echo",
    phase_bias: ["Transition", "Breakthrough"],
    energy_level: "medium",
    tags: ["identity", "change"]
  },
  {
    id: "id_002",
    text: "Should we link this to your current phase, or simply let it stand as a moment in time?",
    category: "identity_phase",
    style: "soft_question",
    phase_bias: ["Consolidation", "Any"],
    energy_level: "medium",
    tags: ["phase-awareness", "present-moment"]
  },
  {
    id: "id_003",
    text: "Would it help to name what this says about who you are becoming, or is that too heavy right now?",
    category: "identity_phase",
    style: "soft_question",
    phase_bias: ["Breakthrough", "Expansion"],
    energy_level: "high",
    tags: ["becoming", "weight-aware"]
  },
  {
    id: "id_004",
    text: "Do you want to mark this as a shift in your story, or keep it as a quieter note?",
    category: "identity_phase",
    style: "soft_question",
    phase_bias: ["Transition", "Breakthrough"],
    energy_level: "medium",
    tags: ["narrative", "shifts"]
  },
  {
    id: "id_005",
    text: "Is there a word or phrase that captures what this moment means in your larger arc?",
    category: "identity_phase",
    style: "gentle_prompt",
    phase_bias: ["Consolidation", "Any"],
    energy_level: "medium",
    tags: ["language", "meaning-making"]
  },
  {
    id: "id_006",
    text: "Would you like to tag this as part of a theme in your life, or not categorize it at all?",
    category: "identity_phase",
    style: "soft_question",
    phase_bias: ["Consolidation", "Any"],
    energy_level: "medium",
    tags: ["themes", "categorization"]
  },
  {
    id: "id_007",
    text: "Do you want to reflect on how past-you would have handled this, or keep the focus on now-you?",
    category: "identity_phase",
    style: "soft_question",
    phase_bias: ["Consolidation", "Transition"],
    energy_level: "medium",
    tags: ["temporal-self", "present-focus"]
  },
  {
    id: "id_008",
    text: "Should we call out any tension between who you feel you are and who you are acting as?",
    category: "identity_phase",
    style: "soft_question",
    phase_bias: ["Discovery", "Transition"],
    energy_level: "medium",
    tags: ["authenticity", "tension"]
  },
  {
    id: "id_009",
    text: "Would it help to see this as part of a longer pattern, or treat it as an isolated event?",
    category: "identity_phase",
    style: "soft_question",
    phase_bias: ["Consolidation", "Any"],
    energy_level: "medium",
    tags: ["patterns", "context"]
  },
  {
    id: "id_010",
    text: "Do you want to name which phase this feels like, or leave the phase language aside here?",
    category: "identity_phase",
    style: "soft_question",
    phase_bias: ["Any"],
    energy_level: "low",
    tags: ["phase-naming", "meta-awareness"]
  },
  {
    id: "id_011",
    text: "Is there a new value or principle emerging here that you want to name?",
    category: "identity_phase",
    style: "gentle_prompt",
    phase_bias: ["Breakthrough", "Expansion"],
    energy_level: "high",
    tags: ["values", "principles"]
  },
  {
    id: "id_012",
    text: "Would it help to write one line about what this teaches you about yourself?",
    category: "identity_phase",
    style: "gentle_prompt",
    phase_bias: ["Consolidation", "Breakthrough"],
    energy_level: "medium",
    tags: ["learning", "self-knowledge"]
  },
  {
    id: "id_013",
    text: "Do you want to flag this as a turning point, or keep it as a subtle adjustment?",
    category: "identity_phase",
    style: "soft_question",
    phase_bias: ["Breakthrough", "Transition"],
    energy_level: "medium",
    tags: ["turning-points", "subtlety"]
  },
  {
    id: "id_014",
    text: "Should we trace how this connects to earlier entries, or let it stay local to today?",
    category: "identity_phase",
    style: "soft_question",
    phase_bias: ["Consolidation", "Any"],
    energy_level: "medium",
    tags: ["connection", "temporal-linking"]
  },
  {
    id: "id_015",
    text: "Do you want to note how this aligns or conflicts with the person you are trying to become?",
    category: "identity_phase",
    style: "soft_question",
    phase_bias: ["Transition", "Breakthrough"],
    energy_level: "medium",
    tags: ["alignment", "aspiration"]
  },

  // Regulation / Overwhelm (46-60)
  {
    id: "reg_001",
    text: "Do you need one small grounding step right now, or does simply naming this feel enough?",
    category: "regulation_overwhelm",
    style: "pause_affirmation",
    phase_bias: ["Recovery", "Any"],
    energy_level: "low",
    tags: ["grounding", "naming"]
  },
  {
    id: "reg_002",
    text: "Would it help to slow down with a brief pause, or keep moving while the energy is here?",
    category: "regulation_overwhelm",
    style: "pause_affirmation",
    phase_bias: ["Recovery", "Any"],
    energy_level: "low",
    tags: ["pace", "energy-awareness"]
  },
  {
    id: "reg_003",
    text: "Do you want to write one stabilizing sentence to yourself, or close gently here?",
    category: "regulation_overwhelm",
    style: "pause_affirmation",
    phase_bias: ["Recovery", "Any"],
    energy_level: "low",
    tags: ["self-support", "stabilizing"]
  },
  {
    id: "reg_004",
    text: "Should we simplify this to one thing that matters most, or leave the complexity as is?",
    category: "regulation_overwhelm",
    style: "soft_question",
    phase_bias: ["Recovery", "Any"],
    energy_level: "low",
    tags: ["simplification", "prioritization"]
  },
  {
    id: "reg_005",
    text: "Would focusing on just the next hour help, or is it better not to plan anything right now?",
    category: "regulation_overwhelm",
    style: "soft_question",
    phase_bias: ["Recovery", "Any"],
    energy_level: "low",
    tags: ["time-horizon", "planning"]
  },
  {
    id: "reg_006",
    text: "Do you want a tiny self-support action, or is rest the only thing that makes sense?",
    category: "regulation_overwhelm",
    style: "soft_question",
    phase_bias: ["Recovery", "Any"],
    energy_level: "low",
    tags: ["self-support", "rest"]
  },
  {
    id: "reg_007",
    text: "Is this a moment to step away from the screen, or to stay with the feeling a bit longer?",
    category: "regulation_overwhelm",
    style: "pause_affirmation",
    phase_bias: ["Recovery", "Any"],
    energy_level: "low",
    tags: ["boundaries", "presence"]
  },
  {
    id: "reg_008",
    text: "Would it help to write a brief reassurance to your future self, or keep this without advice?",
    category: "regulation_overwhelm",
    style: "soft_question",
    phase_bias: ["Recovery", "Consolidation"],
    energy_level: "low",
    tags: ["reassurance", "future-self"]
  },
  {
    id: "reg_009",
    text: "Do you want to mark this as 'heavy' so we tread lightly around it later, or not label it?",
    category: "regulation_overwhelm",
    style: "soft_question",
    phase_bias: ["Recovery", "Any"],
    energy_level: "low",
    tags: ["labeling", "sensitivity"]
  },
  {
    id: "reg_010",
    text: "Should we gently narrow your focus to one concrete thing, or keep this as a broad download?",
    category: "regulation_overwhelm",
    style: "soft_question",
    phase_bias: ["Recovery", "Any"],
    energy_level: "low",
    tags: ["focus", "scope"]
  },
  {
    id: "reg_011",
    text: "Would it support you to end with one kind sentence toward yourself?",
    category: "regulation_overwhelm",
    style: "gentle_prompt",
    phase_bias: ["Recovery", "Any"],
    energy_level: "low",
    tags: ["self-compassion", "kindness"]
  },
  {
    id: "reg_012",
    text: "Do you want to name one thing that feels safe or steady right now, or leave that for later?",
    category: "regulation_overwhelm",
    style: "soft_question",
    phase_bias: ["Recovery", "Any"],
    energy_level: "low",
    tags: ["safety", "stability"]
  },
  {
    id: "reg_013",
    text: "Is this a place to stop entirely, or to transition into something lighter?",
    category: "regulation_overwhelm",
    style: "soft_question",
    phase_bias: ["Recovery", "Any"],
    energy_level: "low",
    tags: ["stopping", "transition"]
  },
  {
    id: "reg_014",
    text: "Would it help to schedule a softer follow-up on this topic, or not tie yourself to that?",
    category: "regulation_overwhelm",
    style: "soft_question",
    phase_bias: ["Recovery", "Consolidation"],
    energy_level: "low",
    tags: ["scheduling", "flexibility"]
  },
  {
    id: "reg_015",
    text: "Do you want to mark that you are near your limit, or keep that implicit?",
    category: "regulation_overwhelm",
    style: "soft_question",
    phase_bias: ["Recovery", "Any"],
    energy_level: "low",
    tags: ["boundaries", "limits"]
  },

  // Neutral / Light Interaction (61-75)
  {
    id: "neut_001",
    text: "Is there anything else tugging at your attention before we pause?",
    category: "neutral_light",
    style: "user_led_turn",
    phase_bias: ["Any"],
    energy_level: "low",
    tags: ["open-ended", "attention"]
  },
  {
    id: "neut_002",
    text: "Do you want to explore one more thread, or is this a good stopping point?",
    category: "neutral_light",
    style: "soft_question",
    phase_bias: ["Any"],
    energy_level: "low",
    tags: ["exploration", "stopping"]
  },
  {
    id: "neut_003",
    text: "Would it feel good to add one small detail, or are you satisfied with what you captured?",
    category: "neutral_light",
    style: "soft_question",
    phase_bias: ["Any"],
    energy_level: "low",
    tags: ["completion", "satisfaction"]
  },
  {
    id: "neut_004",
    text: "Do you want to shift topics, or close out for now?",
    category: "neutral_light",
    style: "user_led_turn",
    phase_bias: ["Any"],
    energy_level: "low",
    tags: ["topic-shift", "closing"]
  },
  {
    id: "neut_005",
    text: "Is there a lighter note you would like to end on today?",
    category: "neutral_light",
    style: "gentle_prompt",
    phase_bias: ["Any"],
    energy_level: "low",
    tags: ["tone", "ending"]
  },
  {
    id: "neut_006",
    text: "Do you want to jot down one thing you are curious about next, or keep it open-ended?",
    category: "neutral_light",
    style: "soft_question",
    phase_bias: ["Discovery", "Any"],
    energy_level: "low",
    tags: ["curiosity", "future"]
  },
  {
    id: "neut_007",
    text: "Would a quick summary sentence help you remember this later, or not needed?",
    category: "neutral_light",
    style: "soft_question",
    phase_bias: ["Consolidation", "Any"],
    energy_level: "low",
    tags: ["summary", "memory"]
  },
  {
    id: "neut_008",
    text: "Do you want to tag this entry in any way, or leave it untagged?",
    category: "neutral_light",
    style: "soft_question",
    phase_bias: ["Any"],
    energy_level: "low",
    tags: ["organization", "tagging"]
  },
  {
    id: "neut_009",
    text: "Is this a moment to log anything practical (sleep, energy, context), or skip that?",
    category: "neutral_light",
    style: "soft_question",
    phase_bias: ["Any"],
    energy_level: "low",
    tags: ["practical", "logging"]
  },
  {
    id: "neut_010",
    text: "Would you like to end by naming one thing you are grateful for, or is that not fitting here?",
    category: "neutral_light",
    style: "soft_question",
    phase_bias: ["Consolidation", "Any"],
    energy_level: "low",
    tags: ["gratitude", "optional"]
  },
  {
    id: "neut_011",
    text: "Do you want to leave a brief note to tomorrow-you, or let this stand without a message?",
    category: "neutral_light",
    style: "soft_question",
    phase_bias: ["Any"],
    energy_level: "low",
    tags: ["future-self", "message"]
  },
  {
    id: "neut_012",
    text: "Is there any loose thought that wants to be captured before we wrap?",
    category: "neutral_light",
    style: "gentle_prompt",
    phase_bias: ["Any"],
    energy_level: "low",
    tags: ["capture", "completion"]
  },
  {
    id: "neut_013",
    text: "Would you prefer to keep going in a more analytical mode, or stop on this reflective note?",
    category: "neutral_light",
    style: "soft_question",
    phase_bias: ["Any"],
    energy_level: "low",
    tags: ["mode", "analytical"]
  },
  {
    id: "neut_014",
    text: "Do you want to close this as a short check-in, or turn it into a deeper session next time?",
    category: "neutral_light",
    style: "soft_question",
    phase_bias: ["Any"],
    energy_level: "low",
    tags: ["check-in", "depth"]
  },
  {
    id: "neut_015",
    text: "Is this a good place to pause the conversation, or is there one last thing to say?",
    category: "neutral_light",
    style: "user_led_turn",
    phase_bias: ["Any"],
    energy_level: "low",
    tags: ["pausing", "completion"]
  }
];

/**
 * Get closing patterns by category
 */
export function getClosingsByCategory(category: ClosingCategory): ClosingPattern[] {
  return CLOSING_PATTERNS.filter(p => p.category === category);
}

/**
 * Get closing patterns by phase bias
 */
export function getClosingsByPhase(phase: AtlasPhase): ClosingPattern[] {
  return CLOSING_PATTERNS.filter(p => 
    p.phase_bias.includes(phase) || p.phase_bias.includes("Any")
  );
}

/**
 * Get closing patterns by style
 */
export function getClosingsByStyle(style: ClosingStyle): ClosingPattern[] {
  return CLOSING_PATTERNS.filter(p => p.style === style);
}
