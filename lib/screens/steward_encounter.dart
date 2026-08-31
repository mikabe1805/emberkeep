import 'package:flutter/material.dart';

import '../content/steward_encounter.dart';
import '../engine.dart';
import '../tokens.dart';
import '../widgets/facets.dart';
import '../widgets/goal_steward.dart';
import '../widgets/pressable.dart';

/// An optional encounter, separate from the workshop's planning actions.
class StewardEncounterScreen extends StatefulWidget {
  const StewardEncounterScreen({
    super.key,
    required this.state,
    this.onPersist,
  });

  final GameState state;
  final VoidCallback? onPersist;

  @override
  State<StewardEncounterScreen> createState() => _StewardEncounterScreenState();
}

class _StewardEncounterScreenState extends State<StewardEncounterScreen> {
  final _scroll = ScrollController();
  late String? _nodeId;
  bool _advancing = false;
  bool _cached = false;

  @override
  void initState() {
    super.initState();
    final memory = widget.state.stewardMemory;
    final saved = memory.nodeId;
    // The unpublished first draft used another story and choice key. Do not
    // drop a reader of that draft into this conversation's ending.
    if (!memory.choices.containsKey(stewardChoiceMemoryKey)) {
      memory.completed = false;
    }
    _nodeId = stewardEncounter.containsKey(saved)
        ? saved
        : memory.completed
        ? null
        : stewardFirstLine;
    memory.discovered = true;
    memory.nodeId = _nodeId;
    // Persist after navigation's build; callbacks can rebuild the parent.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onPersist?.call();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_cached) return;
    _cached = true;
    precacheGoalStewardAssets(context);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _go(String? next, {StewardReply? reply}) {
    if (_advancing) return;
    if (next == null) {
      Navigator.of(context).pop();
      return;
    }
    if (!stewardEncounter.containsKey(next)) return;
    _advancing = true;
    final memory = widget.state.stewardMemory;
    if (reply?.memoryKey case final key?) memory.choices[key] = reply!.id;
    setState(() {
      _nodeId = next;
      memory.nodeId = next;
    });
    widget.onPersist?.call();
    // A second pointer/key event against the old line cannot skip the new one.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_scroll.hasClients) _scroll.jumpTo(0);
      _advancing = false;
    });
  }

  void _finish() {
    if (_advancing) return;
    _advancing = true;
    final memory = widget.state.stewardMemory;
    memory.completed = true;
    memory.nodeId = null;
    widget.onPersist?.call();
    Navigator.of(context).pop();
  }

  void _replay() {
    if (_advancing) return;
    // Preserve the last completed choice until a new one is actually made.
    _go(stewardFirstLine);
  }

  @override
  Widget build(BuildContext context) {
    final line = _nodeId == null
        ? stewardReturnLine(widget.state.stewardMemory)
        : stewardEncounter[_nodeId]!;
    final still =
        widget.state.reduceMotion ||
        (MediaQuery.maybeDisableAnimationsOf(context) ?? false);
    final scale = MediaQuery.textScalerOf(context).scale(1);
    return Scaffold(
      key: const Key('steward-encounter'),
      backgroundColor: const Color(0xFF100D0B),
      body: Stack(
        fit: StackFit.expand,
        children: [
          ExcludeSemantics(
            child: GoalStewardArtwork(
              expression: line.expression,
              reduceMotion: still,
            ),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0, .36, .62, 1],
                colors: [
                  Color(0x4D100B08),
                  Color(0x00100B08),
                  Color(0x30100B08),
                  Color(0xE6100B08),
                ],
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: _SceneAction(
                      key: const Key('steward-leave'),
                      label: 'Back',
                      semanticLabel:
                          'Back to the workshop. Your place is saved.',
                      icon: Icons.arrow_back_rounded,
                      onTap: () => Navigator.of(context).pop(),
                      filled: false,
                    ),
                  ),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final compact = constraints.maxHeight < 610;
                        final maxHeight =
                            constraints.maxHeight *
                            (scale > 1.2
                                ? .78
                                : compact
                                ? .65
                                : .53);
                        return Align(
                          alignment: Alignment.bottomCenter,
                          child: ConstrainedBox(
                            constraints: BoxConstraints(maxHeight: maxHeight),
                            child: Container(
                              key: const Key('steward-dialogue-panel'),
                              decoration: facetedDecoration(
                                cut: 13,
                                gradient: const LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Color(0xFF33251C),
                                    Color(0xFF1B130F),
                                  ],
                                ),
                                borderColor: const Color(0xFFAD8053),
                                shadows: const [
                                  BoxShadow(
                                    color: Color(0x99080503),
                                    blurRadius: 22,
                                    offset: Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: RawScrollbar(
                                controller: _scroll,
                                thumbVisibility: true,
                                thumbColor: const Color(0xFFBBA580),
                                thickness: 3,
                                radius: const Radius.circular(2),
                                mainAxisMargin: 10,
                                crossAxisMargin: 6,
                                child: ClipPath(
                                  clipper: const FacetedClipper(cut: 13),
                                  child: SingleChildScrollView(
                                    key: const Key('steward-dialogue-scroll'),
                                    controller: _scroll,
                                    padding: EdgeInsets.all(compact ? 17 : 22),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        Semantics(
                                          key: const Key('steward-line'),
                                          liveRegion: true,
                                          label:
                                              '${line.speaker}. ${line.text}'
                                              '${line.aside == null ? '' : '. ${line.aside}'}',
                                          excludeSemantics: true,
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.stretch,
                                            children: [
                                              Text(
                                                line.speaker,
                                                style: Type.label.copyWith(
                                                  fontSize: 12,
                                                  letterSpacing: 1.3,
                                                  color: Palette.brassLit,
                                                ),
                                              ),
                                              const SizedBox(height: 12),
                                              Text(
                                                line.text,
                                                key: ValueKey(
                                                  'steward-text-${_nodeId ?? 'return'}',
                                                ),
                                                style: Type.body.copyWith(
                                                  fontSize: compact ? 17 : 19,
                                                  height: 1.4,
                                                  color: Palette.textHi,
                                                ),
                                              ),
                                              if (line.aside != null) ...[
                                                const SizedBox(height: 16),
                                                Text(
                                                  line.aside!,
                                                  style: Type.body.copyWith(
                                                    fontSize: 15,
                                                    height: 1.4,
                                                    color: Palette.textMid,
                                                    fontStyle: FontStyle.italic,
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: 22),
                                        if (_nodeId == null) ...[
                                          _SceneAction(
                                            key: const Key('steward-replay'),
                                            label: 'Replay this conversation',
                                            onTap: _replay,
                                          ),
                                        ] else if (line.choices.isNotEmpty)
                                          for (final reply in line.choices)
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                bottom: 8,
                                              ),
                                              child: _SceneAction(
                                                key: ValueKey(
                                                  'steward-reply-${reply.id}',
                                                ),
                                                label: reply.text,
                                                onTap: () => _go(
                                                  reply.next,
                                                  reply: reply,
                                                ),
                                              ),
                                            )
                                        else
                                          Align(
                                            alignment: Alignment.centerRight,
                                            child: _SceneAction(
                                              key: const Key(
                                                'steward-continue',
                                              ),
                                              label: line.finishes
                                                  ? 'Back to the workshop'
                                                  : 'Continue',
                                              icon: line.finishes
                                                  ? Icons.arrow_back_rounded
                                                  : Icons.arrow_forward_rounded,
                                              onTap: line.finishes
                                                  ? _finish
                                                  : () => _go(line.next),
                                              filled: false,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SceneAction extends StatelessWidget {
  const _SceneAction({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.semanticLabel,
    this.filled = true,
  });

  final String label;
  final VoidCallback onTap;
  final IconData? icon;
  final String? semanticLabel;
  final bool filled;

  @override
  Widget build(BuildContext context) => Pressable(
    onTapUp: (_) => onTap(),
    soundEnabled: false,
    semanticLabel: semanticLabel ?? label,
    guardRapidReentry: true,
    shape: const FacetedBorder(cut: 7),
    edgeColor: Colors.transparent,
    child: ExcludeSemantics(
      child: Container(
        constraints: const BoxConstraints(minHeight: 48),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: facetedDecoration(
          cut: 7,
          color: filled ? const Color(0xFF473324) : const Color(0xEB251B14),
          borderColor: filled
              ? const Color(0xFF997149)
              : const Color(0xFF72553C),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 19, color: Palette.brassLit),
              const SizedBox(width: 9),
            ],
            Flexible(
              child: Text(
                label,
                style: Type.body.copyWith(
                  fontSize: 15,
                  height: 1.25,
                  color: Palette.textHi,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
