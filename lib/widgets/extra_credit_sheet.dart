import 'package:flutter/material.dart';

import '../engine.dart';
import '../models.dart';
import '../tokens.dart';
import 'facets.dart';
import 'glass.dart';
import 'honey_button.dart';

/// A single private acknowledgment, not a Quest editor. The caller commits
/// synchronously and can return an error without throwing away the writing
/// (for example, when a new ledger day starts while this sheet is open).
///
/// It opens on the nearest navigator: inside the night ledger that is the
/// ledger's own, so the sheet sits above the folio and back closes it first.
Future<bool?> showExtraCreditSheet(
  BuildContext context, {
  String? initial,
  required String? Function(String title) onKeep,
  bool reduceMotion = false,
}) => showGeneralDialog<bool>(
  context: context,
  useRootNavigator: false,
  barrierDismissible: true,
  barrierLabel: 'Not now',
  barrierColor: const Color(0xD10B0705),
  transitionDuration: reduceMotion
      ? Duration.zero
      : const Duration(milliseconds: 200),
  pageBuilder: (context, animation, secondaryAnimation) => Material(
    type: MaterialType.transparency,
    child: SafeArea(
      child: _ExtraCreditSheet(
        initial: initial,
        onKeep: onKeep,
        reduceMotion: reduceMotion,
      ),
    ),
  ),
  transitionBuilder: (context, animation, secondaryAnimation, child) =>
      reduceMotion
      ? child
      : FadeTransition(
          opacity: CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          ),
          child: child,
        ),
);

class _ExtraCreditSheet extends StatefulWidget {
  const _ExtraCreditSheet({
    required this.initial,
    required this.onKeep,
    required this.reduceMotion,
  });

  final String? initial;
  final String? Function(String title) onKeep;
  final bool reduceMotion;

  @override
  State<_ExtraCreditSheet> createState() => _ExtraCreditSheetState();
}

class _ExtraCreditSheetState extends State<_ExtraCreditSheet> {
  late final TextEditingController _words = TextEditingController(
    text: widget.initial ?? '',
  )..addListener(_changed);
  bool _saving = false;
  String? _error;

  bool get _editing => widget.initial != null;

  void _changed() => setState(() => _error = null);

  void _keep() {
    if (_saving || _words.text.trim().isEmpty) return;
    setState(() => _saving = true);
    final error = widget.onKeep(_words.text);
    if (!mounted) return;
    if (error != null) {
      setState(() {
        _saving = false;
        _error = error;
      });
      return;
    }
    Navigator.of(context).pop(true);
  }

  @override
  void dispose() {
    _words
      ..removeListener(_changed)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final still = widget.reduceMotion || media.disableAnimations;
    return AnimatedPadding(
      duration: still ? Duration.zero : const Duration(milliseconds: 160),
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + media.viewInsets.bottom),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          // The same candlelit glass and brass-edged writing field as the
          // night reflection: both are writing kept inside the ledger.
          child: GlassPanel(
            key: const Key('extra-credit-sheet'),
            radius: 18,
            tint: const Color(0xFD211813),
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
            child: SingleChildScrollView(
              key: const Key('extra-credit-scroll'),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'EXTRA CREDIT',
                          style: Type.label.copyWith(
                            color: Palette.xpLight,
                            fontSize: Type.minLabel,
                            letterSpacing: 1.4,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Not now',
                        onPressed: () => Navigator.of(context).pop(),
                        constraints: const BoxConstraints(
                          minWidth: 44,
                          minHeight: 44,
                        ),
                        icon: const Icon(
                          Icons.close_rounded,
                          color: Palette.textMid,
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    _editing
                        ? 'That counted, too.'
                        : 'What else counted today?',
                    style: Type.display.copyWith(fontSize: 26, height: 1.12),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _editing
                        ? 'Your +${GameState.extraCreditXp} XP is already kept. Editing the words won’t add more XP.'
                        : 'A real win that wasn’t on your Quest board.',
                    style: Type.body.copyWith(
                      fontSize: 14,
                      height: 1.45,
                      color: Palette.textMid,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Container(
                    decoration: facetedDecoration(
                      cut: 9,
                      color: const Color(0xFF15100D),
                      borderColor: Palette.brass.withValues(alpha: 0.50),
                    ),
                    child: TextField(
                      key: const Key('extra-credit-field'),
                      controller: _words,
                      autofocus: true,
                      minLines: 2,
                      maxLines: 4,
                      maxLength: ExtraCreditEntry.maxTitleLength,
                      textCapitalization: TextCapitalization.sentences,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _keep(),
                      style: Type.body.copyWith(
                        color: Palette.textHi,
                        fontSize: 16,
                        height: 1.45,
                      ),
                      cursorColor: Palette.xpLight,
                      decoration: InputDecoration(
                        labelText: 'What you did',
                        // Mika's own words for the idea, kept as the example.
                        hintText: 'I went to all my classes',
                        hintStyle: Type.body.copyWith(
                          fontSize: 16,
                          color: Palette.textLo,
                        ),
                        labelStyle: Type.body.copyWith(
                          fontSize: 13,
                          color: Palette.textMid,
                        ),
                        floatingLabelStyle: Type.body.copyWith(
                          fontSize: 13,
                          color: Palette.xpLight,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.fromLTRB(
                          12,
                          10,
                          12,
                          7,
                        ),
                        counterStyle: Type.label.copyWith(
                          fontSize: Type.minLabel,
                          color: Palette.textLo,
                        ),
                      ),
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 8),
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        _error!,
                        style: Type.body.copyWith(
                          fontSize: 13,
                          height: 1.4,
                          color: Palette.textHi,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  HoneyButton(
                    key: const Key('extra-credit-save'),
                    label: _editing
                        ? 'SAVE WORDING'
                        : 'ADD +${GameState.extraCreditXp} XP',
                    onTap: _keep,
                    enabled: !_saving && _words.text.trim().isNotEmpty,
                    expand: true,
                    icon: _editing ? Icons.check_rounded : Icons.add_rounded,
                  ),
                  if (!_editing) ...[
                    const SizedBox(height: 12),
                    Text(
                      'One little bonus for the day. No Quest needed.',
                      textAlign: TextAlign.center,
                      style: Type.body.copyWith(
                        fontSize: 12,
                        height: 1.4,
                        color: Palette.textMid,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
