import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../audio.dart';
import '../content/creature_skins.dart';
import '../content/momentum_kits.dart';
import '../engine.dart';
import '../models.dart';
import '../tokens.dart';
import '../widgets/detail_header.dart';
import '../widgets/facets.dart';
import '../widgets/glass.dart';
import '../widgets/hearth_glyph.dart';

/// Specialized help for distinct kinds of days, all feeding the same Keep.
/// Kits are deliberately housed in Goals instead of becoming a sixth tab.
class MomentumKitsPage extends StatelessWidget {
  const MomentumKitsPage({
    super.key,
    required this.state,
    required this.onAdd,
    required this.onPersist,
    required this.onOpenQuests,
  });

  final GameState state;
  final bool Function(Quest) onAdd;
  final VoidCallback onPersist;
  final VoidCallback onOpenQuests;

  void _openKit(BuildContext context, MomentumKitSpec kit) {
    Sfx.instance.play('tick');
    HapticFeedback.selectionClick();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Palette.dialogBarrier,
      builder: (_) => _KitLauncherSheet(
        kit: kit,
        state: state,
        onAdd: onAdd,
        onPersist: onPersist,
        onOpenQuests: () {
          Navigator.of(context).pop();
          onOpenQuests();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final immediate = momentumKits.take(3).toList(growable: false);
    final rhythms = momentumKits.skip(3).toList(growable: false);
    return Scaffold(
      backgroundColor: Palette.parchment,
      body: WarmBackground(
        themeId: state.canvasTheme,
        tint: Palette.xp,
        reduceMotion: state.reduceMotion,
        child: SafeArea(
          child: Column(
            children: [
              const DetailHeader(
                title: 'Momentum Kits',
                subtitle: 'specialized help · the same growing Keep',
                accent: Palette.xpLight,
                pill: 'OPTIONAL',
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 40),
                  children: [
                    _KitsHero(state: state),
                    const SizedBox(height: 22),
                    const _SectionTitle(
                      title: 'RIGHT NOW',
                      subtitle: 'for the kind of day you are actually having',
                      accent: Palette.streak,
                    ),
                    const SizedBox(height: 10),
                    for (final kit in immediate) ...[
                      _KitCard(kit: kit, onTap: () => _openKit(context, kit)),
                      const SizedBox(height: 10),
                    ],
                    const SizedBox(height: 12),
                    const _SectionTitle(
                      title: 'BUILD A RHYTHM',
                      subtitle: 'return whenever you want another session',
                      accent: Palette.unlock,
                    ),
                    const SizedBox(height: 10),
                    for (final kit in rhythms) ...[
                      _KitCard(kit: kit, onTap: () => _openKit(context, kit)),
                      const SizedBox(height: 10),
                    ],
                    const SizedBox(height: 6),
                    Text(
                      'Kits never make a second checklist. They place a few today-only sparks on Quests; completing them grows your usual domains, XP, embers, and hearth.',
                      textAlign: TextAlign.center,
                      style: Type.body.copyWith(
                        fontSize: 12,
                        height: 1.45,
                        fontStyle: FontStyle.italic,
                        color: Palette.textLo,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _KitsHero extends StatelessWidget {
  const _KitsHero({required this.state});
  final GameState state;

  @override
  Widget build(BuildContext context) {
    final flame = flameHueFor(state);
    return GlassPanel(
      glow: true,
      padding: EdgeInsets.zero,
      child: SizedBox(
        height: 168,
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(painter: _KitMapPainter(accent: flame)),
            ),
            Positioned(
              top: 18,
              left: 18,
              right: 125,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'What kind of help\nwould feel useful?',
                    style: Type.display.copyWith(fontSize: 23, height: 1.04),
                  ),
                  const SizedBox(height: 9),
                  Text(
                    'Meet the day where it is.\nStill grow the same world.',
                    style: Type.body.copyWith(
                      fontSize: 12.5,
                      height: 1.35,
                      color: Palette.textMid,
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              right: 30,
              top: 37,
              child: FacetMedallion(
                size: 78,
                accent: flame,
                glow: true,
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0x55FFF4D9), Color(0x332E1810)],
                ),
                child: HearthGlyph(
                  level: state.level,
                  lit: state.streakDays > 0,
                  glow: flame,
                  reduceMotion: state.reduceMotion,
                  size: 58,
                ),
              ),
            ),
            Positioned(
              left: 18,
              right: 18,
              bottom: 15,
              child: Row(
                children: [
                  _HeroRune(color: Stat.vit.color, icon: Icons.spa_outlined),
                  const SizedBox(width: 8),
                  _HeroRune(
                    color: Stat.dis.color,
                    icon: Icons.cottage_outlined,
                  ),
                  const SizedBox(width: 8),
                  _HeroRune(
                    color: Stat.foc.color,
                    icon: Icons.auto_awesome_outlined,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'ONE WORLD · MANY DOORWAYS',
                      maxLines: 1,
                      textAlign: TextAlign.right,
                      style: Type.label.copyWith(
                        fontSize: 9,
                        letterSpacing: 0.75,
                        color: Palette.xpLight,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _KitMapPainter extends CustomPainter {
  const _KitMapPainter({required this.accent});
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final plane = Paint()
      ..color = accent.withValues(alpha: 0.055)
      ..style = PaintingStyle.fill;
    canvas.drawPath(
      Path()
        ..moveTo(size.width * 0.55, 0)
        ..lineTo(size.width, 0)
        ..lineTo(size.width, size.height * 0.72)
        ..lineTo(size.width * 0.68, size.height * 0.46)
        ..close(),
      plane,
    );
    final line = Paint()
      ..color = accent.withValues(alpha: 0.24)
      ..strokeWidth = 1.15
      ..style = PaintingStyle.stroke;
    canvas.drawPath(
      Path()
        ..moveTo(size.width * 0.12, size.height * 0.74)
        ..lineTo(size.width * 0.48, size.height * 0.74)
        ..lineTo(size.width * 0.68, size.height * 0.48)
        ..lineTo(size.width * 0.83, size.height * 0.48),
      line,
    );
    canvas.drawLine(
      Offset(size.width * 0.68, size.height * 0.48),
      Offset(size.width * 0.70, size.height * 0.86),
      line,
    );
  }

  @override
  bool shouldRepaint(_KitMapPainter oldDelegate) =>
      oldDelegate.accent != accent;
}

class _HeroRune extends StatelessWidget {
  const _HeroRune({required this.color, required this.icon});
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) => FacetMedallion(
    size: 27,
    accent: color,
    child: Icon(icon, size: 14, color: color),
  );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.title,
    required this.subtitle,
    required this.accent,
  });
  final String title;
  final String subtitle;
  final Color accent;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      Transform.rotate(
        angle: 0.785,
        child: Container(width: 8, height: 8, color: accent),
      ),
      const SizedBox(width: 11),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Type.label.copyWith(
                fontSize: 11,
                letterSpacing: 1.8,
                color: Palette.textHi,
              ),
            ),
            Text(
              subtitle,
              style: Type.body.copyWith(
                fontSize: 11.5,
                fontStyle: FontStyle.italic,
                color: Palette.textLo,
              ),
            ),
          ],
        ),
      ),
      Container(width: 44, height: 1, color: accent.withValues(alpha: 0.35)),
    ],
  );
}

IconData _iconFor(MomentumKitKind kind) => switch (kind) {
  MomentumKitKind.unstick => Icons.bolt_outlined,
  MomentumKitKind.lowFlame => Icons.nightlight_outlined,
  MomentumKitKind.homeReset => Icons.cottage_outlined,
  MomentumKitKind.focusExpedition => Icons.explore_outlined,
  MomentumKitKind.creativePractice => Icons.auto_awesome_outlined,
  MomentumKitKind.steadyDay => Icons.wb_twilight_outlined,
};

String _badgeFor(MomentumKitKind kind) => switch (kind) {
  MomentumKitKind.unstick => '2–10 MIN',
  MomentumKitKind.lowFlame => '1–3 SPARKS',
  MomentumKitKind.homeReset => '5–30 MIN',
  MomentumKitKind.focusExpedition => '15–45 MIN',
  MomentumKitKind.creativePractice => '10–45 MIN',
  MomentumKitKind.steadyDay => '1–3 SPARKS',
};

class _KitCard extends StatelessWidget {
  const _KitCard({required this.kit, required this.onTap});
  final MomentumKitSpec kit;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: '${kit.title}. ${kit.promise}',
    child: GestureDetector(
      excludeFromSemantics: true,
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: GlassPanel(
        padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FacetMedallion(
              size: 48,
              accent: kit.stat.color,
              glow: kit.kind == MomentumKitKind.lowFlame,
              child: Icon(_iconFor(kit.kind), size: 23, color: kit.stat.color),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          kit.eyebrow,
                          style: Type.label.copyWith(
                            fontSize: 9.5,
                            color: kit.stat.color,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 3,
                        ),
                        decoration: facetedDecoration(
                          cut: 5,
                          color: kit.stat.color.withValues(alpha: 0.09),
                          borderColor: kit.stat.color.withValues(alpha: 0.28),
                        ),
                        child: Text(
                          _badgeFor(kit.kind),
                          style: Type.label.copyWith(
                            fontSize: 8.5,
                            letterSpacing: 0.7,
                            color: Palette.textMid,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(kit.title, style: Type.display.copyWith(fontSize: 19)),
                  const SizedBox(height: 3),
                  Text(
                    kit.promise,
                    style: Type.body.copyWith(
                      fontSize: 12.5,
                      height: 1.35,
                      color: Palette.textMid,
                    ),
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(top: 25, left: 5),
              child: Icon(Icons.chevron_right, size: 19, color: Palette.textLo),
            ),
          ],
        ),
      ),
    ),
  );
}

class _KitLauncherSheet extends StatefulWidget {
  const _KitLauncherSheet({
    required this.kit,
    required this.state,
    required this.onAdd,
    required this.onPersist,
    required this.onOpenQuests,
  });

  final MomentumKitSpec kit;
  final GameState state;
  final bool Function(Quest) onAdd;
  final VoidCallback onPersist;
  final VoidCallback onOpenQuests;

  @override
  State<_KitLauncherSheet> createState() => _KitLauncherSheetState();
}

class _KitLauncherSheetState extends State<_KitLauncherSheet> {
  late final TextEditingController _text;
  int _minutes = 5;
  int _capacity = 2;
  Stat _stat = Stat.foc;
  String _room = 'Kitchen';
  int? _added;

  @override
  void initState() {
    super.initState();
    _text = TextEditingController();
    _minutes = switch (widget.kit.kind) {
      MomentumKitKind.unstick => 5,
      MomentumKitKind.homeReset => 15,
      MomentumKitKind.focusExpedition => 25,
      MomentumKitKind.creativePractice => 25,
      _ => 5,
    };
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  List<int> get _minuteOptions => switch (widget.kit.kind) {
    MomentumKitKind.unstick => const [2, 5, 10],
    MomentumKitKind.homeReset => const [5, 15, 30],
    MomentumKitKind.focusExpedition => const [15, 25, 45],
    MomentumKitKind.creativePractice => const [10, 25, 45],
    _ => const [],
  };

  String? get _prompt => switch (widget.kit.kind) {
    MomentumKitKind.unstick => 'What feels stuck?',
    MomentumKitKind.focusExpedition => 'Where are you trying to arrive?',
    MomentumKitKind.creativePractice => 'What are you making?',
    _ => null,
  };

  String? get _hint => switch (widget.kit.kind) {
    MomentumKitKind.unstick => 'e.g. open the tax form',
    MomentumKitKind.focusExpedition => 'e.g. understand chapter four',
    MomentumKitKind.creativePractice => 'e.g. the moonlit sketch',
    _ => null,
  };

  List<Quest> _quests() => switch (widget.kit.kind) {
    MomentumKitKind.unstick => [
      buildUnstickQuest(task: _text.text, minutes: _minutes, stat: _stat),
    ],
    MomentumKitKind.lowFlame => buildLowFlameQuests(capacity: _capacity),
    MomentumKitKind.homeReset => buildHomeResetQuests(
      room: _room,
      minutes: _minutes,
    ),
    MomentumKitKind.focusExpedition => [
      buildFocusQuest(target: _text.text, minutes: _minutes),
    ],
    MomentumKitKind.creativePractice => [
      buildCreativeQuest(project: _text.text, minutes: _minutes),
    ],
    MomentumKitKind.steadyDay => buildSteadyDayQuests(capacity: _capacity),
  };

  void _launch() {
    FocusManager.instance.primaryFocus?.unfocus();
    final quests = _quests();
    var added = 0;
    for (final quest in quests) {
      if (widget.onAdd(quest)) added++;
    }
    if (added > 0) {
      switch (widget.kit.kind) {
        case MomentumKitKind.focusExpedition:
          widget.state.addGoal(
            Goal(title: 'Protect my attention', stat: Stat.intl, target: 25),
          );
          break;
        case MomentumKitKind.creativePractice:
          widget.state.addGoal(
            Goal(title: 'Keep a creative practice', stat: Stat.foc, target: 25),
          );
          break;
        case MomentumKitKind.steadyDay:
          widget.state.addGoal(
            Goal(title: 'Build a steady day', stat: Stat.soc, target: 25),
          );
          break;
        default:
          break;
      }
      widget.onPersist();
      Sfx.instance.play('levelup');
      HapticFeedback.mediumImpact();
    } else {
      Sfx.instance.play('boing');
      HapticFeedback.selectionClick();
    }
    setState(() => _added = added);
  }

  void _openBoard() {
    Navigator.of(context).pop();
    // Let the modal route finish leaving before asking its parent route to
    // leave too. Two synchronous pops race on iOS and the second is ignored,
    // leaving the user on the kit hub while the hidden tab changes beneath it.
    Future<void>.delayed(const Duration(milliseconds: 320), () {
      widget.onOpenQuests();
    });
  }

  @override
  Widget build(BuildContext context) {
    final kit = widget.kit;
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: keyboard),
      child: Material(
        color: Colors.transparent,
        child: GlassPanel(
          tint: Palette.dialogSurface,
          radius: 24,
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 20),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.84,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 46,
                      height: 3,
                      color: Palette.textLo.withValues(alpha: 0.45),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FacetMedallion(
                        size: 52,
                        accent: kit.stat.color,
                        glow: true,
                        child: Icon(
                          _iconFor(kit.kind),
                          size: 25,
                          color: kit.stat.color,
                        ),
                      ),
                      const SizedBox(width: 13),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              kit.eyebrow,
                              style: Type.label.copyWith(
                                fontSize: 9.5,
                                color: kit.stat.color,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              kit.title,
                              style: Type.display.copyWith(fontSize: 23),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              kit.detail,
                              style: Type.body.copyWith(
                                fontSize: 12.5,
                                height: 1.35,
                                color: Palette.textLo,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  if (_added != null)
                    _SuccessState(
                      requested: _quests().length,
                      added: _added!,
                      accent: kit.stat.color,
                      onOpenQuests: _openBoard,
                    )
                  else ...[
                    if (_prompt != null) ...[
                      _FieldLabel(_prompt!),
                      const SizedBox(height: 7),
                      TextField(
                        key: const ValueKey('momentum-kit-text'),
                        controller: _text,
                        textCapitalization: TextCapitalization.sentences,
                        style: Type.body.copyWith(color: Palette.textHi),
                        cursorColor: kit.stat.color,
                        decoration: InputDecoration(
                          hintText: _hint,
                          hintStyle: Type.body.copyWith(
                            fontSize: 14,
                            color: Palette.textLo,
                          ),
                          filled: true,
                          fillColor: Palette.glassFill,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 13,
                          ),
                          enabledBorder: const OutlineInputBorder(
                            borderSide: BorderSide(color: Palette.glassEdge),
                            borderRadius: BorderRadius.zero,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(
                              color: kit.stat.color.withValues(alpha: 0.75),
                            ),
                            borderRadius: BorderRadius.zero,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (kit.kind == MomentumKitKind.homeReset) ...[
                      const _FieldLabel('Where would a visible win help?'),
                      const SizedBox(height: 8),
                      _ChoiceRow<String>(
                        options: const [
                          'Kitchen',
                          'Bedroom',
                          'Living room',
                          'Desk',
                        ],
                        selected: _room,
                        label: (v) => v,
                        accent: kit.stat.color,
                        onChanged: (v) => setState(() => _room = v),
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (_minuteOptions.isNotEmpty) ...[
                      _FieldLabel(
                        kit.kind == MomentumKitKind.homeReset
                            ? 'How much time is enough?'
                            : 'Choose a small container',
                      ),
                      const SizedBox(height: 8),
                      _ChoiceRow<int>(
                        options: _minuteOptions,
                        selected: _minutes,
                        label: (v) => '$v MIN',
                        accent: kit.stat.color,
                        onChanged: (v) => setState(() => _minutes = v),
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (kit.kind == MomentumKitKind.unstick) ...[
                      const _FieldLabel('What part of life is it tending?'),
                      const SizedBox(height: 8),
                      _ChoiceRow<Stat>(
                        options: const [
                          Stat.foc,
                          Stat.dis,
                          Stat.vit,
                          Stat.intl,
                        ],
                        selected: _stat,
                        label: (v) => v.abbr,
                        color: (v) => v.color,
                        accent: _stat.color,
                        onChanged: (v) => setState(() => _stat = v),
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (kit.kind == MomentumKitKind.lowFlame ||
                        kit.kind == MomentumKitKind.steadyDay) ...[
                      _FieldLabel(
                        kit.kind == MomentumKitKind.lowFlame
                            ? 'How many embers do you truly have?'
                            : 'How full should today feel?',
                      ),
                      const SizedBox(height: 8),
                      _CapacityPicker(
                        value: _capacity,
                        accent: kit.stat.color,
                        onChanged: (v) => setState(() => _capacity = v),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        _capacityCopy(kit.kind, _capacity),
                        style: Type.body.copyWith(
                          fontSize: 12.5,
                          fontStyle: FontStyle.italic,
                          color: Palette.textLo,
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    _LaunchButton(
                      label: _launchLabel(kit.kind, _capacity, _minutes),
                      onTap: _launch,
                    ),
                    const SizedBox(height: 10),
                    Center(
                      child: Text(
                        'today only · editable · no penalty if the day changes',
                        textAlign: TextAlign.center,
                        style: Type.body.copyWith(
                          fontSize: 11,
                          color: Palette.textLo,
                        ),
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

String _capacityCopy(MomentumKitKind kind, int value) {
  if (kind == MomentumKitKind.lowFlame) {
    return switch (value) {
      1 => 'One basic kindness. That is a complete day.',
      2 => 'Tend yourself, then make one corner lighter.',
      _ => 'A small, balanced board — still deliberately gentle.',
    };
  }
  return switch (value) {
    1 => 'One gentle movement is enough to begin.',
    2 => 'Movement and one everyday need.',
    _ => 'Movement, care, and one human connection.',
  };
}

String _launchLabel(MomentumKitKind kind, int capacity, int minutes) =>
    switch (kind) {
      MomentumKitKind.lowFlame || MomentumKitKind.steadyDay =>
        capacity == 1 ? 'LIGHT 1 SPARK' : 'LIGHT $capacity SPARKS',
      MomentumKitKind.homeReset =>
        minutes <= 5 ? 'PIN THE RESET' : 'PIN THE RESET PATH',
      _ => 'PIN TO QUESTS',
    };

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text.toUpperCase(),
    style: Type.label.copyWith(fontSize: 10.5, color: Palette.textMid),
  );
}

class _ChoiceRow<T> extends StatelessWidget {
  const _ChoiceRow({
    required this.options,
    required this.selected,
    required this.label,
    required this.accent,
    required this.onChanged,
    this.color,
  });

  final List<T> options;
  final T selected;
  final String Function(T) label;
  final Color accent;
  final Color Function(T)? color;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      for (final option in options)
        Semantics(
          button: true,
          selected: option == selected,
          child: GestureDetector(
            excludeFromSemantics: true,
            onTap: () {
              Sfx.instance.play('tick');
              HapticFeedback.selectionClick();
              onChanged(option);
            },
            child: AnimatedContainer(
              duration: Motion.quick,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: facetedDecoration(
                cut: 8,
                color: option == selected
                    ? (color?.call(option) ?? accent).withValues(alpha: 0.2)
                    : Colors.transparent,
                borderColor: option == selected
                    ? (color?.call(option) ?? accent).withValues(alpha: 0.7)
                    : Palette.glassEdge,
              ),
              child: Text(
                label(option),
                style: Type.label.copyWith(
                  fontSize: 10.5,
                  color: option == selected
                      ? (color?.call(option) ?? accent)
                      : Palette.textMid,
                ),
              ),
            ),
          ),
        ),
    ],
  );
}

class _CapacityPicker extends StatelessWidget {
  const _CapacityPicker({
    required this.value,
    required this.accent,
    required this.onChanged,
  });
  final int value;
  final Color accent;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      for (var i = 1; i <= 3; i++) ...[
        if (i > 1) const SizedBox(width: 8),
        Expanded(
          child: Semantics(
            button: true,
            selected: i == value,
            label: '$i ${i == 1 ? 'spark' : 'sparks'}',
            child: GestureDetector(
              excludeFromSemantics: true,
              onTap: () {
                Sfx.instance.play('tick');
                HapticFeedback.selectionClick();
                onChanged(i);
              },
              child: AnimatedContainer(
                duration: Motion.quick,
                height: 54,
                decoration: facetedDecoration(
                  cut: 9,
                  color: i == value
                      ? accent.withValues(alpha: 0.18)
                      : Palette.glassFill,
                  borderColor: i == value
                      ? accent.withValues(alpha: 0.7)
                      : Palette.glassEdge,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var spark = 0; spark < i; spark++) ...[
                      Transform.rotate(
                        angle: 0.785,
                        child: Container(
                          width: 8,
                          height: 8,
                          color: i == value ? accent : Palette.textLo,
                        ),
                      ),
                      if (spark < i - 1) const SizedBox(width: 5),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    ],
  );
}

class _LaunchButton extends StatelessWidget {
  const _LaunchButton({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    child: GestureDetector(
      excludeFromSemantics: true,
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: 50),
        alignment: Alignment.center,
        decoration: facetedDecoration(
          cut: 10,
          gradient: Palette.honeyGradient,
          borderColor: Palette.xpLight.withValues(alpha: 0.8),
          shadows: const [BoxShadow(color: Palette.honeyGlow, blurRadius: 18)],
        ),
        child: Text(
          label,
          style: Type.label.copyWith(
            fontSize: 12,
            letterSpacing: 1.5,
            color: Palette.onHoney,
          ),
        ),
      ),
    ),
  );
}

class _SuccessState extends StatelessWidget {
  const _SuccessState({
    required this.requested,
    required this.added,
    required this.accent,
    required this.onOpenQuests,
  });
  final int requested;
  final int added;
  final Color accent;
  final VoidCallback onOpenQuests;

  @override
  Widget build(BuildContext context) {
    final alreadyThere = added == 0;
    return Column(
      children: [
        FacetMedallion(
          size: 72,
          accent: alreadyThere ? Palette.xp : accent,
          glow: true,
          child: Icon(
            alreadyThere ? Icons.bookmark_added_outlined : Icons.auto_awesome,
            size: 32,
            color: alreadyThere ? Palette.xpLight : accent,
          ),
        ),
        const SizedBox(height: 15),
        Text(
          alreadyThere
              ? 'Already waiting on Quests'
              : added == 1
              ? 'One spark is waiting'
              : '$added sparks are waiting',
          textAlign: TextAlign.center,
          style: Type.display.copyWith(fontSize: 23),
        ),
        const SizedBox(height: 7),
        Text(
          alreadyThere
              ? 'This exact kit is already pinned for today. Nothing was duplicated.'
              : added < requested
              ? 'The rest were already on today’s board, so Emberkeep kept only the new ones.'
              : 'They are ordinary Emberkeep quests now: same XP, same embers, same growing hearth.',
          textAlign: TextAlign.center,
          style: Type.body.copyWith(
            fontSize: 13,
            height: 1.4,
            color: Palette.textLo,
          ),
        ),
        const SizedBox(height: 20),
        _LaunchButton(label: 'OPEN QUESTS', onTap: onOpenQuests),
      ],
    );
  }
}
