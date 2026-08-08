import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import '../audio.dart';
import '../content/creature_skins.dart';
import '../content/room_styles.dart';
import '../content/weekly_chronicle.dart';
import '../engine.dart';
import '../models.dart';
import '../platform/share_stub.dart'
    if (dart.library.js_interop) '../platform/share_web.dart';
import '../tokens.dart';
import '../widgets/detail_header.dart';
import '../widgets/constellation.dart';
import '../widgets/facets.dart';
import '../widgets/glass.dart';
import '../widgets/home_room.dart';
import '../widgets/morrow_tapestry_glyph.dart';

class WeeklyChronicleScreen extends StatefulWidget {
  const WeeklyChronicleScreen({super.key, required this.state});
  final GameState state;

  @override
  State<WeeklyChronicleScreen> createState() => _WeeklyChronicleScreenState();
}

class _WeeklyChronicleScreenState extends State<WeeklyChronicleScreen> {
  final _cardKey = GlobalKey();
  bool _includeReflection = false;
  bool _busy = false;

  WeeklyChronicleData get _data => weeklyChronicleFor(widget.state);

  Future<void> _share() async {
    if (_busy) return;
    setState(() => _busy = true);
    final data = _data;
    try {
      final boundary =
          _cardKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      final ok =
          bytes != null &&
          await sharePng(
            bytes.buffer.asUint8List(),
            'room-of-days-weekly-chronicle.png',
            '${data.shareText} — Room of Days',
          );
      if (!mounted) return;
      Sfx.instance.play(ok ? 'streak' : 'boing');
      if (!ok) _copySummary();
    } catch (_) {
      if (mounted) _copySummary();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _copySummary() {
    Clipboard.setData(ClipboardData(text: '${_data.shareText} — Room of Days'));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Palette.card,
        content: Text(
          'Chronicle copied — the image can be shared from a native build.',
          style: Type.body.copyWith(color: Palette.textHi),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    final canReflect = data.reflection != null;
    return Scaffold(
      backgroundColor: Palette.parchment,
      body: WarmBackground(
        themeId: widget.state.canvasTheme,
        tint: Palette.streak,
        reduceMotion: widget.state.reduceMotion,
        child: SafeArea(
          child: Column(
            children: [
              const DetailHeader(
                title: 'Your Week',
                subtitle: 'a shareable page from the life behind your space',
                accent: Palette.xp,
                pill: '9:16',
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 40),
                  children: [
                    RepaintBoundary(
                      key: _cardKey,
                      child: AspectRatio(
                        aspectRatio: 9 / 16,
                        child: _ChronicleCard(
                          state: widget.state,
                          data: data,
                          includeReflection: _includeReflection,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    if (canReflect)
                      _PrivacyChoice(
                        selected: _includeReflection,
                        onChanged: (value) {
                          Sfx.instance.play('tick');
                          HapticFeedback.selectionClick();
                          setState(() => _includeReflection = value);
                        },
                      )
                    else
                      Text(
                        'Write during the week and you can optionally place one private line in a future Chronicle.',
                        textAlign: TextAlign.center,
                        style: Type.body.copyWith(
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                          color: Palette.textLo,
                        ),
                      ),
                    const SizedBox(height: 14),
                    _HoneyButton(
                      label: _busy ? 'PREPARING…' : 'SHARE CHRONICLE',
                      onTap: _share,
                    ),
                    const SizedBox(height: 9),
                    Text(
                      'Journal words are excluded unless you explicitly include them above.',
                      textAlign: TextAlign.center,
                      style: Type.body.copyWith(
                        fontSize: 11,
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

class _ChronicleCard extends StatelessWidget {
  const _ChronicleCard({
    required this.state,
    required this.data,
    required this.includeReflection,
  });

  final GameState state;
  final WeeklyChronicleData data;
  final bool includeReflection;

  @override
  Widget build(BuildContext context) {
    final accent = state.dominantStat?.color ?? Palette.xpLight;
    final reflection = data.reflection;
    final weekHistory = <String, int>{
      for (var i = 0; i < data.counts.length; i++)
        if (data.counts[i] > 0)
          Days.key(data.start.add(Duration(days: i))): data.counts[i],
    };
    return ClipPath(
      clipper: const FacetedClipper(cut: 16),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF3A281F), Color(0xFF221717), Color(0xFF130E0D)],
          ),
        ),
        child: Stack(
          children: [
            const Positioned.fill(child: _ChroniclePlanes()),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 19, 20, 17),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      MorrowTapestryGlyph(
                        level: state.level,
                        lit: state.streakDays > 0,
                        reduceMotion: true,
                        size: 26,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'YOUR WEEK',
                              style: Type.label.copyWith(
                                fontSize: Type.minLabel,
                                color: Palette.xpLight,
                              ),
                            ),
                            Text(
                              data.rangeLabel,
                              style: Type.label.copyWith(
                                fontSize: Type.minLabel,
                                color: Palette.textLo,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        'LV ${state.level}',
                        style: Type.label.copyWith(
                          fontSize: Type.minLabel,
                          color: accent,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 13),
                  ClipPath(
                    clipper: const FacetedClipper(cut: 10),
                    child: SizedBox(
                      height: 122,
                      child: HomeRoom(
                        lively: false,
                        level: state.level,
                        unlocked: state.ownedFurniture,
                        wall: wallColorsFor(state),
                        plateId: state.wallStyle,
                        floor: floorColorsFor(state),
                        window: state.windowScene,
                        petAwake: data.litDays > 0,
                        emberGlow: flameHueFor(state),
                        heirloomFlame: heirloomFlameFor(state),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    data.total == 0
                        ? 'A quiet chapter'
                        : '${data.total} ${data.total == 1 ? 'quest' : 'quests'} became progress',
                    textAlign: TextAlign.center,
                    style: Type.display.copyWith(
                      fontSize: 23,
                      height: 1.04,
                      color: Palette.textHi,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '${data.litDays} OF 7 DAYS ACTIVE · ${data.deltaLine.toUpperCase()}',
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    style: Type.label.copyWith(
                      fontSize: Type.minLabel,
                      height: 1.35,
                      color: Palette.textLo,
                    ),
                  ),
                  const SizedBox(height: 13),
                  _WeekRunes(data: data, accent: accent),
                  const SizedBox(height: 13),
                  if (includeReflection && reflection != null)
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: facetedDecoration(
                          cut: 9,
                          color: Palette.glassFill,
                          borderColor: accent.withValues(alpha: 0.32),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'A LINE I KEPT',
                              style: Type.label.copyWith(
                                fontSize: Type.minLabel,
                                color: accent,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              '“${chronicleExcerpt(reflection.text)}”',
                              textAlign: TextAlign.center,
                              maxLines: 4,
                              overflow: TextOverflow.ellipsis,
                              style: Type.body.copyWith(
                                fontSize: 11.5,
                                height: 1.35,
                                fontStyle: FontStyle.italic,
                                color: Palette.textMid,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    Expanded(
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Positioned.fill(
                            child: Opacity(
                              opacity: 0.62,
                              child: HistorySky(
                                history: weekHistory,
                                ember: flameHueFor(state),
                                reduceMotion: true,
                              ),
                            ),
                          ),
                          Align(
                            alignment: const Alignment(0, 0.72),
                            child: _DomainSeal(
                              stat: data.strongestDomain,
                              accent: accent,
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 9),
                  Text(
                    state.buildTitle,
                    textAlign: TextAlign.center,
                    style: Type.label.copyWith(
                      fontSize: Type.minLabel,
                      color: accent,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${state.totalXp} XP OF REAL LIFE · ROOM OF DAYS',
                    textAlign: TextAlign.center,
                    style: Type.label.copyWith(
                      fontSize: Type.minLabel,
                      color: Palette.textLo,
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

class _ChroniclePlanes extends StatelessWidget {
  const _ChroniclePlanes();

  @override
  Widget build(BuildContext context) => CustomPaint(painter: _PlanesPainter());
}

class _PlanesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      Path()
        ..moveTo(0, 0)
        ..lineTo(size.width * 0.58, 0)
        ..lineTo(size.width * 0.22, size.height)
        ..lineTo(0, size.height)
        ..close(),
      Paint()..color = Colors.white.withValues(alpha: 0.025),
    );
    canvas.drawPath(
      Path()
        ..moveTo(size.width * 0.72, 0)
        ..lineTo(size.width, 0)
        ..lineTo(size.width, size.height)
        ..lineTo(size.width * 0.48, size.height)
        ..close(),
      Paint()..color = Colors.black.withValues(alpha: 0.09),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _WeekRunes extends StatelessWidget {
  const _WeekRunes({required this.data, required this.accent});
  final WeeklyChronicleData data;
  final Color accent;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      for (var i = 0; i < 7; i++)
        Column(
          children: [
            Text(
              const ['M', 'T', 'W', 'T', 'F', 'S', 'S'][i],
              style: Type.label.copyWith(
                fontSize: Type.minLabel,
                color: Palette.textLo,
              ),
            ),
            const SizedBox(height: 5),
            Transform.rotate(
              angle: 0.785,
              child: Container(
                width: data.counts[i] > 0 ? 15 : 11,
                height: data.counts[i] > 0 ? 15 : 11,
                decoration: BoxDecoration(
                  color: data.counts[i] > 0
                      ? accent.withValues(alpha: 0.82)
                      : Palette.glassFill,
                  border: Border.all(
                    color: data.counts[i] > 0
                        ? Palette.specular.withValues(alpha: 0.34)
                        : Palette.glassEdge,
                  ),
                  boxShadow: data.counts[i] > 0
                      ? [
                          BoxShadow(
                            color: accent.withValues(alpha: 0.32),
                            blurRadius: 7,
                          ),
                        ]
                      : null,
                ),
              ),
            ),
          ],
        ),
    ],
  );
}

class _DomainSeal extends StatelessWidget {
  const _DomainSeal({required this.stat, required this.accent});
  final Stat? stat;
  final Color accent;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
    decoration: facetedDecoration(
      cut: 9,
      color: accent.withValues(alpha: 0.1),
      borderColor: accent.withValues(alpha: 0.34),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          stat == null ? 'FIRST PAGE' : '${stat!.abbr} BURNED BRIGHTEST',
          style: Type.label.copyWith(fontSize: Type.minLabel, color: accent),
        ),
        const SizedBox(height: 3),
        Text(
          stat?.blurb ?? 'Complete a quest to see your leading area here.',
          textAlign: TextAlign.center,
          style: Type.body.copyWith(fontSize: 10.5, color: Palette.textLo),
        ),
      ],
    ),
  );
}

class _PrivacyChoice extends StatelessWidget {
  const _PrivacyChoice({required this.selected, required this.onChanged});
  final bool selected;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: () => onChanged(!selected),
    child: GlassPanel(
      padding: const EdgeInsets.all(13),
      child: Row(
        children: [
          Icon(
            selected ? Icons.check_box_outlined : Icons.check_box_outline_blank,
            size: 21,
            color: selected ? Palette.xpLight : Palette.textLo,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Include one journal line',
                  style: Type.body.copyWith(
                    fontSize: 13.5,
                    color: Palette.textHi,
                  ),
                ),
                Text(
                  'off by default · previewed before sharing',
                  style: Type.body.copyWith(
                    fontSize: 11,
                    color: Palette.textLo,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.lock_outline, size: 16, color: Palette.textLo),
        ],
      ),
    ),
  );
}

class _HoneyButton extends StatelessWidget {
  const _HoneyButton({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: onTap,
    child: Container(
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
          fontSize: 11.5,
          letterSpacing: 1.4,
          color: Palette.onHoney,
        ),
      ),
    ),
  );
}
