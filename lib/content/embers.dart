import '../models.dart';
import '../tokens.dart';

/// "Ember of the Day" — a small, fun, today-only bonus quest offered once each
/// day, drawn from a different life domain in rotation (round-38: content must
/// renew — habit timescales outlast hand-authored content, so a little daily
/// procedural variety keeps the board fresh). Light by design: a tiny extra
/// win, never a new obligation (it expires at dawn via the bonus plumbing).
const emberPool = <Stat, List<String>>{
  Stat.str: [
    'Twenty jumping jacks',
    'Hold a plank for thirty seconds',
    'Take the stairs today',
    'Dance to one whole song',
  ],
  Stat.vit: [
    'Drink an extra glass of water',
    'Step outside for fresh air',
    'Eat a piece of fruit',
    'Five slow, deep breaths',
  ],
  Stat.intl: [
    'Read something new for five minutes',
    'Look up a word you don’t know',
    'Write down one idea',
    'Learn one small fact',
  ],
  Stat.foc: [
    'A fifteen-minute focus sprint',
    'Clear your desktop',
    'Finish one lingering small task',
    'Pick tomorrow’s top three',
  ],
  Stat.soc: [
    'Send someone a kind message',
    'Reply to that text you’ve been putting off',
    'Share something that made you smile',
    'Thank someone today',
  ],
  Stat.dis: [
    'Clear one surface',
    'Throw out five things',
    'Wipe down a counter',
    'Put away what’s out of place',
  ],
};

/// The ember for [day] — deterministic from the date so it's stable across
/// rebuilds but fresh each day, rotating the domain.
({Stat stat, String title}) emberOfDay(DateTime day) {
  final seed = Days.key(day).codeUnits.fold<int>(0, (a, c) => a + c);
  final stat = Stat.values[seed % Stat.values.length];
  final pool = emberPool[stat]!;
  final title = pool[(seed ~/ Stat.values.length) % pool.length];
  return (stat: stat, title: title);
}
