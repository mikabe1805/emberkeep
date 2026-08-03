import 'dart:math' show max, min;

import 'package:flutter/material.dart';

import '../audio.dart';
import '../haptics.dart';
import '../models.dart';
import '../tokens.dart';
import 'facets.dart';
import 'glass.dart';
import 'honey_button.dart';

/// Optional writing for the closing ledger. Every answered prompt returns as
/// one structured Journal page; dismissing or leaving everything blank writes
/// nothing and never gets in the way of closing the day.
Future<NightJournalData?> showNightReflectionSheet(
  BuildContext context, {
  NightJournalData? initial,
  bool reduceMotion = false,
}) {
  Sfx.instance.play('tick_warm');
  Haptics.tap();
  // The night flow itself lives in an OverlayEntry. A modal bottom sheet
  // launched from that entry inherits its transformed coordinate space and
  // can render as a partial-height drawer. Put the reflection on the root
  // navigator instead: it is one of the day's bookends, not a utility sheet.
  return showGeneralDialog<NightJournalData>(
    context: context,
    useRootNavigator: true,
    barrierDismissible: true,
    barrierLabel: 'Not now',
    barrierColor: const Color(0xD10B0705),
    transitionDuration: reduceMotion
        ? Duration.zero
        : const Duration(milliseconds: 220),
    pageBuilder: (context, animation, secondaryAnimation) => SizedBox.expand(
      child: Material(
        type: MaterialType.transparency,
        child: SafeArea(
          child: SizedBox.expand(
            child: _NightReflectionSheet(
              initial: initial,
              reduceMotion: reduceMotion,
            ),
          ),
        ),
      ),
    ),
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      if (reduceMotion) return child;
      final entrance = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(
        opacity: entrance,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.035),
            end: Offset.zero,
          ).animate(entrance),
          child: child,
        ),
      );
    },
  );
}

class _NightReflectionSheet extends StatefulWidget {
  const _NightReflectionSheet({
    required this.initial,
    required this.reduceMotion,
  });

  final NightJournalData? initial;
  final bool reduceMotion;

  @override
  State<_NightReflectionSheet> createState() => _NightReflectionSheetState();
}

class _NightReflectionSheetState extends State<_NightReflectionSheet> {
  late final TextEditingController _reflection;
  late final List<TextEditingController> _gratitudes;
  late final TextEditingController _discovery;
  late final TextEditingController _tomorrow;
  int _section = 0;
  bool _ready = false;

  Iterable<TextEditingController> get _controllers sync* {
    yield _reflection;
    yield* _gratitudes;
    yield _discovery;
    yield _tomorrow;
  }

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _reflection = TextEditingController(text: initial?.reflection ?? '');
    _gratitudes = [
      for (var index = 0; index < 3; index++)
        TextEditingController(
          text: index < (initial?.gratitudes.length ?? 0)
              ? initial!.gratitudes[index]
              : '',
        ),
    ];
    _discovery = TextEditingController(text: initial?.discovery ?? '');
    _tomorrow = TextEditingController(text: initial?.tomorrowMessage ?? '');
    for (final controller in _controllers) {
      controller.addListener(_trackReady);
    }
    _ready = _controllers.any(
      (controller) => controller.text.trim().isNotEmpty,
    );
    if (_reflection.text.trim().isEmpty) {
      if (_gratitudes.any((c) => c.text.trim().isNotEmpty)) {
        _section = 1;
      } else if (_discovery.text.trim().isNotEmpty) {
        _section = 2;
      } else if (_tomorrow.text.trim().isNotEmpty) {
        _section = 3;
      }
    }
  }

  void _trackReady() {
    final ready = _controllers.any(
      (controller) => controller.text.trim().isNotEmpty,
    );
    if (ready != _ready && mounted) setState(() => _ready = ready);
  }

  bool _answered(int section) => switch (section) {
    0 => _reflection.text.trim().isNotEmpty,
    1 => _gratitudes.any((c) => c.text.trim().isNotEmpty),
    2 => _discovery.text.trim().isNotEmpty,
    _ => _tomorrow.text.trim().isNotEmpty,
  };

  void _keep() {
    final data = NightJournalData(
      reflection: _reflection.text,
      gratitudes: [for (final c in _gratitudes) c.text],
      discovery: _discovery.text,
      tomorrowMessage: _tomorrow.text,
    );
    if (data.isEmpty && widget.initial == null) return;
    Sfx.instance.play('tick_lift');
    Haptics.success();
    Navigator.of(context).pop(data);
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller
        ..removeListener(_trackReady)
        ..dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final still =
        widget.reduceMotion ||
        (MediaQuery.maybeDisableAnimationsOf(context) ?? false);
    final keyboard = media.viewInsets.bottom;
    // This is a deliberate bookend, not a utility drawer. Let the writing
    // surface occupy the night while keeping a small reveal of the ledger
    // around its faceted edge. When the keyboard arrives, the same surface
    // contracts above it and its slivers make every prompt reachable.
    return LayoutBuilder(
      builder: (context, bounds) {
        // Route constraints are the source of truth. MediaQuery can briefly
        // retain the previous surface size during a root-overlay transition
        // (and in split-screen), which used to pull this ritual back down into
        // a drawer even though the route itself covered the display.
        final routeHeight = bounds.hasBoundedHeight
            ? bounds.maxHeight
            : media.size.height;
        final routeWidth = bounds.hasBoundedWidth
            ? bounds.maxWidth
            : media.size.width;
        final available = max(1.0, routeHeight - keyboard - 22);
        return AnimatedPadding(
          duration: still ? Duration.zero : const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: EdgeInsets.fromLTRB(12, 10, 12, 12 + keyboard),
          child: Align(
            alignment: Alignment.bottomCenter,
            child: SizedBox(
              width: max(1.0, min(580, routeWidth - 24)),
              height: available,
              child: GlassPanel(
                key: const Key('night-reflection-sheet'),
                radius: 18,
                tint: const Color(0xFD211813),
                padding: const EdgeInsets.fromLTRB(15, 13, 15, 14),
                child: CustomScrollView(
                  key: const Key('night-reflection-scroll'),
                  physics: const BouncingScrollPhysics(),
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  slivers: [
                    SliverToBoxAdapter(
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
                                  Icons.menu_book_rounded,
                                  size: 19,
                                  color: Palette.xpLight,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'TONIGHT, IF YOU WANT',
                                      style: Type.label.copyWith(
                                        fontSize: 10,
                                        color: Palette.xpLight,
                                        letterSpacing: 1.35,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      'Keep what matters',
                                      style: Type.display.copyWith(
                                        fontSize: 22,
                                        height: 1.05,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Semantics(
                                button: true,
                                label: 'Not now',
                                child: IconButton(
                                  tooltip: 'Not now',
                                  constraints: const BoxConstraints(
                                    minWidth: 48,
                                    minHeight: 48,
                                  ),
                                  onPressed: () => Navigator.of(context).pop(),
                                  icon: const Icon(
                                    Icons.close_rounded,
                                    color: Palette.textLo,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 7),
                          Text(
                            'Use any prompt. Leave the rest blank.',
                            style: Type.body.copyWith(
                              fontSize: 12.5,
                              color: Palette.textMid,
                            ),
                          ),
                          const SizedBox(height: 12),
                          LayoutBuilder(
                            builder: (context, bounds) {
                              final compact =
                                  bounds.maxWidth < 340 ||
                                  MediaQuery.textScalerOf(context).scale(1) >
                                      1.3;
                              if (compact) {
                                final tabWidth = (bounds.maxWidth - 6) / 2;
                                return Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: [
                                    for (var index = 0; index < 4; index++)
                                      _promptTab(
                                        index,
                                        width: tabWidth,
                                        compact: true,
                                      ),
                                  ],
                                );
                              }
                              final tabWidth = (bounds.maxWidth - 6) / 2;
                              return Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: [
                                  for (var index = 0; index < 4; index++)
                                    _promptTab(index, width: tabWidth),
                                ],
                              );
                            },
                          ),
                          const SizedBox(height: 12),
                          AnimatedSwitcher(
                            duration: still
                                ? Duration.zero
                                : const Duration(milliseconds: 180),
                            switchInCurve: Curves.easeOutCubic,
                            child: _sectionBody(),
                          ),
                          const SizedBox(height: 12),
                          HoneyButton(
                            label: !_ready && widget.initial != null
                                ? 'REMOVE TONIGHT’S PAGE'
                                : 'KEEP TONIGHT’S PAGE',
                            icon: !_ready && widget.initial != null
                                ? Icons.delete_outline_rounded
                                : Icons.bookmark_add_outlined,
                            enabled: _ready || widget.initial != null,
                            expand: true,
                            onTap: _keep,
                          ),
                        ],
                      ),
                    ),
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: SizedBox.shrink(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _sectionBody() => switch (_section) {
    0 => _PromptBody(
      key: const ValueKey('reflection'),
      title: 'Optional reflection',
      prompt: 'What do you want to remember about today?',
      child: _NightField(
        key: const Key('night-reflection-field'),
        controller: _reflection,
        hint: 'A moment, a feeling, or the honest version of the day…',
        maxLength: 280,
        minLines: 3,
        maxLines: 5,
      ),
    ),
    1 => _PromptBody(
      key: const ValueKey('grateful'),
      title: 'Three things you’re grateful for',
      prompt: 'People, places, moments, or very small things all count.',
      child: Column(
        children: [
          for (var index = 0; index < 3; index++) ...[
            _NightField(
              key: Key('night-gratitude-$index'),
              controller: _gratitudes[index],
              hint: '${index + 1}.',
              maxLength: 120,
              minLines: 1,
              maxLines: 2,
              action: index == 2 ? TextInputAction.done : TextInputAction.next,
            ),
            if (index != 2) const SizedBox(height: 8),
          ],
        ],
      ),
    ),
    2 => _PromptBody(
      key: const ValueKey('discovery'),
      title: 'One thing you discovered',
      prompt: 'Something you noticed, learned, or understood differently.',
      child: _NightField(
        key: const Key('night-discovery-field'),
        controller: _discovery,
        hint: 'I discovered…',
        maxLength: 220,
        minLines: 3,
        maxLines: 4,
      ),
    ),
    _ => _PromptBody(
      key: const ValueKey('tomorrow'),
      title: 'A message for tomorrow you',
      prompt: 'This will be waiting when you open the next day.',
      child: _NightField(
        key: const Key('night-tomorrow-field'),
        controller: _tomorrow,
        hint: 'For tomorrow…',
        maxLength: 220,
        minLines: 3,
        maxLines: 4,
      ),
    ),
  };

  Widget _promptTab(int index, {double? width, bool compact = false}) {
    const labels = ['REFLECT', '3 GRATEFUL', 'DISCOVERED', 'TOMORROW'];
    const icons = [
      Icons.history_edu_rounded,
      Icons.favorite_border_rounded,
      Icons.lightbulb_outline_rounded,
      Icons.forward_to_inbox_outlined,
    ];
    return _PromptTab(
      width: width,
      compact: compact,
      label: labels[index],
      icon: icons[index],
      selected: _section == index,
      answered: _answered(index),
      onTap: () => setState(() => _section = index),
    );
  }
}

class _PromptTab extends StatelessWidget {
  const _PromptTab({
    this.width,
    this.compact = false,
    required this.label,
    required this.icon,
    required this.selected,
    required this.answered,
    required this.onTap,
  });

  final double? width;
  final bool compact;
  final String label;
  final IconData icon;
  final bool selected;
  final bool answered;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? Palette.xpLight : Palette.textMid;
    return Semantics(
      button: true,
      selected: selected,
      label: '$label prompt${answered ? ', answered' : ''}',
      child: Material(
        color: Colors.transparent,
        shape: const FacetedBorder(cut: 6),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            width: width ?? double.infinity,
            constraints: BoxConstraints(minHeight: compact ? 52 : 48),
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 4 : 9,
              vertical: compact ? 5 : 7,
            ),
            decoration: facetedDecoration(
              cut: 6,
              color: selected
                  ? Palette.xp.withValues(alpha: 0.13)
                  : Palette.glassFill,
              borderColor: selected
                  ? Palette.xp.withValues(alpha: 0.62)
                  : Palette.glassEdge,
            ),
            child: compact
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        answered ? Icons.check_rounded : icon,
                        size: 14,
                        color: color,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        label,
                        maxLines: 2,
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                        style: Type.label.copyWith(fontSize: 9, color: color),
                      ),
                    ],
                  )
                : Row(
                    children: [
                      Icon(
                        answered ? Icons.check_rounded : icon,
                        size: 14,
                        color: color,
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          label,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Type.label.copyWith(
                            fontSize: 9.5,
                            color: color,
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class _PromptBody extends StatelessWidget {
  const _PromptBody({
    super.key,
    required this.title,
    required this.prompt,
    required this.child,
  });

  final String title;
  final String prompt;
  final Widget child;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: Type.display.copyWith(fontSize: 19, color: Palette.textHi),
      ),
      const SizedBox(height: 3),
      Text(
        prompt,
        style: Type.body.copyWith(fontSize: 12, color: Palette.textLo),
      ),
      const SizedBox(height: 10),
      child,
    ],
  );
}

class _NightField extends StatelessWidget {
  const _NightField({
    super.key,
    required this.controller,
    required this.hint,
    required this.maxLength,
    required this.minLines,
    required this.maxLines,
    this.action = TextInputAction.newline,
  });

  final TextEditingController controller;
  final String hint;
  final int maxLength;
  final int minLines;
  final int maxLines;
  final TextInputAction action;

  @override
  Widget build(BuildContext context) => Container(
    decoration: facetedDecoration(
      cut: 9,
      color: const Color(0xFF15100D),
      borderColor: Palette.brass.withValues(alpha: 0.50),
    ),
    child: TextField(
      controller: controller,
      minLines: minLines,
      maxLines: maxLines,
      maxLength: maxLength,
      keyboardType: TextInputType.multiline,
      textCapitalization: TextCapitalization.sentences,
      textInputAction: action,
      style: Type.body.copyWith(
        fontSize: 15,
        height: 1.35,
        color: Palette.textHi,
      ),
      cursorColor: Palette.xpLight,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: Type.body.copyWith(fontSize: 14, color: Palette.textLo),
        counterStyle: Type.label.copyWith(fontSize: 9, color: Palette.textLo),
        border: InputBorder.none,
        contentPadding: const EdgeInsets.fromLTRB(12, 11, 12, 7),
      ),
    ),
  );
}
