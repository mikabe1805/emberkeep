import '../engine.dart';
import 'achievements.dart';

/// Window views (round-49) — the landscape outside your room's window (the
/// owner's "landscape behind avatar"). Bought/applied with embers, exclusive
/// like room styles. Painted in code (widgets/home_room.dart paintWindowScene);
/// each [id] is the contract the painter switches on. The free default 'moon'
/// is always owned.
class WindowView {
  const WindowView({
    required this.id,
    required this.name,
    required this.price,
    this.requires,
  });

  final String id;
  final String name;
  final int price;
  final String? requires;
}

final windowViews = <WindowView>[
  const WindowView(id: 'moon', name: 'Moonlit Night', price: 0),
  const WindowView(id: 'city', name: 'City Lights', price: 140),
  const WindowView(id: 'forest', name: 'Pine Forest', price: 160),
  const WindowView(id: 'mountains', name: 'Far Mountains', price: 180),
  const WindowView(id: 'rain', name: 'Rainy Night', price: 200),
  const WindowView(
      id: 'dawn', name: 'First Light', price: 220, requires: 'dawn-patrol'),
  const WindowView(
      id: 'aurora', name: 'Aurora', price: 280, requires: 'month-of-fire'),
];

WindowView? windowViewById(String id) {
  for (final v in windowViews) {
    if (v.id == id) return v;
  }
  return null;
}

bool isWindowOwned(GameState s, WindowView v) =>
    v.price == 0 || s.ownedWindows.contains(v.id);

bool isWindowApplied(GameState s, WindowView v) => s.windowScene == v.id;

bool windowUnlocked(WindowView v, GameState s) =>
    v.requires == null || s.unlockedAchievements.contains(v.requires);

String? windowGateLabel(WindowView v) {
  if (v.requires == null) return null;
  for (final a in achievements) {
    if (a.id == v.requires) return a.title;
  }
  return 'a trophy';
}
