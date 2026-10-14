// The fight screen: a full-screen painted stage with two thumbs' worth of
// controls over it.
//
// The picture is two painters repainting straight from a [BrawlScene] on a
// ticker, so a frame never rebuilds the widget tree. The controls are painted
// with the HUD (so they look like the prototype's) and wrapped by transparent
// widgets that carry the words for a screen reader. Touch follows the
// prototype: a left-thumb pad slides to move and swipes up to jump, a big
// ATTACK button taps for a combo and holds for Power Slam, three round buttons
// cast, call and release the Super. Easy mode makes the whole stage the
// button.
library;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/semantics.dart' show CustomSemanticsAction;
import 'package:flutter/services.dart';

import '../../audio.dart' show InteractionSound, MaterialSound;
import '../../tokens.dart';
import '../../widgets/pressable.dart';
import '../brawl_abilities.dart' show lockedLine;
import '../core/brawl_core.dart';
import 'brawl_feel.dart';
import 'brawl_scene.dart';

class BrawlFightScreen extends StatefulWidget {
  const BrawlFightScreen({
    super.key,
    required this.config,
    required this.feel,
    required this.onFinished,
    required this.onQuit,
    this.reduceMotion = false,
    this.soundOn = true,
    this.onSoundChanged,
    this.hpMax,
  });

  final BrawlConfig config;
  final BrawlFeel feel;
  final bool reduceMotion;

  /// The fight is over and its result is ready (the victory screen opens).
  final void Function(BrawlResult result, BrawlFight fight) onFinished;

  /// Leave from the pause sheet.
  final VoidCallback onQuit;

  final bool soundOn;
  final ValueChanged<bool>? onSoundChanged;

  /// Overrides the monster's health (tests).
  final double? hpMax;

  @override
  State<BrawlFightScreen> createState() => BrawlFightScreenState();
}

class _Touch {
  _Touch(this.kind, this.sx, this.sy) : x = sx, y = sy;
  final String kind;
  final double sx, sy;
  double x, y;
  bool jumped = false;
}

class BrawlFightScreenState extends State<BrawlFightScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final BrawlFight fight;
  BrawlScene? _scene;
  Size _size = Size.zero;
  EdgeInsets _insets = EdgeInsets.zero;
  late final Ticker _ticker;
  Duration _last = Duration.zero;
  final Map<int, _Touch> _touches = {};
  bool _paused = false;
  bool _sound = true;
  double _keyLeft = 0, _keyRight = 0;
  final FocusNode _focus = FocusNode(debugLabel: 'brawl-fight');

  /// The running scene (null until the first layout).
  BrawlScene? get scene => _scene;
  bool get paused => _paused;

  @override
  void initState() {
    super.initState();
    _sound = widget.soundOn;
    fight = createBrawlFight(widget.config.copyWith(hpMax: widget.hpMax));
    _ticker = createTicker(_onTick)..start();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker.dispose();
    _scene?.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _setPaused(true);
  }

  void _onTick(Duration elapsed) {
    final scene = _scene;
    final dt = ((elapsed - _last).inMicroseconds / 1e6).clamp(0.0005, 0.05);
    _last = elapsed;
    if (scene == null || _paused) return;
    scene.tick(dt, keyMove: _keyRight - _keyLeft);
  }

  BrawlScene _sceneFor(Size size, EdgeInsets insets) {
    var scene = _scene;
    if (scene != null && size == _size && insets == _insets) return scene;
    final old = scene;
    final input = old?.inp;
    scene = BrawlScene(
      core: fight,
      layout: BrawlLayout(size, top: insets.top, bottom: insets.bottom),
      feel: widget.feel,
      reduceMotion: widget.reduceMotion,
      input: input,
    );
    scene.onVictory = () {
      if (mounted) widget.onFinished(BrawlResult.of(fight), fight);
    };
    _scene = scene;
    _size = size;
    _insets = insets;
    // The old scene is disposed after this frame, when nothing paints it.
    if (old != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
    }
    return scene;
  }

  void _setPaused(bool value) {
    if (_paused == value || !mounted) return;
    setState(() => _paused = value);
    if (value) {
      _scene?.releaseAll();
      _touches.clear();
    }
  }

  // ---------------------------------------------------------------- touch

  Offset _logical(Offset local) {
    final s = _scene!.layout.scale;
    return Offset(local.dx / s, local.dy / s);
  }

  void _down(PointerDownEvent e) {
    final scene = _scene;
    if (scene == null || _paused || fight.phase == BrawlPhase.done) return;
    final p = _logical(e.localPosition), lay = scene.layout, easy = scene.easy;
    String? kind;
    if (easy) {
      if (lay.eSpell.contains(p.dx, p.dy, 8)) {
        kind = 'spell';
      } else if (lay.eFriend.contains(p.dx, p.dy, 8)) {
        kind = 'friend';
      } else if (lay.eSup.contains(p.dx, p.dy, 8)) {
        kind = 'sup';
      } else {
        kind = 'tap';
      }
    } else {
      if (lay.spell.contains(p.dx, p.dy, 9)) {
        kind = 'spell';
      } else if (lay.friend.contains(p.dx, p.dy, 9)) {
        kind = 'friend';
      } else if (lay.sup.contains(p.dx, p.dy, 9)) {
        kind = 'sup';
      } else if (p.dx < lay.padZoneRight && p.dy > lay.padZoneTop) {
        kind = 'pad';
      } else if (p.dy > lay.padZoneTop - 40) {
        kind = 'attack';
      }
    }
    if (kind == null) return;
    _touches[e.pointer] = _Touch(kind, p.dx, p.dy);
    final t = scene.touch;
    switch (kind) {
      case 'pad':
        t
          ..padOn = true
          ..padOx = p.dx
          ..padOy = p.dy
          ..padKx = 0
          ..padKy = 0
          ..usedPad = true;
      case 'tap':
        scene.pressTap();
        t.ripples.add([p.dx, p.dy, 0]);
      case 'attack':
        scene.pressAttack();
      case 'spell':
        scene.pressSpell();
      case 'friend':
        scene.pressFriend();
      case 'sup':
        scene.pressSuper();
    }
  }

  void _move(PointerMoveEvent e) {
    final scene = _scene, t = _touches[e.pointer];
    if (scene == null || t == null) return;
    final p = _logical(e.localPosition);
    t
      ..x = p.dx
      ..y = p.dy;
    final touch = scene.touch;
    if (t.kind == 'pad') {
      final dx = p.dx - t.sx, dy = p.dy - t.sy;
      final ax = dx.abs();
      final mv = ax < 9 ? 0.0 : dx.sign * ((ax - 9) / 30).clamp(0.0, 1.0);
      touch
        ..padMove = mv
        ..padKx = dx.clamp(-40.0, 40.0)
        ..padKy = dy.clamp(-40.0, 40.0);
      if (dy < -34 && !t.jumped) {
        scene.pressJump();
        t.jumped = true;
      }
      if (dy > -12) t.jumped = false;
    } else if (t.kind == 'tap') {
      if (p.dy - t.sy < -56 && !t.jumped) {
        scene.pressJump();
        t.jumped = true;
      }
    }
  }

  void _up(PointerEvent e) {
    final scene = _scene, t = _touches.remove(e.pointer);
    if (scene == null || t == null) return;
    if (t.kind == 'pad') {
      scene.touch
        ..padOn = false
        ..padMove = 0
        ..padKx = 0
        ..padKy = 0;
    } else if (t.kind == 'attack' || t.kind == 'tap') {
      scene.releaseAttack();
    }
  }

  KeyEventResult _key(FocusNode node, KeyEvent e) {
    final scene = _scene;
    if (scene == null) return KeyEventResult.ignored;
    final key = e.logicalKey;
    if (e is KeyDownEvent &&
        (key == LogicalKeyboardKey.escape || key == LogicalKeyboardKey.keyP)) {
      _setPaused(!_paused);
      return KeyEventResult.handled;
    }
    final down = e is KeyDownEvent || e is KeyRepeatEvent;
    if (e is KeyUpEvent) {
      if (key == LogicalKeyboardKey.arrowLeft) _keyLeft = 0;
      if (key == LogicalKeyboardKey.arrowRight) _keyRight = 0;
      if (key == LogicalKeyboardKey.keyJ) scene.releaseAttack();
      if (key == LogicalKeyboardKey.arrowUp ||
          key == LogicalKeyboardKey.space) {
        scene.inp.jumpHeld = false;
      }
      return KeyEventResult.ignored;
    }
    if (_paused || e is KeyRepeatEvent || !down) return KeyEventResult.ignored;
    if (key == LogicalKeyboardKey.arrowLeft) {
      _keyLeft = 1;
    } else if (key == LogicalKeyboardKey.arrowRight) {
      _keyRight = 1;
    } else if (key == LogicalKeyboardKey.arrowUp ||
        key == LogicalKeyboardKey.space) {
      scene.pressJump();
    } else if (key == LogicalKeyboardKey.keyJ) {
      scene.pressAttack();
    } else if (key == LogicalKeyboardKey.keyK) {
      scene.pressSpell();
    } else if (key == LogicalKeyboardKey.keyL) {
      scene.pressFriend();
    } else if (key == LogicalKeyboardKey.semicolon) {
      scene.pressSuper();
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  // ---------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return ColoredBox(
      color: const Color(0xFF130B07),
      child: LayoutBuilder(
        builder: (context, box) {
          final size = box.biggest;
          final scene = _sceneFor(size, media.padding);
          return Focus(
            focusNode: _focus,
            autofocus: true,
            onKeyEvent: _key,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Listener(
                  behavior: HitTestBehavior.opaque,
                  onPointerDown: _down,
                  onPointerMove: _move,
                  onPointerUp: _up,
                  onPointerCancel: _up,
                  child: RepaintBoundary(
                    child: CustomPaint(
                      key: const Key('brawl-canvas'),
                      painter: BrawlWorldPainter(scene),
                      foregroundPainter: BrawlHudPainter(scene),
                      size: size,
                    ),
                  ),
                ),
                _ControlWords(scene: scene, onQuit: widget.onQuit),
                Positioned(
                  left: 0,
                  right: 0,
                  top: (scene.layout.hudTop + 98) * scene.layout.scale,
                  child: _ToastLine(scene: scene),
                ),
                _TopButtons(
                  scene: scene,
                  paused: _paused,
                  sound: _sound,
                  top: scene.layout.hudTop * scene.layout.scale,
                  onPause: () => _setPaused(true),
                  onSound: () {
                    setState(() => _sound = !_sound);
                    widget.onSoundChanged?.call(_sound);
                  },
                ),
                if (_paused)
                  _PauseSheet(
                    sound: _sound,
                    onResume: () => _setPaused(false),
                    onQuit: widget.onQuit,
                    onSound: () {
                      setState(() => _sound = !_sound);
                      widget.onSoundChanged?.call(_sound);
                    },
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Transparent widgets over the painted controls, carrying their words.
class _ControlWords extends StatelessWidget {
  const _ControlWords({required this.scene, required this.onQuit});

  final BrawlScene scene;
  final VoidCallback onQuit;

  Widget _at(BrawlCircle c, Widget child, double pad) {
    final s = scene.layout.scale;
    final r = (c.r + pad) * s;
    return Positioned(
      left: c.x * s - r,
      top: c.y * s - r,
      width: r * 2,
      height: r * 2,
      child: child,
    );
  }

  Widget _node(
    String label, {
    VoidCallback? onTap,
    bool enabled = true,
    String? hint,
    VoidCallback? onLongPress,
  }) => Semantics(
    button: true,
    enabled: enabled,
    label: label,
    hint: hint,
    onTap: onTap,
    onLongPress: onLongPress,
    excludeSemantics: true,
    child: const SizedBox.expand(),
  );

  @override
  Widget build(BuildContext context) {
    final lay = scene.layout;
    return ValueListenableBuilder<BrawlControlsState>(
      valueListenable: scene.controls,
      builder: (context, st, _) {
        String ability(String name, bool on, bool ready, Stat stat) {
          if (!on) return 'Locked. ${lockedLine(stat)}';
          return ready ? '$name, ready' : '$name, recharging';
        }

        final attackLabel = st.daze
            ? 'Finish it!'
            : st.easy
            ? 'Attack. Tap anywhere on the stage'
            : st.slamReady
            ? 'Attack. Tap for a combo, hold for Power Slam. Power Slam is ready'
            : 'Attack. Tap for a combo';
        final spell = st.easy ? lay.eSpell : lay.spell;
        final friend = st.easy ? lay.eFriend : lay.friend;
        final sup = st.easy ? lay.eSup : lay.sup;
        return Stack(
          children: [
            _at(
              st.easy ? lay.eFinish : lay.attack,
              _node(
                attackLabel,
                enabled: !st.over,
                onTap: () {
                  if (st.daze) {
                    scene.inp
                      ..pFinish = true
                      ..pAtk = true;
                  } else {
                    scene.inp.pAtk = true;
                  }
                },
                onLongPress: st.daze
                    ? null
                    : () {
                        scene.inp
                          ..pAtk = true
                          ..attackHeld = true;
                        Future<void>.delayed(
                          const Duration(milliseconds: 900),
                          scene.releaseAttack,
                        );
                      },
              ),
              0,
            ),
            _at(
              spell,
              _node(
                ability('Spell Bolt', st.spellOn, st.spellReady, Stat.intl),
                enabled: !st.over,
                onTap: scene.pressSpell,
              ),
              4,
            ),
            _at(
              friend,
              _node(
                ability('Call a Friend', st.friendOn, st.friendReady, Stat.soc),
                enabled: !st.over,
                onTap: scene.pressFriend,
              ),
              4,
            ),
            _at(
              sup,
              _node(
                st.supOn
                    ? (st.supReady
                          ? 'Super, ready'
                          : 'Super, ${st.supPercent} percent')
                    : 'Locked. ${lockedLine(Stat.dis)}',
                enabled: !st.over,
                onTap: scene.pressSuper,
              ),
              4,
            ),
            if (!st.easy) ...[
              _at(
                lay.pad,
                Semantics(
                  label:
                      'Move pad. Slide left or right to move, swipe up to jump',
                  onIncrease: () => _nudge(1),
                  onDecrease: () => _nudge(-1),
                  customSemanticsActions: {
                    const CustomSemanticsAction(label: 'Jump'): scene.pressJump,
                  },
                  excludeSemantics: true,
                  child: const SizedBox.expand(),
                ),
                0,
              ),
            ],
            Positioned(
              left: 0,
              top: 0,
              width: 1,
              height: 1,
              child: ValueListenableBuilder<String>(
                valueListenable: scene.announcerText,
                builder: (context, text, _) => Semantics(
                  liveRegion: true,
                  label: text,
                  child: const SizedBox.shrink(),
                ),
              ),
            ),
            Positioned(
              left: 0,
              top: 0,
              width: 1,
              height: 1,
              child: ValueListenableBuilder<String>(
                valueListenable: scene.status,
                builder: (context, text, _) =>
                    Semantics(label: text, child: const SizedBox.shrink()),
              ),
            ),
          ],
        );
      },
    );
  }

  void _nudge(double dir) {
    scene.touch.padMove = dir;
    Future<void>.delayed(const Duration(milliseconds: 420), () {
      if (scene.touch.padMove == dir) scene.touch.padMove = 0;
    });
  }
}

class _ToastLine extends StatelessWidget {
  const _ToastLine({required this.scene});
  final BrawlScene scene;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<String?>(
    valueListenable: scene.toast,
    builder: (context, text, _) => IgnorePointer(
      child: AnimatedOpacity(
        opacity: text == null ? 0 : 1,
        duration: const Duration(milliseconds: 220),
        child: Center(
          child: Semantics(
            liveRegion: true,
            label: text ?? '',
            child: Container(
              key: const Key('brawl-toast'),
              margin: const EdgeInsets.symmetric(horizontal: 24),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
              decoration: BoxDecoration(
                color: const Color(0xCC140C06),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: const Color(0xFFE5C896).withValues(alpha: 0.35),
                ),
              ),
              child: ExcludeSemantics(
                child: Text(
                  text ?? ' ',
                  textAlign: TextAlign.center,
                  style: Type.body.copyWith(
                    fontSize: 15,
                    color: const Color(0xFFFFF4D9),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _TopButtons extends StatelessWidget {
  const _TopButtons({
    required this.scene,
    required this.paused,
    required this.sound,
    required this.top,
    required this.onPause,
    required this.onSound,
  });

  final BrawlScene scene;
  final bool paused;
  final bool sound;
  final double top;
  final VoidCallback onPause;
  final VoidCallback onSound;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 4,
      right: 4,
      top: top + 4,
      child: Row(
        children: [
          _RoundButton(
            key: const Key('brawl-pause'),
            icon: Icons.pause_rounded,
            label: 'Pause',
            onTap: onPause,
          ),
          const Spacer(),
          _RoundButton(
            key: const Key('brawl-sound'),
            icon: sound ? Icons.volume_up_rounded : Icons.volume_off_rounded,
            label: sound
                ? 'Sound on. Tap to mute'
                : 'Sound off. Tap to turn on',
            onTap: onSound,
          ),
        ],
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Pressable(
    pressDepth: 1,
    edgeColor: Colors.transparent,
    borderRadius: BorderRadius.circular(22),
    material: MaterialSound.brass,
    interactionSound: InteractionSound.select,
    semanticLabel: label,
    onTapUp: (_) => onTap(),
    child: SizedBox(
      width: 44,
      height: 44,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const RadialGradient(
            center: Alignment(-0.3, -0.4),
            colors: [Color(0x38FFE2AA), Color(0xD1180E08)],
          ),
          border: Border.all(color: const Color(0x57FFE2AA)),
        ),
        child: ExcludeSemantics(
          child: Icon(icon, size: 20, color: const Color(0xFFFFF4D9)),
        ),
      ),
    ),
  );
}

class _PauseSheet extends StatelessWidget {
  const _PauseSheet({
    required this.sound,
    required this.onResume,
    required this.onQuit,
    required this.onSound,
  });

  final bool sound;
  final VoidCallback onResume;
  final VoidCallback onQuit;
  final VoidCallback onSound;

  @override
  Widget build(BuildContext context) {
    Widget action(
      String label,
      VoidCallback onTap, {
      bool primary = false,
      Key? key,
    }) => Pressable(
      key: key,
      pressDepth: 1,
      edgeColor: Colors.transparent,
      borderRadius: BorderRadius.circular(26),
      material: MaterialSound.brass,
      interactionSound: InteractionSound.select,
      semanticLabel: label,
      onTapUp: (_) => onTap(),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 52, minWidth: 220),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            gradient: primary
                ? const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFFF7D68E), Color(0xFFD9A24F)],
                  )
                : null,
            color: primary ? null : const Color(0x33FFE2AA),
            border: Border.all(color: const Color(0x66FFE2AA)),
          ),
          child: Center(
            child: ExcludeSemantics(
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: Type.display.copyWith(
                  fontFamily: 'EBGaramond',
                  fontSize: 20,
                  color: primary ? const Color(0xFF3A1D08) : Palette.textHi,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    return Positioned.fill(
      child: ColoredBox(
        key: const Key('brawl-paused'),
        color: const Color(0xCC0F0804),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Semantics(
                    header: true,
                    child: Text(
                      'Paused',
                      style: Type.display.copyWith(
                        fontFamily: 'EBGaramond',
                        fontSize: 34,
                        fontWeight: FontWeight.w700,
                        color: Palette.textHi,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Take your time. The fight waits for you.',
                    textAlign: TextAlign.center,
                    style: Type.body.copyWith(
                      fontSize: 15,
                      color: Palette.textMid,
                    ),
                  ),
                  const SizedBox(height: 22),
                  action(
                    'Keep fighting',
                    onResume,
                    primary: true,
                    key: const Key('brawl-resume'),
                  ),
                  const SizedBox(height: 12),
                  action(
                    sound ? 'Sound on' : 'Sound off',
                    onSound,
                    key: const Key('brawl-pause-sound'),
                  ),
                  const SizedBox(height: 12),
                  action(
                    'Leave the fight',
                    onQuit,
                    key: const Key('brawl-quit'),
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
