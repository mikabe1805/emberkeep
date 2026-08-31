import '../steward_memory.dart';
import '../widgets/goal_steward.dart';

/// One authored, optional scene. Identifiers are save data: keep them stable.
class StewardLine {
  const StewardLine({
    required this.text,
    this.speaker = 'STEWARD',
    this.expression = GoalStewardExpression.considering,
    this.next,
    this.choices = const [],
    this.aside,
    this.finishes = false,
  });

  final String text;
  final String speaker;
  final GoalStewardExpression expression;
  final String? next;
  final List<StewardReply> choices;
  final String? aside;
  final bool finishes;
}

class StewardReply {
  const StewardReply(this.id, this.text, this.next, {this.memoryKey});

  final String id;
  final String text;

  /// Null means leave without consuming this line; it can be resumed later.
  final String? next;
  final String? memoryKey;
}

const stewardFirstLine = 'soup-hello';
const stewardChoiceMemoryKey = 'soup-note';

/// The first line establishes who wrote the note and why it matters before
/// asking the player to respond. No workshop terminology is needed to follow it.
const stewardEncounter = <String, StewardLine>{
  'soup-hello': StewardLine(
    text:
        'I was just reading a note from the cook downstairs. '
        'Apparently I complain too much about the soup.',
    choices: [
      StewardReply('ask', 'What’s wrong with the soup?', 'soup-problem'),
      StewardReply('tease', 'Do you complain a lot?', 'soup-complaining'),
      StewardReply('leave', 'I’ll let you get back to it.', null),
    ],
  ),
  'soup-problem': StewardLine(
    text:
        'Too much salt. I asked him to use less. '
        'Now he sends notes with my dinner.',
    next: 'soup-note',
  ),
  'soup-complaining': StewardLine(
    text:
        'According to him. I asked for less salt, '
        'and now every dinner comes with a comment.',
    next: 'soup-note',
  ),
  'soup-note': StewardLine(
    speaker: 'THE COOK’S NOTE',
    text: 'Less salt today.\nTry it before you complain.',
    aside: 'He holds out the note.',
    expression: GoalStewardExpression.ready,
    next: 'soup-friends',
  ),
  'soup-friends': StewardLine(
    text: 'I’ve known him for years. He’s been teasing me about it all week.',
    expression: GoalStewardExpression.ready,
    choices: [
      StewardReply(
        'friends',
        'You two sound like friends.',
        'soup-friendship',
        memoryKey: stewardChoiceMemoryKey,
      ),
      StewardReply(
        'agree',
        'I’d complain about salty soup too.',
        'soup-agreement',
        memoryKey: stewardChoiceMemoryKey,
      ),
      StewardReply(
        'cook',
        'I’m on his side.',
        'soup-cook-side',
        memoryKey: stewardChoiceMemoryKey,
      ),
    ],
  ),
  'soup-friendship': StewardLine(
    text:
        'We are. I eat there most evenings. '
        'He saves me a seat when it’s busy.',
    expression: GoalStewardExpression.acknowledging,
    next: 'soup-bread',
  ),
  'soup-agreement': StewardLine(
    text: 'Thank you. I was starting to think it was just me.',
    expression: GoalStewardExpression.acknowledging,
    next: 'soup-bread',
  ),
  'soup-cook-side': StewardLine(
    text: 'You haven’t even tried the soup.\n\nHe’d like you.',
    expression: GoalStewardExpression.acknowledging,
    next: 'soup-bread',
  ),
  'soup-bread': StewardLine(
    text:
        'His bread is good, though. He always saves me the end of the loaf. '
        'He knows that’s my favorite part.',
    expression: GoalStewardExpression.acknowledging,
    choices: [
      StewardReply('tell', 'You should tell him you like it.', 'soup-tell-him'),
      StewardReply('knows', 'I think he knows.', 'soup-he-knows'),
    ],
  ),
  'soup-tell-him': StewardLine(
    text: 'I tell him. But I probably talk about the soup more.',
    expression: GoalStewardExpression.acknowledging,
    next: 'soup-goodbye',
  ),
  'soup-he-knows': StewardLine(
    text: 'I hope so. I’m in there often enough.',
    expression: GoalStewardExpression.acknowledging,
    next: 'soup-goodbye',
  ),
  'soup-goodbye': StewardLine(
    text: 'Now I’m hungry. I hope he’s saved me some bread.',
    aside: 'He puts the note in the wooden box beside him.',
    expression: GoalStewardExpression.closing,
    finishes: true,
  ),
};

/// Revisit reflects the actual reply without inventing events between visits.
StewardLine stewardReturnLine(StewardMemory memory) => StewardLine(
  text: switch (memory.choices[stewardChoiceMemoryKey]) {
    'friends' =>
      'You were right about the cook. He’s a friend. '
          'I’d still like him to use less salt.',
    'agree' =>
      'Good to know someone else would complain about that soup. '
          'I was beginning to feel very fussy.',
    'cook' =>
      'Still taking the cook’s side? Fair enough. '
          'I think you’d get along.',
    _ => 'Got a minute? I was just reading a note from the cook.',
  },
  expression: GoalStewardExpression.acknowledging,
);
