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
      {this.haptic = false, this.wide = false});
  final String text;
  final IconData icon;
  final Color color;
  final String? sound;
  final bool haptic;
  final bool wide;
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
      _Bubble('+${b.xp} XP', Icons.bolt, Palette.xp, null),
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
            Icons.flash_on, Palette.unlock, 'crit', haptic: true),
      if (b.loot != null)
        _Bubble(
            '${(cosmeticFor(b.loot)?.rarity ?? Rarity.common) == Rarity.rare ? "RARE" : "LOOT"} · ${b.loot}',
            Icons.card_giftcard,
            rarityColor(cosmeticFor(b.loot)?.rarity ?? Rarity.common),
            'loot'),
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

    return Positioned(
      left: (widget.anchor.dx - 110).clamp(8.0, screen.width - 228),
      top: (widget.anchor.dy - 60.0 * (_bubbles.length + 1))
          .clamp(8.0, screen.height - 300),
      child: OverlaySurface(
        child: IgnorePointer(
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            final elapsed = _c.value * totalMs;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < _bubbles.length; i++)
                  _bubbleView(_bubbles[i], elapsed - i * staggerMs, totalMs),
              ],
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
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            constraints: BoxConstraints(maxWidth: b.wide ? 230 : 220),
            decoration: BoxDecoration(
              color: Palette.card.withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: b.color.withValues(alpha: 0.55)),
              boxShadow: [
                BoxShadow(
                  color: b.color.withValues(alpha: 0.22),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(b.icon, size: b.wide ? 13 : 16, color: b.color),
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
                          style: Type.numerals
                              .copyWith(fontSize: 13, color: b.color),
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
