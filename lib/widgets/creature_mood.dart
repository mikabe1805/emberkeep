import '../engine.dart';
import 'portrait.dart';

/// One place that decides whether the companion is beaming or resting, so the
/// creature feels the same across every screen instead of each call site
/// inventing its own rule. Happy when there's a reason to be — a live streak,
/// or a caller-supplied beat like a just-completed quest — otherwise the calm
/// idle. (Previously Me used streakDays>0, Quests a post-completion flag, the
/// shop was always happy, visits always happy — the same creature, four moods.)
PortraitMood moodFor(GameState state, {bool beaming = false}) =>
    (beaming || state.streakDays > 0) ? PortraitMood.happy : PortraitMood.idle;
