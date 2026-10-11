// The reading nook's own glass: the "Write for today" card with its four ways
// in, the last two entries, and the label on the painted box that opens
// Keepsakes. The painted room (the plate) is HouseRoomBackdrop's; the page
// that stacks these over it is journal_nook_page.dart.
//
// Everything here is plain widgets over plain data, so the Journal tab, a test
// and a render can all build it from a GameState. Opening the writing view is
// the caller's job (see JournalWriter); nothing here writes or saves.
library;

import 'package:flutter/material.dart';

import '../../../audio.dart';
import '../../../engine.dart';
import '../../../models.dart';
import '../../../tokens.dart';
import '../../glass.dart';
import '../../pressable.dart';

const _months = [
  'JAN',
  'FEB',
  'MAR',
  'APR',
  'MAY',
  'JUN',
  'JUL',
  'AUG',
  'SEP',
  'OCT',
  'NOV',
  'DEC',
];
const _weekdays = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];

/// `TUE · OCT 6`, the nook's way of dating a page.
String journalDateLabel(DateTime d) =>
    '${_weekdays[d.weekday - 1]} · ${_months[d.month - 1]} ${d.day}';

/// One way into a blank page: its name on the chip, and what the writing view
/// opens with.
class JournalPrompt {
  const JournalPrompt({
    required this.id,
    required this.label,
    required this.hint,
    required this.starter,
  });

  /// Stable name for tests and keys.
  final String id;

  /// What the chip says, and the heading of the writing view.
  final String label;

  /// The writing view's hint line.
  final String hint;

  /// The first line already on the page.
  final String starter;
}

/// The four ways in, in the order the nook shows them. "After the quest" names
/// today's last quest when there is one.
List<JournalPrompt> journalNookPrompts(GameState state) {
  final quests = state.todayQuestTitles;
  return [
    JournalPrompt(
      id: 'after-the-quest',
      label: 'After the quest',
      hint: 'What made it easier, harder, or worth repeating?',
      starter: quests.isEmpty
          ? 'After the quest:\n'
          : 'After “${quests.last}”:\n',
    ),
    const JournalPrompt(
      id: 'a-small-win',
      label: 'A small win',
      hint: 'Start with something that counted, even if nobody saw it.',
      starter: 'One small win today:\n',
    ),
    const JournalPrompt(
      id: 'set-it-down',
      label: 'Set it down',
      hint: 'Name what felt heavy. You do not need to solve it here.',
      starter: 'What felt heavy:\n',
    ),
    const JournalPrompt(
      id: 'a-warm-detail',
      label: 'A warm detail',
      hint: 'Hold onto one person, place, or moment you are grateful for.',
      starter: 'Something I’m grateful for:\n',
    ),
  ];
}

/// The last [count] free journal entries, newest first.
List<Note> recentJournalEntries(GameState state, {int count = 2}) {
  final entries = [...state.journal]..sort((a, b) => b.at.compareTo(a.at));
  return entries.take(count).toList();
}

/// What an entry's row says: its first line, or a quiet name for a photo page.
String journalEntryTitle(Note note) {
  for (final line in note.text.split('\n')) {
    final trimmed = line.trim();
    if (trimmed.isNotEmpty) return trimmed;
  }
  return note.images.isNotEmpty ? 'Photo entry' : 'A page kept';
}

TextStyle _serif(double size, Color color, {FontWeight? weight}) => TextStyle(
  fontFamily: 'EBGaramond',
  fontSize: size,
  fontWeight: weight ?? FontWeight.w500,
  height: 1.15,
  color: color,
);

/// The least a touch target is tall: every chip, row and button in the nook.
const double _hit = 44;

const _ink = Color(0xFFEFE2CB);
const _inkSoft = Color(0xFFC6B69C);

/// The "Write for today" glass card.
class JournalNookCard extends StatelessWidget {
  const JournalNookCard({
    super.key,
    required this.date,
    required this.prompts,
    required this.recent,
    required this.onWrite,
    required this.onPrompt,
    required this.onEntry,
    required this.onAllEntries,
  });

  final DateTime date;
  final List<JournalPrompt> prompts;

  /// The last entries, newest first; none shows the first-page state.
  final List<Note> recent;

  /// "Write for today": a blank page.
  final VoidCallback onWrite;
  final ValueChanged<JournalPrompt> onPrompt;
  final ValueChanged<Note> onEntry;

  /// "All": the Journal hub, every note in one place.
  final VoidCallback onAllEntries;

  @override
  Widget build(BuildContext context) {
    final label = journalDateLabel(date);
    return GlassPanel(
      blur: true,
      tint: const Color(0xCC3A2A1E),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
      child: Column(
        key: const ValueKey('journal-nook-card'),
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Pressable(
            semanticLabel: 'Write for today',
            semanticHint: 'Opens a blank page',
            pressDepth: 1.5,
            edgeColor: Colors.transparent,
            material: MaterialSound.parchment,
            interactionSound: InteractionSound.open,
            onTapUp: (_) => onWrite(),
            child: ExcludeSemantics(
              child: ConstrainedBox(
                key: const ValueKey('journal-nook-write'),
                constraints: const BoxConstraints(minHeight: _hit),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Row(
                    children: [
                      // The date sits over the title inside the same 44 pt
                      // target, so the card keeps the prototype's order
                      // without a row of its own for it.
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              label,
                              key: const ValueKey('journal-nook-date'),
                              style: Type.label.copyWith(
                                color: _inkSoft,
                                letterSpacing: 1.8,
                                height: 1.1,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              'Write for today',
                              style: _serif(
                                28,
                                const Color(0xFFFFF3DE),
                              ).copyWith(height: 1.0),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.edit_outlined,
                        size: 19,
                        color: Palette.xpLight.withValues(alpha: 0.8),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          _PromptGrid(prompts: prompts, onPrompt: onPrompt),
          const SizedBox(height: 4),
          Container(height: 1, color: const Color(0x24E8C892)),
          if (recent.isEmpty)
            const _FirstPage()
          else
            _Recent(
              entries: recent,
              onEntry: onEntry,
              onAllEntries: onAllEntries,
            ),
        ],
      ),
    );
  }
}

/// The four chips, two to a row, equal in height whatever the text size.
class _PromptGrid extends StatelessWidget {
  const _PromptGrid({required this.prompts, required this.onPrompt});

  final List<JournalPrompt> prompts;
  final ValueChanged<JournalPrompt> onPrompt;

  @override
  Widget build(BuildContext context) {
    Widget chip(JournalPrompt p) => Expanded(
      child: _PromptChip(prompt: p, onTap: () => onPrompt(p)),
    );
    final rows = <Widget>[];
    for (var i = 0; i < prompts.length; i += 2) {
      // The chips' hit areas meet: each is 44 pt tall (the pill inside is 32),
      // so the rows carry no gap of their own.
      rows.add(
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              chip(prompts[i]),
              const SizedBox(width: 6),
              if (i + 1 < prompts.length)
                chip(prompts[i + 1])
              else
                const Expanded(child: SizedBox.shrink()),
            ],
          ),
        ),
      );
    }
    return Column(
      key: const ValueKey('journal-nook-prompts'),
      mainAxisSize: MainAxisSize.min,
      children: rows,
    );
  }
}

class _PromptChip extends StatelessWidget {
  const _PromptChip({required this.prompt, required this.onTap});

  final JournalPrompt prompt;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      semanticLabel: 'Start journal prompt: ${prompt.label}',
      semanticHint: prompt.hint,
      pressDepth: 1.5,
      edgeColor: Colors.transparent,
      material: MaterialSound.parchment,
      interactionSound: InteractionSound.open,
      onTapUp: (_) => onTap(),
      child: ExcludeSemantics(
        child: ConstrainedBox(
          key: ValueKey('journal-nook-chip-hit-${prompt.id}'),
          constraints: const BoxConstraints(minHeight: _hit),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Container(
              key: ValueKey('journal-nook-chip-${prompt.id}'),
              constraints: const BoxConstraints(minHeight: 32),
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0x470D0A08),
                borderRadius: BorderRadius.circular(17),
                border: Border.all(color: const Color(0x3DEFD8B3)),
              ),
              child: Text(
                prompt.label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: _serif(15, const Color(0xFFE8DAC6)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Recent extends StatelessWidget {
  const _Recent({
    required this.entries,
    required this.onEntry,
    required this.onAllEntries,
  });

  final List<Note> entries;
  final ValueChanged<Note> onEntry;
  final VoidCallback onAllEntries;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const ValueKey('journal-nook-recent'),
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: Semantics(
                header: true,
                child: Text(
                  'RECENT ENTRIES',
                  style: Type.label.copyWith(
                    color: _inkSoft,
                    letterSpacing: 1.8,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
            Pressable(
              semanticLabel: 'All journal entries',
              pressDepth: 1.5,
              edgeColor: Colors.transparent,
              material: MaterialSound.parchment,
              interactionSound: InteractionSound.open,
              onTapUp: (_) => onAllEntries(),
              child: ExcludeSemantics(
                child: ConstrainedBox(
                  key: const ValueKey('journal-nook-all'),
                  constraints: const BoxConstraints(
                    minHeight: _hit,
                    minWidth: _hit,
                  ),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 12),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'ALL',
                            style: Type.label.copyWith(
                              color: Palette.xpLight.withValues(alpha: 0.85),
                              letterSpacing: 1.4,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Icon(
                            Icons.chevron_right,
                            size: 16,
                            color: Palette.xpLight.withValues(alpha: 0.85),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        for (var i = 0; i < entries.length; i++)
          _EntryRow(
            note: entries[i],
            last: i == entries.length - 1,
            onTap: () => onEntry(entries[i]),
          ),
      ],
    );
  }
}

class _EntryRow extends StatelessWidget {
  const _EntryRow({
    required this.note,
    required this.last,
    required this.onTap,
  });

  final Note note;
  final bool last;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final date = journalDateLabel(note.at);
    final title = journalEntryTitle(note);
    final scale = MediaQuery.textScalerOf(context).scale(1);
    // Past a large text size the date no longer shares a line with the title.
    final stacked = scale > 1.5;
    final dateText = Text(
      date,
      style: Type.label.copyWith(
        color: _inkSoft,
        letterSpacing: 0.9,
        fontWeight: FontWeight.w500,
      ),
    );
    final titleText = Text(
      title,
      maxLines: stacked ? 2 : 1,
      overflow: TextOverflow.ellipsis,
      style: _serif(16.5, _ink),
    );
    return Pressable(
      semanticLabel: 'Read journal entry from $date: $title',
      pressDepth: 1.5,
      edgeColor: Colors.transparent,
      material: MaterialSound.parchment,
      interactionSound: InteractionSound.open,
      onTapUp: (_) => onTap(),
      child: ExcludeSemantics(
        child: Container(
          key: ValueKey('journal-nook-entry-${note.id}'),
          constraints: const BoxConstraints(minHeight: _hit),
          alignment: Alignment.centerLeft,
          padding: EdgeInsets.symmetric(vertical: stacked ? 7 : 2),
          decoration: BoxDecoration(
            border: last
                ? null
                : const Border(bottom: BorderSide(color: Color(0x1AE8C892))),
          ),
          child: Row(
            children: [
              Expanded(
                child: stacked
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          dateText,
                          const SizedBox(height: 3),
                          titleText,
                        ],
                      )
                    : Row(
                        children: [
                          SizedBox(
                            width: 104 * scale.clamp(1.0, 1.5),
                            child: dateText,
                          ),
                          Expanded(child: titleText),
                        ],
                      ),
              ),
              const SizedBox(width: 6),
              const Icon(Icons.chevron_right, size: 16, color: Palette.textLo),
            ],
          ),
        ),
      ),
    );
  }
}

/// No entry yet: the page waits, with nothing to do but start.
class _FirstPage extends StatelessWidget {
  const _FirstPage();

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: const ValueKey('journal-nook-empty'),
      padding: const EdgeInsets.only(bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your first page is ready',
            style: Type.display.copyWith(
              fontSize: 19,
              fontWeight: FontWeight.w500,
              color: _ink,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'Choose a way in above, or just start. The date and today’s quests '
            'are kept with it.',
            style: _serif(15, _inkSoft).copyWith(height: 1.3),
          ),
        ],
      ),
    );
  }
}

/// The label on the painted box. It points at the box with a hairline and a
/// dot, and opens Keepsakes.
class JournalKeepsakesTag extends StatelessWidget {
  const JournalKeepsakesTag({super.key, required this.onTap});

  final VoidCallback onTap;

  /// Hairline and dot, to the left of the label (the plate's pointer).
  static const leaderWidth = 22.0;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(
          width: leaderWidth,
          height: 6,
          child: CustomPaint(painter: _LeaderPainter()),
        ),
        Pressable(
          semanticLabel: 'Keepsakes',
          semanticHint: 'Opens your memory cabinet',
          pressDepth: 1.5,
          edgeColor: Colors.transparent,
          material: MaterialSound.parchment,
          interactionSound: InteractionSound.open,
          onTapUp: (_) => onTap(),
          child: ExcludeSemantics(
            child: Padding(
              // 28 pt of label inside a 44 pt target.
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Container(
                key: const ValueKey('journal-keepsakes-tag'),
                constraints: const BoxConstraints(minHeight: 28, minWidth: 83),
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xC71A130F),
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: const Color(0x47FFF0D7)),
                ),
                child: Text(
                  'KEEPSAKES',
                  maxLines: 1,
                  style: Type.label.copyWith(
                    color: const Color(0xFFF0E3CD),
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _LeaderPainter extends CustomPainter {
  const _LeaderPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height / 2;
    final line = Paint()
      ..color = const Color(0x8CFFF0D7)
      ..strokeWidth = 1;
    canvas.drawLine(Offset(3, y), Offset(size.width, y), line);
    canvas.drawCircle(
      Offset(3, y),
      2.4,
      Paint()..color = const Color(0xCCFFF0D7),
    );
  }

  @override
  bool shouldRepaint(_LeaderPainter old) => false;
}
