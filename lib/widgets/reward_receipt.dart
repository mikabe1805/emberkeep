import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../audio.dart';
import '../content/cosmetics.dart';
import '../models.dart';
import '../tokens.dart';
import 'glass.dart';

/// The "receipt of rewards": a vertical stack of color-coded bubbles popping
/// in one by one near the completed quest — one tap can deliver 2–6 distinct
/// micro-rewards, each with its own color, icon and sound layer
/// (Habitica's best pattern, modernized — DESIGN.md §3).
class RewardReceipt extends StatefulWidget {
  const RewardReceipt({
    super.key,
    required this.bundle,
    required this.anchor,
    required this.onDone,
  });

  final RewardBundle bundle;

  /// Global position of the completing tap; bubbles rise above it.
  final Offset anchor;
  final VoidCallback onDone;

  @override
  State<RewardReceipt> createState() => _RewardReceiptState();
}

class _Bubble {
  _Bubble(this.text, this.icon, this.color, this.sound,
      {this.haptic = false, this.wide = false, this.hero = false});
  final String text;
  final IconData icon;
  final Color color;
  final String? sound;
  final bool haptic;
  final bool wide;

  /// The headline rewards (XP, crit, loot) — rendered larger, the joy
  /// hierarchy made visible rather than every pill the same weight.
  final bool hero;
}

class _RewardReceiptState extends State<RewardReceipt>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final List<_Bubble> _bubbles;

  @override
  void initState() {
    super.initState();
    final b = widget.bundle;
    _bubbles = [
      if (b.firstOfDay)
        _Bubble('FIRST EMBER OF THE DAY 🔥', Icons.local_fire_department,
            Palette.streak, 'streak'),
      _Bubble('+${b.xp} XP', Icons.bolt, Palette.xp, null, hero: true),
      // per-stat pitched blip (§8: pitch varies by stat)
      _Bubble('+${b.statGain} ${b.stat.abbr}', Icons.trending_up,
          b.stat.color, 'stat_${b.stat.index}'),
      if (b.verifiedMult != null)
        _Bubble('VERIFIED ×${b.verifiedMult!.toStringAsFixed(1)}',
            Icons.verified, Palette.verify, null),
      if (b.streakMult != null)
        _Bubble('STREAK ×${b.streakMult!.toStringAsFixed(1)}',
            Icons.local_fire_department, Palette.streak, 'streak'),
      if (b.comebackMult != null)
        _Bubble('WELCOME BACK ×${b.comebackMult!.toStringAsFixed(1)}',
            Icons.local_fire_department, Palette.streak, 'streak'),
      if (b.shieldHeld)
        _Bubble('STREAK SAFE 🛡️', Icons.shield, Palette.verify, 'streak'),
      if (b.critMult != null)
        _Bubble('CRITICAL! ×${b.critMult!.toStringAsFixed(1)}',
            Icons.flash_on, Palette.unlock, 'crit',
            haptic: true, hero: true),
      if (b.loot != null)
        _Bubble(
            '${(cosmeticFor(b.loot)?.rarity ?? Rarity.common) == Rarity.rare ? "RARE" : "LOOT"} · ${b.loot}',
            Icons.card_giftcard,
            rarityColor(cosmeticFor(b.loot)?.rarity ?? Rarity.common),
            'loot',
            hero: true),
      // the personal voice — last, wider, no sound (DESIGN.md §11.2)
      _Bubble(b.message, Icons.favorite, b.stat.color, null, wide: true),
    ];

    final total = Motion.bubbleLife +
        Motion.bubbleStagger * _bubbles.length;
    _c = AnimationController(vsync: this, duration: total)
      ..addStatusListener((s) {
        if (s == AnimationStatus.completed) widget.onDone();
      })
      ..forward();

    // sound/haptic layers fire on each bubble's entrance beat
    for (var i = 0; i < _bubbles.length; i++) {
      final bubble = _bubbles[i];
      if (bubble.sound == null && !bubble.haptic) continue;
      Future.delayed(Motion.bubbleStagger * i, () {
        if (!mounted) return;
        if (bubble.sound != null) Sfx.instance.play(bubble.sound!);
        if (bubble.haptic) {
          // composed double-tap: stronger than routine, smaller than level-up
          HapticFeedback.heavyImpact();
          Future.delayed(const Duration(milliseconds: 90), () {
            if (mounted) HapticFeedback.mediumImpact();
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);
    final totalMs = _c.duration!.inMilliseconds.toDouble();
    final staggerMs = Motion.bubbleStagger.inMilliseconds.toDouble();

    // Keep the whole bubble stack on screen: estimate its height and clamp the
    // top so the bottom never runs off the bottom edge (stack can be ~10 tall).
    final stackH = 60.0 * _bubbles.length;
    final top = (widget.anchor.dy - stackH)
        .clamp(8.0, (screen.height - stackH - 16).clamp(8.0, screen.height));

    return Positioned(
      left: (widget.anchor.dx - 110).clamp(8.0, screen.width - 228),
      top: top,
      child: OverlaySurface(
        child: IgnorePointer(
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            final elapsed = _c.value * totalMs;
            return ConstrainedBox(
              constraints: BoxConstraints(maxHeight: screen.height - 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < _bubbles.length; i++)
                    _bubbleView(_bubbles[i], elapsed - i * staggerMs, totalMs),
                ],
              ),
            );
          },
        ),
      ),
      ),
    );
  }

  Widget _bubbleView(_Bubble b, double localMs, double totalMs) {
    // entrance: 220ms pop (ease-out-back); exit: shared fade at the end
    final enter = (localMs / 220).clamp(0.0, 1.0);
    if (enter <= 0) return const SizedBox(height: 44);
    final scale = Curves.easeOutBack.transform(enter);
    final fadeStart = totalMs - 350;
    final exit = ((_c.value * totalMs - fadeStart) / 350).clamp(0.0, 1.0);

    return Opacity(
      opacity: (enter * (1 - exit)).clamp(0.0, 1.0),
      child: Transform.translate(
        offset: Offset(0, (1 - scale) * 14 - 18 * exit),
        child: Transform.scale(
          scale: 0.6 + 0.4 * scale,
          alignment: Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: EdgeInsets.symmetric(
                horizontal: 13, vertical: b.hero ? 10 : 8),
            constraints: BoxConstraints(maxWidth: b.wide ? 230 : 220),
            decoration: BoxDecoration(
              // each bubble glows its OWN colour (a tint of the espresso base),
              // brighter at the top — a little gem of light, not a brown pill
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color.alphaBlend(
                      b.color.withValues(alpha: b.hero ? 0.30 : 0.20),
                      Palette.card),
                  Color.alphaBlend(
                      b.color.withValues(alpha: 0.10), Palette.card),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: b.color.withValues(alpha: b.hero ? 0.85 : 0.6),
                  width: b.hero ? 1.4 : 1.0),
              boxShadow: [
                BoxShadow(
                  color: b.color.withValues(alpha: b.hero ? 0.40 : 0.22),
                  blurRadius: b.hero ? 18 : 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              // wide message wraps to multiple lines; keep the icon on the
              // first line rather than vertically centered across the block.
              crossAxisAlignment: b.wide
                  ? CrossAxisAlignment.start
                  : CrossAxisAlignment.center,
              children: [
                Icon(b.icon,
                    size: b.wide
                        ? 13
                        : b.hero
                            ? 19
                            : 16,
                    color: b.color),
                const SizedBox(width: 6),
                Flexible(
                  child: b.wide
                      ? Text(
                          b.text,
                          style: Type.body.copyWith(
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                              color: Palette.textMid),
                        )
                      : Text(
                          b.text,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Type.numerals.copyWith(
                              fontSize: b.hero ? 18 : 13, color: b.color),
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
