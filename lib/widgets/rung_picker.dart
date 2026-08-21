import 'package:flutter/material.dart';

import '../audio.dart';
import '../tokens.dart';
import 'facets.dart';
import 'glass.dart';
import 'honey_button.dart';

/// Asks where on its ladder a newly adopted quest should start — the "how
/// many push-ups feel doable today?" moment, at the moment it matters.
/// Returns the chosen rung index, or null if dismissed (→ don't adopt).
/// Defaults to [initial], the template's authored rung, so accepting the
/// suggested floor stays one tap.
Future<int?> pickRung(
  BuildContext context, {
  required Color accent,
  required String questTitle,
  required List<String> ladder,
  int initial = 0,
}) {
  return showModalBottomSheet<int>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _RungSheet(
      accent: accent,
      questTitle: questTitle,
      ladder: ladder,
      initial: initial.clamp(0, ladder.length - 1),
    ),
  );
}

class _RungSheet extends StatefulWidget {
  const _RungSheet({
    required this.accent,
    required this.questTitle,
    required this.ladder,
    required this.initial,
  });
  final Color accent;
  final String questTitle;
  final List<String> ladder;
  final int initial;

  @override
  State<_RungSheet> createState() => _RungSheetState();
}

class _RungSheetState extends State<_RungSheet> {
  late int _sel = widget.initial;

  void _choose(int rung) {
    Sfx.instance.playMaterial(MaterialSound.glass);
    setState(() => _sel = rung);
  }

  @override
  Widget build(BuildContext context) {
    // Scroll guard: five rung chips at accessibility text scales outgrow a
    // small phone, and a consent-adjacent sheet must never clip its button.
    final maxHeight = MediaQuery.sizeOf(context).height * 0.85;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: GlassPanel(
            tint: const Color(0xF22A211D),
            padding: EdgeInsets.zero,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'WHERE ARE YOU STARTING?',
                    style: Type.label.copyWith(
                      fontSize: 12,
                      color: widget.accent,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    widget.questTitle,
                    style: Type.display.copyWith(fontSize: 18),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Every rung is a real start — pick the one that feels doable '
                    'today. It climbs from wherever you begin.',
                    style: Type.body.copyWith(
                      fontSize: 12.5,
                      height: 1.4,
                      color: Palette.textLo,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (var i = 0; i < widget.ladder.length; i++)
                        Semantics(
                          button: true,
                          selected: _sel == i,
                          label: widget.ladder[i],
                          onTap: () => _choose(i),
                          child: GestureDetector(
                            key: ValueKey('pick-rung-$i'),
                            excludeFromSemantics: true,
                            behavior: HitTestBehavior.opaque,
                            onTap: () => _choose(i),
                            child: Container(
                              constraints: const BoxConstraints(minHeight: 44),
                              alignment: Alignment.center,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 9,
                              ),
                              decoration: facetedDecoration(
                                cut: 8,
                                color: _sel == i
                                    ? widget.accent.withValues(alpha: 0.28)
                                    : Palette.glassFill,
                                borderColor: _sel == i
                                    ? widget.accent
                                    : Palette.glassEdge,
                                borderWidth: _sel == i ? 1.6 : 1.0,
                              ),
                              child: Text(
                                widget.ladder[i],
                                style: Type.label.copyWith(
                                  fontSize: 11,
                                  color: _sel == i
                                      ? widget.accent
                                      : Palette.textLo,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  HoneyButton(
                    label: 'START HERE',
                    expand: true,
                    onTap: () {
                      Navigator.of(context).pop(_sel);
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
