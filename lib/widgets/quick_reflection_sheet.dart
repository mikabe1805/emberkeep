import 'package:flutter/material.dart';

import '../audio.dart';
import '../haptics.dart';
import '../tokens.dart';
import 'facets.dart';
import 'glass.dart';
import 'honey_button.dart';

/// A deliberately tiny journal door: one useful line, attached to the day,
/// without turning a completed quest or the night ritual into another form.
Future<String?> showQuickReflectionSheet(
  BuildContext context, {
  required String title,
  required String prompt,
  String? attached,
}) {
  Sfx.instance.playMaterial(MaterialSound.glass);
  Haptics.tap();
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: const Color(0xC70B0705),
    builder: (_) =>
        _QuickReflectionSheet(title: title, prompt: prompt, attached: attached),
  );
}

class _QuickReflectionSheet extends StatefulWidget {
  const _QuickReflectionSheet({
    required this.title,
    required this.prompt,
    required this.attached,
  });

  final String title;
  final String prompt;
  final String? attached;

  @override
  State<_QuickReflectionSheet> createState() => _QuickReflectionSheetState();
}

class _QuickReflectionSheetState extends State<_QuickReflectionSheet> {
  final TextEditingController _text = TextEditingController();
  final FocusNode _focus = FocusNode();
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _text.addListener(_trackReady);
  }

  void _trackReady() {
    final ready = _text.text.trim().isNotEmpty;
    if (ready != _ready) setState(() => _ready = ready);
  }

  void _keep() {
    final value = _text.text.trim();
    if (value.isEmpty) return;
    Sfx.instance.play('tick_lift');
    Haptics.success();
    Navigator.of(context).pop(value);
  }

  @override
  void dispose() {
    _text
      ..removeListener(_trackReady)
      ..dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final availableHeight = (MediaQuery.sizeOf(context).height - keyboard - 40)
        .clamp(180.0, 620.0)
        .toDouble();
    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.fromLTRB(14, 12, 14, 14 + keyboard),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 560,
            maxHeight: availableHeight,
          ),
          child: GlassPanel(
            radius: 18,
            tint: const Color(0xFC211813),
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FacetMedallion(
                        size: 38,
                        accent: Palette.xp,
                        child: const Icon(
                          Icons.history_edu_rounded,
                          size: 20,
                          color: Palette.xpLight,
                        ),
                      ),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'ONE LINE, IF YOU WANT',
                              style: Type.label.copyWith(
                                fontSize: Type.minLabel,
                                color: Palette.xpLight,
                                letterSpacing: 1.4,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              widget.title,
                              style: Type.display.copyWith(
                                fontSize: 21,
                                height: 1.08,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Semantics(
                        button: true,
                        label: 'Not now',
                        child: IconButton(
                          visualDensity: VisualDensity.compact,
                          tooltip: 'Not now',
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(
                            Icons.close_rounded,
                            color: Palette.textLo,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    widget.prompt,
                    style: Type.body.copyWith(
                      fontSize: 12.5,
                      height: 1.35,
                      color: Palette.textMid,
                    ),
                  ),
                  if (widget.attached?.trim().isNotEmpty ?? false) ...[
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      decoration: facetedDecoration(
                        cut: 7,
                        color: Palette.xp.withValues(alpha: 0.07),
                        borderColor: Palette.xp.withValues(alpha: 0.30),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.link_rounded,
                            size: 15,
                            color: Palette.xpLight,
                          ),
                          const SizedBox(width: 7),
                          Expanded(
                            child: Text(
                              widget.attached!,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Type.body.copyWith(
                                fontSize: 11.5,
                                fontStyle: FontStyle.italic,
                                color: Palette.textMid,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Container(
                    decoration: facetedDecoration(
                      cut: 9,
                      color: const Color(0xFF15100D),
                      borderColor: Palette.brass.withValues(alpha: 0.50),
                    ),
                    child: TextField(
                      controller: _text,
                      focusNode: _focus,
                      autofocus: true,
                      minLines: 2,
                      maxLines: 3,
                      maxLength: 180,
                      keyboardType: TextInputType.text,
                      textCapitalization: TextCapitalization.sentences,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _keep(),
                      style: Type.body.copyWith(
                        fontSize: 15,
                        height: 1.35,
                        color: Palette.textHi,
                      ),
                      cursorColor: Palette.xpLight,
                      decoration: InputDecoration(
                        hintText: 'What do you want to remember?',
                        hintStyle: Type.body.copyWith(
                          fontSize: 14,
                          color: Palette.textLo,
                        ),
                        counterStyle: Type.label.copyWith(
                          fontSize: Type.minLabel,
                          color: Palette.textLo,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.fromLTRB(
                          12,
                          11,
                          12,
                          7,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  HoneyButton(
                    label: 'KEEP IN JOURNAL',
                    icon: Icons.bookmark_add_outlined,
                    enabled: _ready,
                    expand: true,
                    onTap: _keep,
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
