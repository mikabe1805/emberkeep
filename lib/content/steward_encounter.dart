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
        'The cook has started putting instructions in my supper.\n\n'
        'Tonight’s soup comes with a note.',
    choices: [
      StewardReply('ask', 'What’s wrong with the soup?', 'soup-problem'),
      StewardReply('tease', 'What did you do?', 'soup-complaining'),
      StewardReply('leave', 'I’ll let you get back to it.', null),
    ],
  ),
  'soup-problem': StewardLine(
    text:
        'I asked for less salt. Once.\n\n'
        'Well. Once at each meal.',
    next: 'soup-note',
  ),
  'soup-complaining': StewardLine(
    text:
        'I make observations about the soup. He counts them.\n\n'
        'Apparently we’re at seven this week. Mostly salt.',
    next: 'soup-note',
  ),
  'soup-note': StewardLine(
    speaker: 'THE COOK’S NOTE',
    text: 'Less salt.\nYes, I remembered the bread.\nEat it while it’s hot.',
    aside: 'He turns the note so you can read it.',
    expression: GoalStewardExpression.ready,
    next: 'soup-friends',
  ),
  'soup-friends': StewardLine(
    text:
        'Twelve years he’s been cooking for me. '
        'And now he thinks he can tell me when to eat.',
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
        'He has a key to the workshop. I have a chair in his kitchen.\n\n'
        'I’m still not withdrawing the complaint.',
    expression: GoalStewardExpression.acknowledging,
    next: 'soup-bread',
  ),
  'soup-agreement': StewardLine(
    text:
        'Thank you. I was beginning to worry '
        'everyone else had something wrong with their tongue.',
    expression: GoalStewardExpression.acknowledging,
    next: 'soup-bread',
  ),
  'soup-cook-side': StewardLine(
    text:
        'Already? You haven’t even tried the soup.\n\n'
        'He’d like you. I find that slightly concerning.',
    expression: GoalStewardExpression.acknowledging,
    next: 'soup-bread',
  ),
  'soup-bread': StewardLine(
    text:
        'He saves the crusty end of the loaf for me. Best part.\n\n'
        'Claims nobody else wants it.',
    expression: GoalStewardExpression.acknowledging,
    choices: [
      StewardReply(
        'tell',
        'You should tell him you like his bread.',
        'soup-tell-him',
      ),
      StewardReply('knows', 'I think he knows.', 'soup-he-knows'),
    ],
  ),
  'soup-tell-him': StewardLine(
    text:
        'I did. Once.\n\n'
        'He started baking an extra loaf. You see what encouragement does.',
    expression: GoalStewardExpression.acknowledging,
    next: 'soup-goodbye',
  ),
  'soup-he-knows': StewardLine(
    text:
        'Unfortunately. That’s why he thinks '
        'he can get away with the soup.',
    expression: GoalStewardExpression.acknowledging,
    next: 'soup-goodbye',
  ),
  'soup-goodbye': StewardLine(
    text: 'Take a piece. Before I decide I’m hungry enough for both.',
    aside: 'He slides the plate toward your chair.',
    expression: GoalStewardExpression.closing,
    finishes: true,
  ),
};

/// Revisit reflects the actual reply without inventing events between visits.
StewardLine stewardReturnLine(StewardMemory memory) => StewardLine(
  text: switch (memory.choices[stewardChoiceMemoryKey]) {
    'friends' =>
      'He has a key. I have a chair. '
          'We don’t need to agree about the soup.',
    'agree' =>
      'At least you understand about the salt.\n\n'
          'Take a seat. He’s left enough bread for two.',
    'cook' =>
      'Still taking the cook’s side?\n\n'
          'Fine. You can have some bread anyway.',
    _ => 'Got a minute? I was just reading a note from the cook.',
  },
  expression: GoalStewardExpression.acknowledging,
);
