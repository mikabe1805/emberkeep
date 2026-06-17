import '../models.dart';
import '../tokens.dart';
import 'ladders.dart';

/// Guided workouts (RESEARCH-workouts.md) — short, fully-curated, OFFLINE
/// movement sessions for people who want to be healthier but aren't gym rats.
/// Pure const content (no LLM, ever); only the *outcome* of finishing a
/// session becomes a transient Quest through the normal reward engine.

enum MoveKind {
  /// Counted reps — a slow-tap honor counter; DONE advances.
  reps,

  /// A hold or timed bout — a countdown ring; auto-advances at zero.
  timed,
}

class WorkoutMove {
  const WorkoutMove({
    required this.name,
    required this.kind,
    this.reps = 0,
    this.seconds = 0,
    this.perSide = false,
    required this.cue,
    required this.easier,
    this.restSeconds = 0,
    this.isWarmup = false,
    this.isCooldown = false,
    this.caution,
  });

  final String name;
  final MoveKind kind;

  /// Beginner rep count (per side when [perSide]).
  final int reps;

  /// Hold/work seconds for [MoveKind.timed].
  final int seconds;
  final bool perSide;

  /// One-line plain-language form cue.
  final String cue;

  /// The regression shown by the EASIER button.
  final String easier;

  /// Rest seconds AFTER this move (0 = straight on).
  final int restSeconds;

  /// Warm-up / cool-down framing (part of the win, not "work").
  final bool isWarmup;
  final bool isCooldown;

  /// Optional safety line shown under the cue.
  final String? caution;

  bool get isWork => !isWarmup && !isCooldown;
}

class Routine {
  const Routine({
    required this.id,
    required this.title,
    required this.blurb,
    required this.minutes,
    required this.difficulty,
    required this.stat,
    required this.evidenceTitle,
    required this.moves,
    this.restDay = false,
  });

  final String id;
  final String title;

  /// The disarming "this won't be Thor-level" intro line.
  final String blurb;

  /// Honest "~N min" estimate for the preview.
  final int minutes;

  /// 1–10 → the synthesized reward Quest's difficulty.
  final int difficulty;

  /// Stat.str for strength routines, Stat.vit for mobility/recovery.
  final Stat stat;

  /// Key into evidenceCards for the intro "why this works" card.
  final String evidenceTitle;

  final List<WorkoutMove> moves;

  /// A gentle recovery option, surfaced as the "sore/tired today" path.
  final bool restDay;

  /// Any timed WORK move present → finishing it on the clock can pay ×1.2.
  bool get hasTimedWork =>
      moves.any((m) => m.kind == MoveKind.timed && m.isWork);

  /// Count of real work moves (drives fair partial credit on an early exit).
  int get workMoves => moves.where((m) => m.isWork).length;
}

const _muscleCaution =
    'Feel it in the muscles — never the lower back, knees, or shoulders. Drop to the easier version if your form slips.';
const _stretchCaution = 'A mild pull is good. Sharp or joint pain? Back off.';

const routines = <Routine>[
  // ── R1 · the tiny rung as product ────────────────────────────────
  Routine(
    id: 'wake-up',
    title: 'Wake-Up Snack',
    blurb: 'Four minutes, doable in pyjamas. This counts — really.',
    minutes: 4,
    difficulty: 2,
    stat: Stat.str,
    evidenceTitle: 'Exercise snacks count',
    moves: [
      WorkoutMove(
        name: 'March on the spot',
        kind: MoveKind.timed,
        seconds: 45,
        cue: 'Pump bent arms, fists soft, stay tall.',
        easier: 'Seated march — lift alternate knees.',
        isWarmup: true,
      ),
      WorkoutMove(
        name: 'Shoulder rolls',
        kind: MoveKind.reps,
        reps: 10,
        cue: 'Arms hang loose, roll slow — 5 forward, 5 back.',
        easier: 'Smaller circles.',
        isWarmup: true,
      ),
      WorkoutMove(
        name: 'Sit-to-stand',
        kind: MoveKind.reps,
        reps: 5,
        restSeconds: 15,
        cue: 'Feet hip-width, drive up through your heels.',
        easier: 'From a higher chair, or push off your hands.',
        caution: _muscleCaution,
      ),
      WorkoutMove(
        name: 'Calf raises',
        kind: MoveKind.reps,
        reps: 6,
        restSeconds: 15,
        cue: 'Hand on a wall, rise tall, lower slowly.',
        easier: 'Both feet, seated.',
      ),
      WorkoutMove(
        name: 'Chest-opener stretch',
        kind: MoveKind.timed,
        seconds: 20,
        cue: 'Reach your arms back, chest gently up.',
        easier: 'Sit tall, smaller range.',
        isCooldown: true,
        caution: _stretchCaution,
      ),
    ],
  ),

  // ── R2 · the flagship ────────────────────────────────────────────
  Routine(
    id: 'full-body',
    title: 'Beginner Full Body',
    blurb: 'This won’t be Thor-level — promise. Gentle reps, lots of rest.',
    minutes: 13,
    difficulty: 4,
    stat: Stat.str,
    evidenceTitle: 'Start absurdly small',
    moves: [
      WorkoutMove(
        name: 'March on the spot',
        kind: MoveKind.timed,
        seconds: 60,
        cue: 'Pump your arms, stay tall, find a rhythm.',
        easier: 'Seated march.',
        isWarmup: true,
      ),
      WorkoutMove(
        name: 'Knee lifts',
        kind: MoveKind.reps,
        reps: 16,
        cue: 'Knee toward the opposite hand, abs tight, back straight.',
        easier: 'Hold a chair, smaller lift.',
        isWarmup: true,
      ),
      WorkoutMove(
        name: 'Sit-to-stand squat',
        kind: MoveKind.reps,
        reps: 6,
        restSeconds: 30,
        cue: 'Lean slightly forward, stand up through your heels.',
        easier: 'Higher chair, or use your hands.',
        caution: _muscleCaution,
      ),
      WorkoutMove(
        name: 'Wall press-up',
        kind: MoveKind.reps,
        reps: 8,
        restSeconds: 30,
        cue: 'Hands at chest height, body straight, bend the elbows.',
        easier: 'Stand closer to the wall.',
        caution: _muscleCaution,
      ),
      WorkoutMove(
        name: 'Calf raises',
        kind: MoveKind.reps,
        reps: 8,
        restSeconds: 30,
        cue: 'Hand on a chair, rise tall, lower slowly.',
        easier: 'Both feet, seated.',
      ),
      WorkoutMove(
        name: 'Sideways leg lift',
        kind: MoveKind.reps,
        reps: 5,
        perSide: true,
        restSeconds: 30,
        cue: 'Hold a chair, lift a straight leg out, control it down.',
        easier: 'Smaller lift.',
      ),
      WorkoutMove(
        name: 'Plank',
        kind: MoveKind.timed,
        seconds: 15,
        restSeconds: 30,
        cue: 'Forearms and toes (or knees), straight line, belly tight.',
        easier: 'Knees down, or hands on the wall.',
        caution: _muscleCaution,
      ),
      WorkoutMove(
        name: 'Standing hamstring stretch',
        kind: MoveKind.timed,
        seconds: 15,
        cue: 'Step one foot back, heel down, lean gently.',
        easier: 'Less range.',
        isCooldown: true,
        caution: _stretchCaution,
      ),
      WorkoutMove(
        name: 'Chest-opener',
        kind: MoveKind.timed,
        seconds: 15,
        cue: 'Reach your arms back, chest up.',
        easier: 'Sit tall.',
        isCooldown: true,
        caution: _stretchCaution,
      ),
    ],
  ),

  // ── R3 · rest-day / mobility ─────────────────────────────────────
  Routine(
    id: 'mobility',
    title: 'Gentle Mobility Flow',
    blurb: 'No sweat, no strain — just loosening the hinges. A kind rest day.',
    minutes: 9,
    difficulty: 2,
    stat: Stat.vit,
    evidenceTitle: 'Evening workouts are fine',
    restDay: true,
    moves: [
      WorkoutMove(
        name: 'Cat–Cow',
        kind: MoveKind.timed,
        seconds: 75,
        cue: 'On all fours, arch then round, slow, with your breath.',
        easier: 'Seated, hands on knees, round and arch.',
        isWarmup: true,
      ),
      WorkoutMove(
        name: 'Hip circles',
        kind: MoveKind.reps,
        reps: 5,
        perSide: true,
        cue: 'Hands on hips, big slow circles.',
        easier: 'Hold a chair, smaller circles.',
      ),
      WorkoutMove(
        name: 'Ankle rotations',
        kind: MoveKind.reps,
        reps: 5,
        perSide: true,
        cue: 'Lift one foot, draw slow circles with the toes.',
        easier: 'Seated.',
      ),
      WorkoutMove(
        name: 'Upper-body twist',
        kind: MoveKind.reps,
        reps: 5,
        perSide: true,
        cue: 'Cross arms to shoulders, turn your torso, hips still.',
        easier: 'Smaller range, seated.',
        caution: _stretchCaution,
      ),
      WorkoutMove(
        name: 'Chest stretch',
        kind: MoveKind.timed,
        seconds: 20,
        cue: 'Reach arms back, chest gently forward and up.',
        easier: 'Less range.',
        isCooldown: true,
        caution: _stretchCaution,
      ),
      WorkoutMove(
        name: 'Neck rotation',
        kind: MoveKind.reps,
        reps: 3,
        perSide: true,
        cue: 'Slowly turn toward a shoulder, only as far as comfy.',
        easier: 'Smaller turn.',
        isCooldown: true,
        caution: _stretchCaution,
      ),
    ],
  ),

  // ── R4 · desk break ──────────────────────────────────────────────
  Routine(
    id: 'desk-break',
    title: 'Desk Break',
    blurb: 'Three minutes, no sweat. On the hour, or after a meeting.',
    minutes: 3,
    difficulty: 1,
    stat: Stat.vit,
    evidenceTitle: 'Anchor habits to moments, not clocks',
    restDay: true,
    moves: [
      WorkoutMove(
        name: 'Sit-to-stand',
        kind: MoveKind.reps,
        reps: 5,
        cue: 'Stand fully tall, sit with control.',
        easier: 'Use your hands.',
        isWarmup: true,
      ),
      WorkoutMove(
        name: 'Seated hip marching',
        kind: MoveKind.reps,
        reps: 5,
        perSide: true,
        cue: 'Lift a bent knee as far as comfy, foot down controlled.',
        easier: 'Smaller lift.',
      ),
      WorkoutMove(
        name: 'Shoulder rolls',
        kind: MoveKind.reps,
        reps: 10,
        cue: 'Arms hang, roll slowly — 5 forward, 5 back.',
        easier: 'Smaller circles.',
      ),
      WorkoutMove(
        name: 'Ankle stretch',
        kind: MoveKind.reps,
        reps: 5,
        perSide: true,
        cue: 'Point your toes away, then back toward you.',
        easier: 'Seated.',
      ),
      WorkoutMove(
        name: 'Chest + neck stretch',
        kind: MoveKind.timed,
        seconds: 20,
        cue: 'Open the chest; slow neck turn each side.',
        easier: 'Less range.',
        isCooldown: true,
        caution: _stretchCaution,
      ),
    ],
  ),

  // ── R5 · level two (reached by rising past R2) ───────────────────
  Routine(
    id: 'level-two',
    title: 'Level Two',
    blurb: 'You’ve outgrown the starter — same warmth, a real stretch.',
    minutes: 16,
    difficulty: 6,
    stat: Stat.str,
    evidenceTitle: 'Exercise snacks count',
    moves: [
      WorkoutMove(
        name: 'March + arm circles',
        kind: MoveKind.timed,
        seconds: 60,
        cue: 'Stay tall, loosen the shoulders.',
        easier: 'Slow it down.',
        isWarmup: true,
      ),
      WorkoutMove(
        name: 'Bodyweight squat',
        kind: MoveKind.reps,
        reps: 10,
        restSeconds: 30,
        cue: 'Sit back like into a chair, chest up.',
        easier: 'Chair behind you, or a mini-squat.',
        caution: _muscleCaution,
      ),
      WorkoutMove(
        name: 'Incline or knee push-up',
        kind: MoveKind.reps,
        reps: 8,
        restSeconds: 30,
        cue: 'Hands on a counter or knees on the floor, straight line.',
        easier: 'Back to a wall push-up.',
        caution: _muscleCaution,
      ),
      WorkoutMove(
        name: 'Reverse lunge',
        kind: MoveKind.reps,
        reps: 5,
        perSide: true,
        restSeconds: 30,
        cue: 'Step back, lower the back knee, push up through the front heel.',
        easier: 'Hold a chair, shorter step.',
        caution: _muscleCaution,
      ),
      WorkoutMove(
        name: 'Plank',
        kind: MoveKind.timed,
        seconds: 25,
        restSeconds: 30,
        cue: 'Forearms and toes, straight line, breathe.',
        easier: 'Knees down.',
        caution: _muscleCaution,
      ),
      WorkoutMove(
        name: 'Glute bridge',
        kind: MoveKind.reps,
        reps: 8,
        restSeconds: 30,
        cue: 'On your back, drive hips up, squeeze, lower slowly.',
        easier: 'No hold at the top.',
        caution: _muscleCaution,
      ),
      WorkoutMove(
        name: 'Slow calf raises',
        kind: MoveKind.reps,
        reps: 12,
        restSeconds: 30,
        cue: 'Tall onto the toes, three-second lower.',
        easier: 'Both feet supported.',
      ),
      WorkoutMove(
        name: 'Standing stretch flow',
        kind: MoveKind.timed,
        seconds: 30,
        cue: 'Hold each one gently, no bouncing.',
        easier: 'Less range.',
        isCooldown: true,
        caution: _stretchCaution,
      ),
    ],
  ),

  // ── R6 · the universal bad-day fallback ──────────────────────────
  Routine(
    id: 'two-minute',
    title: 'Two-Minute Win',
    blurb: 'Wiped? Do this. One warm-up, one move, one breath. Still counts.',
    minutes: 2,
    difficulty: 1,
    stat: Stat.str,
    evidenceTitle: 'Start absurdly small',
    moves: [
      WorkoutMove(
        name: 'March on the spot',
        kind: MoveKind.timed,
        seconds: 30,
        cue: 'Loosen up, fists soft.',
        easier: 'Seated march.',
        isWarmup: true,
      ),
      WorkoutMove(
        name: 'Wall push-ups',
        kind: MoveKind.reps,
        reps: 5,
        cue: 'Hands on the wall, body straight, bend the elbows.',
        easier: 'Stand closer to the wall.',
        caution: _muscleCaution,
      ),
      WorkoutMove(
        name: 'Box breathing',
        kind: MoveKind.timed,
        seconds: 30,
        cue: 'In for 4, hold 4, out for 4.',
        easier: 'Just breathe slowly.',
        isCooldown: true,
      ),
    ],
  ),
];

Routine? routineById(String id) {
  for (final r in routines) {
    if (r.id == id) return r;
  }
  return null;
}

/// The routine recommended for a launcher quest at [rung] on its ladder
/// (Wake-Up Snack → Beginner Full Body → Level Two).
Routine recommendedForRung(int rung) {
  const ids = ['wake-up', 'full-body', 'level-two'];
  return routineById(ids[rung.clamp(0, ids.length - 1)]) ?? routines.first;
}

/// The board quest that opens the guided-workout runner. Shared by the
/// default board and the Goals discovery card so it's defined once.
Quest workoutLauncherQuest() => Quest(
      title: 'Guided workout session',
      stat: Stat.str,
      difficulty: 3,
      rising: true,
      workout: true,
      ladder: Ladders.byBaseTitle['Guided workout session'],
      ladderHint: 'GUIDED · BEGINNER-FRIENDLY',
    );
