import '../models/coach_models.dart';

// --- Pre-Session Check-in ---
final preSessionV1 = CoachDropletTemplate(
  id: "coach.pre_session.v1",
  title: "Pre-Session Check-in",
  subtitle: "Surface what matters right now.",
  isDefault: true,
  tags: ["pre", "session", "prep"],
  fields: [
    DropletField(
      id: "focusTopic",
      type: DropletFieldType.text,
      label: "Main topic today",
      help: "One line works",
      required: true,
    ),
    DropletField(
      id: "mood",
      type: DropletFieldType.scale,
      label: "Current mood (1–7)",
      min: 1,
      max: 7,
      required: true,
    ),
    DropletField(
      id: "energy",
      type: DropletFieldType.scale,
      label: "Energy (1–7)",
      min: 1,
      max: 7,
      required: true,
    ),
    DropletField(
      id: "wins",
      type: DropletFieldType.text,
      label: "Small win since last session",
      required: false,
    ),
    DropletField(
      id: "frictions",
      type: DropletFieldType.chips,
      label: "What feels sticky?",
      options: ["time", "focus", "fear", "clarity", "support", "other"],
      required: false,
    ),
  ],
);

// --- Post-Session Debrief ---
final postSessionV1 = CoachDropletTemplate(
  id: "coach.post_session.v1",
  title: "Post-Session Debrief",
  subtitle: "Capture insights while fresh.",
  isDefault: true,
  tags: ["post", "session", "debrief"],
  fields: [
    DropletField(
      id: "insight",
      type: DropletFieldType.text,
      label: "Biggest insight",
      required: true,
    ),
    DropletField(
      id: "commitment",
      type: DropletFieldType.text,
      label: "One commitment this week",
      required: true,
    ),
    DropletField(
      id: "confidence",
      type: DropletFieldType.scale,
      label: "Confidence to follow through (1–7)",
      min: 1,
      max: 7,
      required: true,
    ),
    DropletField(
      id: "supportNeeded",
      type: DropletFieldType.text,
      label: "Support needed",
      required: false,
    ),
  ],
);

// --- Weekly Goals & Friction Map ---
final weeklyGoalsV1 = CoachDropletTemplate(
  id: "coach.weekly_goals.v1",
  title: "Weekly Goals & Friction Map",
  subtitle: "Pick 1–3 goals and name likely blockers.",
  isDefault: true,
  tags: ["weekly", "goals"],
  fields: [
    DropletField(
      id: "goal1",
      type: DropletFieldType.text,
      label: "Goal 1",
      required: true,
    ),
    DropletField(
      id: "goal2",
      type: DropletFieldType.text,
      label: "Goal 2",
      required: false,
    ),
    DropletField(
      id: "goal3",
      type: DropletFieldType.text,
      label: "Goal 3",
      required: false,
    ),
    DropletField(
      id: "blockers",
      type: DropletFieldType.chips,
      label: "Potential blockers",
      options: ["time", "scoping", "perfection", "unknowns", "dependencies", "motivation"],
      required: false,
    ),
  ],
);

// --- Stress Pulse (1-min PANAS-lite) ---
final stressPulseV1 = CoachDropletTemplate(
  id: "coach.stress_pulse.v1",
  title: "Stress Pulse (1-min)",
  subtitle: "Quick pulse to spot trends.",
  isDefault: true,
  tags: ["pulse", "stress"],
  fields: [
    DropletField(
      id: "stress",
      type: DropletFieldType.scale,
      label: "Stress (1–7)",
      min: 1,
      max: 7,
      required: true,
    ),
    DropletField(
      id: "valence",
      type: DropletFieldType.scale,
      label: "Mood (1–7)",
      min: 1,
      max: 7,
      required: true,
    ),
  ],
);

// --- Diet Intake (single quick meal) ---
final dietIntakeV1 = CoachDropletTemplate(
  id: "coach.diet_intake.v1",
  title: "Diet Intake (Quick Meal)",
  subtitle: "Log one meal or snack in under a minute.",
  isDefault: true,
  tags: ["diet", "meal", "nutrition"],
  fields: [
    DropletField(
      id: "when",
      type: DropletFieldType.datetime,
      label: "When",
      required: true,
    ),
    DropletField(
      id: "mealType",
      type: DropletFieldType.chips,
      label: "Type",
      required: true,
      options: ["breakfast", "lunch", "dinner", "snack", "drink"],
    ),
    DropletField(
      id: "items",
      type: DropletFieldType.text,
      label: "What did you have?",
      help: "Comma-separated",
      required: true,
    ),
    DropletField(
      id: "calories",
      type: DropletFieldType.number,
      label: "Est. calories (optional)",
      required: false,
    ),
    DropletField(
      id: "protein_g",
      type: DropletFieldType.number,
      label: "Protein g (opt.)",
      required: false,
    ),
    DropletField(
      id: "carbs_g",
      type: DropletFieldType.number,
      label: "Carbs g (opt.)",
      required: false,
    ),
    DropletField(
      id: "fat_g",
      type: DropletFieldType.number,
      label: "Fat g (opt.)",
      required: false,
    ),
    DropletField(
      id: "notes",
      type: DropletFieldType.text,
      label: "Notes (opt.)",
      required: false,
    ),
  ],
);

// --- Daily Habits Check-in ---
final habitsDailyV1 = CoachDropletTemplate(
  id: "coach.habits_daily.v1",
  title: "Daily Habits Check-in",
  subtitle: "Tap the habits you completed today.",
  isDefault: true,
  tags: ["habits", "routine", "daily"],
  fields: [
    DropletField(
      id: "date",
      type: DropletFieldType.date,
      label: "Date",
      required: true,
    ),
    DropletField(
      id: "done",
      type: DropletFieldType.chips,
      label: "Completed today",
      options: ["journal", "exercise", "meditate", "reading", "no-sugar", "lights-out-11", "water-8c", "pomodoro-3"],
      required: false,
    ),
    DropletField(
      id: "comment",
      type: DropletFieldType.text,
      label: "Optional note",
      required: false,
    ),
  ],
);

// --- Checklist Done (freeform) ---
final checklistDoneV1 = CoachDropletTemplate(
  id: "coach.checklist_done.v1",
  title: "Checklist Done",
  subtitle: "Log what you checked off.",
  isDefault: true,
  tags: ["tasks", "done", "checklist"],
  fields: [
    DropletField(
      id: "date",
      type: DropletFieldType.date,
      label: "Date",
      required: true,
    ),
    DropletField(
      id: "items",
      type: DropletFieldType.text,
      label: "Items completed",
      help: "Comma-separated",
      required: true,
    ),
    DropletField(
      id: "effort",
      type: DropletFieldType.scale,
      label: "Effort felt (1–7)",
      min: 1,
      max: 7,
      required: false,
    ),
  ],
);

// --- Sleep & Recovery ---
final sleepRecoveryV1 = CoachDropletTemplate(
  id: "coach.sleep_recovery.v1",
  title: "Sleep & Recovery",
  subtitle: "Basic nightly data.",
  isDefault: true,
  tags: ["sleep", "recovery"],
  fields: [
    DropletField(
      id: "date",
      type: DropletFieldType.date,
      label: "Night of",
      required: true,
    ),
    DropletField(
      id: "bedtime",
      type: DropletFieldType.time,
      label: "Bedtime",
      required: false,
    ),
    DropletField(
      id: "waketime",
      type: DropletFieldType.time,
      label: "Wake time",
      required: false,
    ),
    DropletField(
      id: "hours",
      type: DropletFieldType.number,
      label: "Hours slept (est.)",
      required: false,
    ),
    DropletField(
      id: "quality",
      type: DropletFieldType.scale,
      label: "Quality (1–7)",
      min: 1,
      max: 7,
      required: false,
    ),
    DropletField(
      id: "caffeinePm",
      type: DropletFieldType.bool,
      label: "Caffeine after 2pm?",
      required: false,
    ),
    DropletField(
      id: "notes",
      type: DropletFieldType.text,
      label: "Notes (opt.)",
      required: false,
    ),
  ],
);

// --- Exercise Session ---
final exerciseSessionV1 = CoachDropletTemplate(
  id: "coach.exercise_session.v1",
  title: "Exercise Session",
  subtitle: "Log today's movement.",
  isDefault: true,
  tags: ["exercise", "fitness", "movement"],
  fields: [
    DropletField(
      id: "when",
      type: DropletFieldType.datetime,
      label: "When",
      required: true,
    ),
    DropletField(
      id: "type",
      type: DropletFieldType.chips,
      label: "Type",
      required: true,
      options: ["walk", "run", "gym", "yoga", "cycle", "swim", "sport", "rehab"],
    ),
    DropletField(
      id: "duration",
      type: DropletFieldType.number,
      label: "Duration (min)",
      required: false,
    ),
    DropletField(
      id: "intensity",
      type: DropletFieldType.scale,
      label: "Intensity (1–7)",
      min: 1,
      max: 7,
      required: false,
    ),
    DropletField(
      id: "notes",
      type: DropletFieldType.text,
      label: "Notes (opt.)",
      required: false,
    ),
  ],
);

// --- Strength Session (Simple) ---
final strengthSimpleV1 = CoachDropletTemplate(
  id: "coach.strength_simple.v1",
  title: "Strength Session (Simple)",
  subtitle: "Log your main lifts fast.",
  isDefault: true,
  tags: ["strength", "weights", "gym", "session", "simple"],
  fields: [
    DropletField(
      id: "when",
      type: DropletFieldType.datetime,
      label: "When",
      required: true,
    ),
    DropletField(
      id: "split",
      type: DropletFieldType.chips,
      label: "Split",
      required: false,
      options: ["full-body", "upper", "lower", "push", "pull", "legs", "arms", "core"],
    ),
    DropletField(
      id: "exercises",
      type: DropletFieldType.text,
      required: true,
      label: "Exercises (quick)",
      help: "e.g., Squat 3x5@225; Bench 3x5@185; Row 3x8@115",
    ),
    DropletField(
      id: "duration",
      type: DropletFieldType.number,
      label: "Duration (min)",
      required: false,
    ),
    DropletField(
      id: "topSetRpe",
      type: DropletFieldType.scale,
      label: "Top set RPE (1–10)",
      required: false,
      min: 1,
      max: 10,
    ),
    DropletField(
      id: "prHit",
      type: DropletFieldType.bool,
      label: "Hit a PR?",
      required: false,
    ),
    DropletField(
      id: "notes",
      type: DropletFieldType.text,
      label: "Notes (opt.)",
      required: false,
    ),
  ],
);

// --- Cardio Session ---
final cardioSessionV1 = CoachDropletTemplate(
  id: "coach.cardio_session.v1",
  title: "Cardio Session",
  subtitle: "Type, duration, effort, optional distance/HR.",
  isDefault: true,
  tags: ["cardio", "endurance", "aerobic"],
  fields: [
    DropletField(
      id: "when",
      type: DropletFieldType.datetime,
      label: "When",
      required: true,
    ),
    DropletField(
      id: "type",
      type: DropletFieldType.chips,
      label: "Type",
      required: true,
      options: ["walk", "run", "cycle", "row", "swim", "hike", "erg", "other"],
    ),
    DropletField(
      id: "duration",
      type: DropletFieldType.number,
      label: "Duration (min)",
      required: true,
    ),
    DropletField(
      id: "distance",
      type: DropletFieldType.number,
      label: "Distance (mi/km)",
      required: false,
    ),
    DropletField(
      id: "avgHr",
      type: DropletFieldType.number,
      label: "Avg HR (bpm) (opt.)",
      required: false,
    ),
    DropletField(
      id: "rpe",
      type: DropletFieldType.scale,
      label: "RPE (1–10)",
      min: 1,
      max: 10,
      required: false,
    ),
    DropletField(
      id: "notes",
      type: DropletFieldType.text,
      label: "Notes (opt.)",
      required: false,
    ),
  ],
);

// --- Hydration ---
final hydrationV1 = CoachDropletTemplate(
  id: "coach.hydration.v1",
  title: "Hydration",
  subtitle: "Daily fluids quick log.",
  isDefault: true,
  tags: ["hydration", "water"],
  fields: [
    DropletField(
      id: "date",
      type: DropletFieldType.date,
      label: "Date",
      required: true,
    ),
    DropletField(
      id: "water_oz",
      type: DropletFieldType.number,
      label: "Water (oz)",
      required: false,
    ),
    DropletField(
      id: "electrolytes",
      type: DropletFieldType.bool,
      label: "Electrolytes today?",
      required: false,
    ),
    DropletField(
      id: "notes",
      type: DropletFieldType.text,
      label: "Notes (opt.)",
      required: false,
    ),
  ],
);

final defaultDroplets = [
  // Core coaching droplets
  preSessionV1,
  postSessionV1,
  weeklyGoalsV1,
  stressPulseV1,
  // Lifestyle tracking droplets
  dietIntakeV1,
  habitsDailyV1,
  checklistDoneV1,
  sleepRecoveryV1,
  exerciseSessionV1,
  // Fitness droplets
  strengthSimpleV1,
  cardioSessionV1,
  hydrationV1,
];
