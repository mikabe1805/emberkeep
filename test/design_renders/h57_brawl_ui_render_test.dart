// The weekend brawl's screens, through the real app, at 393 x 852 and 3x
// (PNGs 1179 x 2556). Skipped unless asked for:
//
//   flutter test --dart-define=H57_BRAWL=true \
//     test/design_renders/h57_brawl_ui_render_test.dart
//
// H57_ONLY=door,versus,fight,victory,easy picks groups; H57_OUT=<folder>
// writes somewhere else. Output: design/comparisons/2026-10-14/h57-brawl-ui/
// in this checkout.
import 'package:emberkeep/a11y.dart' show appTextScale;
import 'package:emberkeep/brawl/brawl_loot.dart';
import 'package:emberkeep/brawl/core/brawl_core.dart';
import 'package:emberkeep/brawl/ui/brawl_flow.dart';
import 'package:emberkeep/brawl/ui/brawl_fight_screen.dart';
import 'package:emberkeep/clock.dart';
import 'package:emberkeep/content/day_planning.dart';
import 'package:emberkeep/models.dart';
import 'package:emberkeep/screens/quests.dart' show QuestsPage;
import 'package:emberkeep/tokens.dart' show Stat;
import 'package:emberkeep/widgets/class_day/doorway_art.dart';
import 'package:emberkeep/widgets/house/house_room.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'class_day_harness.dart';

const _renders = bool.fromEnvironment('H57_BRAWL');
const _only = String.fromEnvironment('H57_ONLY');
bool _wants(String name) =>
    _only.isEmpty || _only.split(',').map((s) => s.trim()).contains(name);

const _out = String.fromEnvironment(
  'H57_OUT',
  defaultValue:
      'C:/Users/mikus/Downloads/experimentProject/app/.worktrees/house-quests/'
      'design/comparisons/2026-10-14/h57-brawl-ui',
);

/// Saturday 2026-10-03 is in an even week (the Couch Troll); Saturday
/// 2026-10-10 is in an odd one (the Fog); Friday 2026-10-09 has no classes.
DateTime _at(int day, int hour, int minute) =>
    DateTime(2026, 10, day, hour, minute);

final _schedule = mikaSchedule();

List<String> get _plates => {
  for (final set in [
    HousePlateSets.me,
    HousePlateSets.goals,
    HousePlateSets.plansDay,
    HousePlateSets.plansMonth,
    HousePlateSets.journal,
  ])
    ...set.all,
}.toList();

/// This week's quests finished, as the engine records them: [points] per stat.
void _train(MikaAccount account, DateTime at, Map<Stat, int> points) {
  final monday = DateTime(at.year, at.month, at.day - (at.weekday - 1), 9);
  var n = 0;
  points.forEach((stat, count) {
    for (var i = 0; i < count; i++) {
      account.state.markTraining(
        stat,
        at: monday.add(Duration(hours: n++ % 40, minutes: i)),
        timerProven: i % 4 == 3,
      );
    }
  });
}

const _quietWeek = <Stat, int>{};
const _bigWeek = <Stat, int>{
  Stat.str: 7,
  Stat.vit: 6,
  Stat.intl: 8,
  Stat.foc: 6,
  Stat.soc: 5,
  Stat.dis: 7,
};

Future<MikaAccount> _boot(
  WidgetTester tester,
  DateTime at, {
  Map<Stat, int> week = _quietWeek,
  bool reduceMotion = false,
  bool easy = false,
  double textScale = 1,
}) async {
  final account = mikaAccount(renderAt: at, reduceMotion: reduceMotion);
  account.state.brawlEasy = easy;
  account.state.textScale = textScale;
  account.state.musicEnabled = false;
  account.state.notifyEnabled = false;
  account.quests
    ..add(Quest(title: 'Practice guitar', stat: Stat.foc, difficulty: 2))
    ..add(Quest(title: 'Review one problem', stat: Stat.foc, difficulty: 3))
    ..add(Quest(title: 'Write for today', stat: Stat.dis, difficulty: 2));
  applyDailyField(account.quests, at, const [
    'Read ten pages',
    'Review one problem',
    'Write for today',
  ]);
  _train(account, at, week);
  Clock.freeze(at);
  await bootRoom(
    tester,
    account,
    schedule: _schedule,
    precache: [...RoomArt.everyday, ..._plates],
  );
  final context = tester.element(find.byType(MaterialApp).first);
  await tester.runAsync(() async {
    for (final asset in DoorwayAssets.all) {
      await precacheImage(DoorwayAssets.providerFor(asset), context);
    }
    await Future<void>.delayed(const Duration(milliseconds: 400));
  });
  await tester.pump(const Duration(milliseconds: 200));
  await settle(tester, total: const Duration(milliseconds: 2800));
  appTextScale.value = textScale;
  await tester.pump();
  return account;
}

Future<void> _openDoor(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('brawl-door')).hitTestable());
  await tester.pump();
  await settle(tester, total: const Duration(milliseconds: 1200));
}

BrawlFlowScreenState _flow(WidgetTester tester) =>
    tester.state<BrawlFlowScreenState>(find.byType(BrawlFlowScreen));

BrawlFightScreenState _fightState(WidgetTester tester) =>
    tester.state<BrawlFightScreenState>(find.byType(BrawlFightScreen));

/// Pumps frames until [done], with the average-player bot at the controls.
Future<void> _play(
  WidgetTester tester,
  BrawlFightScreenState state,
  bool Function() done, {
  double maxSeconds = 150,
}) async {
  final scene = state.scene!;
  final bot = BrawlBot(state.fight, seed: 3);
  scene.beforeStep = () {
    bot.drive();
    final b = bot.input;
    scene.inp
      ..moveX = b.moveX
      ..attackHeld = b.attackHeld
      ..jumpHeld = b.jumpHeld
      ..pAtk = scene.inp.pAtk || b.pAtk
      ..pJump = scene.inp.pJump || b.pJump
      ..pSpell = scene.inp.pSpell || b.pSpell
      ..pFriend = scene.inp.pFriend || b.pFriend
      ..pSuper = scene.inp.pSuper || b.pSuper
      ..pFinish = scene.inp.pFinish || b.pFinish;
    b
      ..pAtk = false
      ..pJump = false
      ..pSpell = false
      ..pFriend = false
      ..pSuper = false
      ..pFinish = false;
  };
  var frames = 0;
  while (!done() && frames < maxSeconds * 60) {
    await tester.pump(const Duration(milliseconds: 16));
    frames++;
  }
  scene.beforeStep = null;
}

void main() {
  setUpAll(setUpRoomRenders);
  tearDownAll(tearDownRoomRenders);
  setUp(() {
    QuestsPage.debugLegacyBoard = false;
    BrawlDebug.seed = 41;
  });
  tearDown(() {
    QuestsPage.debugLegacyBoard = true;
    BrawlDebug.seed = null;
    BrawlDebug.openAnyDay = false;
    appTextScale.value = 1;
  });
  final sheet = FrameSheet(_out);
  tearDownAll(() {
    if (_renders) sheet.writeManifest();
  });

  Future<void> shot(
    WidgetTester tester,
    String name,
    DateTime at,
    String note,
  ) => sheet.shot(tester, name, at: at, surface: 'QUESTS', note: note);

  roomRenderTest('the weekend door', skip: !_renders, (tester) async {
    if (!_wants('door')) return;
    var at = _at(3, 11, 0);
    await _boot(tester, at);
    expect(find.byKey(const Key('brawl-door')), findsOneWidget);
    await shot(
      tester,
      'A_doorway_saturday',
      at,
      'Saturday: the Doorway lights "Join the fight!" with the Troll at the door',
    );
    await tester.tap(find.byKey(const Key('quest-day-board')).hitTestable());
    await tester.pump();
    await settle(tester, total: const Duration(milliseconds: 1400));
    await shot(
      tester,
      'A_board_saturday',
      at,
      'Saturday: the board keeps the door lit',
    );
    await tester.pumpWidget(const SizedBox.shrink());
    at = DateTime(2026, 11, 26, 11, 0);
    await _boot(tester, at);
    await shot(
      tester,
      'B_doorway_weekday',
      at,
      'Thanksgiving, no classes: the Doorway only says what is coming',
    );
    expect(find.byKey(const Key('brawl-door')), findsNothing);
    expect(find.byKey(const Key('brawl-preview')), findsOneWidget);
  });

  roomRenderTest('versus, a quiet week and a big week', skip: !_renders, (
    tester,
  ) async {
    if (!_wants('versus')) return;
    final at = _at(3, 11, 0);
    await _boot(tester, at);
    await _openDoor(tester);
    await shot(tester, 'C_versus_quiet', at, 'the versus screen, a quiet week');
    await tester.drag(
      find.byKey(const Key('brawl-versus-scroll')),
      const Offset(0, -700),
      warnIfMissed: false,
    );
    await settle(tester, total: const Duration(milliseconds: 700));
    await shot(
      tester,
      'C_versus_quiet_abilities',
      at,
      'the monster and abilities',
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await _boot(tester, at, week: _bigWeek);
    await _openDoor(tester);
    await shot(tester, 'D_versus_big', at, 'the versus screen, a big week');
    await tester.drag(
      find.byKey(const Key('brawl-versus-scroll')),
      const Offset(0, -700),
      warnIfMissed: false,
    );
    await settle(tester, total: const Duration(milliseconds: 700));
    await shot(
      tester,
      'D_versus_big_abilities',
      at,
      'abilities glowing, trained this week',
    );
    await tester.drag(
      find.byKey(const Key('brawl-versus-scroll')),
      const Offset(0, -900),
      warnIfMissed: false,
    );
    await settle(tester, total: const Duration(milliseconds: 700));
    await shot(
      tester,
      'D_versus_big_bottom',
      at,
      'the end of the versus screen: Easy mode and FIGHT!',
    );
  });

  roomRenderTest(
    'a big week through the door to the victory',
    skip: !_renders,
    (tester) async {
      if (!_wants('fight') && !_wants('victory')) return;
      final at = _at(3, 11, 0);
      await _boot(tester, at, week: _bigWeek);
      await _openDoor(tester);
      await tester.tap(find.byKey(const Key('brawl-fight')).hitTestable());
      await tester.pump();
      await settle(tester, total: const Duration(milliseconds: 600));
      expect(find.byType(BrawlFightScreen), findsOneWidget);
      final state = _fightState(tester);
      await _play(tester, state, () => state.fight.clock > 1.2);
      await shot(tester, 'E_fight_start', at, 'ROUND 1 to FIGHT!');
      await _play(
        tester,
        state,
        () => state.fight.combo.n >= 8,
        maxSeconds: 40,
      );
      await shot(tester, 'E_mid_combo', at, 'mid-combo, a big week');
      await _play(
        tester,
        state,
        () => state.fight.bolts.isNotEmpty,
        maxSeconds: 40,
      );
      await tester.pump(const Duration(milliseconds: 60));
      await shot(tester, 'E_spell_bolt', at, 'Spell Bolt in flight');
      await _play(
        tester,
        state,
        () => state.fight.f.state == BrawlFighterState.superMove,
        maxSeconds: 40,
      );
      await _play(
        tester,
        state,
        () => state.fight.f.anim == BrawlFighterAnim.superFlurry,
        maxSeconds: 5,
      );
      await tester.pump(const Duration(milliseconds: 120));
      await shot(tester, 'E_super', at, 'the Super');
      await _play(
        tester,
        state,
        () => state.fight.phase == BrawlPhase.daze,
        maxSeconds: 150,
      );
      await _play(
        tester,
        state,
        () => (state.fight.dazeT) > 0.5,
        maxSeconds: 3,
      );
      await shot(tester, 'E_finish_it', at, 'FINISH IT!');
      await _play(
        tester,
        state,
        () => (state.fight.fin?.t ?? 0) > 1.9,
        maxSeconds: 20,
      );
      await shot(tester, 'E_finisher', at, 'the Troll, tucked in for a nap');
      await _play(
        tester,
        state,
        () => _flow(tester).stage == BrawlStage.victory,
        maxSeconds: 20,
      );
      await settle(tester, total: const Duration(milliseconds: 2200));
      await shot(
        tester,
        'F_victory',
        at,
        'victory: the chest and the breakdown',
      );
      await tester.drag(
        find.byKey(const Key('brawl-victory-scroll')),
        const Offset(0, -700),
        warnIfMissed: false,
      );
      await settle(tester, total: const Duration(milliseconds: 700));
      await shot(tester, 'F_victory_breakdown', at, 'which stats did the work');
    },
  );

  roomRenderTest('the Fog and Easy mode', skip: !_renders, (tester) async {
    if (!_wants('easy')) return;
    final at = _at(10, 11, 0);
    await _boot(tester, at, week: _bigWeek, easy: true);
    await shot(tester, 'G_doorway_fog', at, 'Saturday, the Fog week');
    await _openDoor(tester);
    await shot(
      tester,
      'G_versus_fog',
      at,
      'the Fog at the versus screen, Easy mode on',
    );
    await tester.tap(find.byKey(const Key('brawl-fight')).hitTestable());
    await tester.pump();
    await settle(tester, total: const Duration(milliseconds: 600));
    final state = _fightState(tester);
    await _play(tester, state, () => state.fight.combo.n >= 6, maxSeconds: 60);
    await shot(
      tester,
      'G_easy_fog',
      at,
      'Easy mode against the Fog: the whole stage is the button',
    );
    await _play(
      tester,
      state,
      () => (state.fight.fin?.t ?? 0) > 1.6,
      maxSeconds: 150,
    );
    await shot(
      tester,
      'G_fog_finisher',
      at,
      'the Fog becomes a little cloud that waters the plant',
    );
  });

  roomRenderTest('a practice weekend', skip: !_renders, (tester) async {
    if (!_wants('practice')) return;
    final at = _at(3, 11, 0);
    final account = await _boot(tester, at, week: _bigWeek);
    expect(account, isNotNull);
    await _openDoor(tester);
    await tester.tap(find.byKey(const Key('brawl-fight')).hitTestable());
    await tester.pump();
    await settle(tester, total: const Duration(milliseconds: 600));
    var state = _fightState(tester);
    await _play(
      tester,
      state,
      () => _flow(tester).stage == BrawlStage.victory,
      maxSeconds: 150,
    );
    await settle(tester, total: const Duration(milliseconds: 1800));
    await tester.tap(find.byKey(const Key('brawl-again')).hitTestable());
    await tester.pump();
    await settle(tester, total: const Duration(milliseconds: 600));
    state = _fightState(tester);
    await _play(
      tester,
      state,
      () => _flow(tester).stage == BrawlStage.victory,
      maxSeconds: 150,
    );
    await settle(tester, total: const Duration(milliseconds: 1800));
    await shot(
      tester,
      'H_victory_practice',
      at,
      'the second win of the weekend: practice, no chest',
    );
  });

  roomRenderTest('large text and Reduce Motion', skip: !_renders, (
    tester,
  ) async {
    if (!_wants('text')) return;
    final at = _at(10, 11, 0);
    await _boot(tester, at, week: _bigWeek, textScale: 2);
    await _openDoor(tester);
    await shot(tester, 'I_versus_200', at, 'the versus screen at 200% text');
    await tester.drag(
      find.byKey(const Key('brawl-versus-scroll')),
      const Offset(0, -1500),
      warnIfMissed: false,
    );
    await settle(tester, total: const Duration(milliseconds: 600));
    await shot(tester, 'I_versus_200_abilities', at, 'abilities at 200% text');
    await tester.drag(
      find.byKey(const Key('brawl-versus-scroll')),
      const Offset(0, 5000),
      warnIfMissed: false,
    );
    await settle(tester, total: const Duration(milliseconds: 500));
    await tester.tap(find.byKey(const Key('brawl-fight')).hitTestable());
    await tester.pump();
    await settle(tester, total: const Duration(milliseconds: 600));
    final big = _fightState(tester);
    await _play(
      tester,
      big,
      () => _flow(tester).stage == BrawlStage.victory,
      maxSeconds: 150,
    );
    await settle(tester, total: const Duration(milliseconds: 1800));
    await shot(tester, 'I_victory_200', at, 'the victory at 200% text');
    await tester.drag(
      find.byKey(const Key('brawl-victory-scroll')),
      const Offset(0, -1500),
      warnIfMissed: false,
    );
    await settle(tester, total: const Duration(milliseconds: 600));
    await shot(
      tester,
      'I_victory_200_breakdown',
      at,
      'the breakdown at 200% text',
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await _boot(tester, at, week: _bigWeek, reduceMotion: true);
    await _openDoor(tester);
    await tester.tap(find.byKey(const Key('brawl-fight')).hitTestable());
    await tester.pump();
    await settle(tester, total: const Duration(milliseconds: 600));
    final state = _fightState(tester);
    await _play(tester, state, () => state.fight.combo.n >= 8, maxSeconds: 40);
    await shot(
      tester,
      'J_reduce_motion_combo',
      at,
      'Reduce Motion: the same fight, calmer',
    );
    await _play(
      tester,
      state,
      () => _flow(tester).stage == BrawlStage.victory,
      maxSeconds: 150,
    );
    await settle(tester, total: const Duration(milliseconds: 1800));
    await shot(
      tester,
      'J_reduce_motion_victory',
      at,
      'Reduce Motion: the chest is already open',
    );
  });

  roomRenderTest('Power Slam on a quiet week', skip: !_renders, (tester) async {
    if (!_wants('slam')) return;
    final at = _at(3, 11, 0);
    await _boot(tester, at);
    await _openDoor(tester);
    await tester.tap(find.byKey(const Key('brawl-fight')).hitTestable());
    await tester.pump();
    await settle(tester, total: const Duration(milliseconds: 600));
    final state = _fightState(tester);
    await _play(
      tester,
      state,
      () =>
          state.fight.t > 4 &&
          state.fight.f.state == BrawlFighterState.charge &&
          state.fight.f.charge > 0.3,
      maxSeconds: 60,
    );
    await shot(
      tester,
      'K_slam_charge',
      at,
      'holding ATTACK: Power Slam charges',
    );
    await _play(
      tester,
      state,
      () => state.fight.f.state == BrawlFighterState.slam,
      maxSeconds: 20,
    );
    await tester.pump(const Duration(milliseconds: 150));
    await shot(tester, 'K_slam_impact', at, 'Power Slam lands');
  });
}
