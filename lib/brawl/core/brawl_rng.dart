import 'dart:math' as math;

/// The weekend brawl's random numbers: mulberry32, the same generator the
/// prototype used, so a seed means the same fight everywhere.
///
/// It is written with explicit 32-bit masks (and a split multiply) so the
/// stream is identical on the VM, on iOS and on the web, where integers are
/// doubles.
final class BrawlRng {
  BrawlRng(int seed) : _a = seed & _mask;

  static const int _mask = 0xFFFFFFFF;
  int _a;

  /// A number in [0, 1).
  double next() {
    _a = (_a + 0x6D2B79F5) & _mask;
    var t = brawlImul(_a ^ (_a >> 15), 1 | _a);
    t = ((t + brawlImul(t ^ (t >> 7), 61 | t)) ^ t) & _mask;
    return ((t ^ (t >> 14)) & _mask) / 4294967296.0;
  }

  /// A number in [lo, hi).
  double range(double lo, double hi) => lo + (hi - lo) * next();

  /// A bell-curve number with mean 0 and spread 1 (Box-Muller).
  double gauss() {
    final u = 1 - next();
    final v = next();
    return math.sqrt(-2 * math.log(u)) * math.cos(2 * math.pi * v);
  }
}

/// 32-bit integer multiply (JavaScript's Math.imul) for unsigned inputs,
/// safe where 64-bit integers are not available.
int brawlImul(int a, int b) {
  final ah = (a >> 16) & 0xFFFF;
  final al = a & 0xFFFF;
  final bh = (b >> 16) & 0xFFFF;
  final bl = b & 0xFFFF;
  return ((al * bl) + ((((ah * bl) + (al * bh)) & 0xFFFF) << 16)) & 0xFFFFFFFF;
}
