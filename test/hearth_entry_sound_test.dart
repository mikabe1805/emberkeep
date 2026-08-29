import 'dart:io';

import 'package:emberkeep/audio.dart';
import 'package:emberkeep/screens/shell.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'ordinary contacts share one deterministic varied walk across roles',
    () {
      final sounds = InteractionSoundRouter();
      final start = DateTime(2026, 8, 20, 12);

      expect(
        [
          sounds.next(InteractionSound.open, at: start)?.asset,
          sounds
              .next(
                InteractionSound.navigate,
                at: start.add(const Duration(milliseconds: 250)),
              )
              ?.asset,
          sounds
              .next(
                InteractionSound.select,
                at: start.add(const Duration(milliseconds: 500)),
              )
              ?.asset,
          sounds
              .next(
                InteractionSound.place,
                at: start.add(const Duration(milliseconds: 750)),
              )
              ?.asset,
        ],
        [
          'room/ordinary/open/1',
          'room/ordinary/navigate/3',
          'room/ordinary/select/2',
          'room/ordinary/place/4',
        ],
      );
    },
  );

  test('the app-session ignition can only be claimed once', () {
    final ignition = AppSessionIgnitionGate();
    expect(ignition.claim(), isTrue);
    expect(ignition.claim(), isFalse);
    expect(ignition.isClaimed, isTrue);
  });

  test('welcome ignition waits for every launch overlay to clear', () {
    bool mayBegin({
      bool onboarded = true,
      bool whatsNewPending = false,
      bool whatsNewVisible = false,
      bool whatsNewCheckScheduled = false,
      bool morningVisible = false,
      bool morningCheckScheduled = false,
    }) => sessionIgnitionMayBegin(
      startupSettled: true,
      onboarded: onboarded,
      questRoomVisible: true,
      whatsNewPending: whatsNewPending,
      whatsNewVisible: whatsNewVisible,
      whatsNewCheckScheduled: whatsNewCheckScheduled,
      morningVisible: morningVisible,
      morningCheckScheduled: morningCheckScheduled,
    );

    expect(mayBegin(), isTrue);
    expect(mayBegin(onboarded: false), isFalse);
    expect(
      sessionIgnitionMayBegin(
        startupSettled: true,
        onboarded: true,
        questRoomVisible: false,
        whatsNewPending: false,
        whatsNewVisible: false,
        whatsNewCheckScheduled: false,
        morningVisible: false,
        morningCheckScheduled: false,
      ),
      isFalse,
    );
    expect(mayBegin(whatsNewPending: true), isFalse);
    expect(mayBegin(whatsNewVisible: true), isFalse);
    expect(mayBegin(whatsNewCheckScheduled: true), isFalse);
    expect(mayBegin(morningVisible: true), isFalse);
    expect(mayBegin(morningCheckScheduled: true), isFalse);
  });

  test('the hearth is one session wake-up, never a tab or looping room bed', () {
    String source(String path) =>
        File(path).readAsStringSync().replaceAll('\r\n', '\n');
    final audio = source('lib/audio.dart');
    final shell = source('lib/screens/shell.dart');
    final pressable = source('lib/widgets/pressable.dart');
    final fire = source('lib/widgets/quest_depth_room.dart');

    expect(audio, isNot(contains('ReleaseMode.loop')));
    expect(audio, isNot(contains('hearth_room.wav')));
    expect(audio, isNot(contains('setHearthRoomActive')));
    expect(shell, isNot(contains('setHearthRoomActive')));
    expect(shell, contains('AppSessionIgnitionGate'));
    expect(shell, contains("Sfx.instance.play('fire_ignite');"));
    expect(
      RegExp(r"play\('fire_ignite'").allMatches(shell),
      hasLength(1),
      reason: 'only the visible-room session gate owns the welcome cue',
    );
    expect(shell, contains('_whatsNewOverlay != null'));
    expect(shell, contains('_morningOverlay != null'));
    expect(shell, contains('Navigator.of(context).canPop() == false'));
    expect(shell, contains('Timer? _ignitionClearTimer'));
    expect(shell, contains('_ignitionClearTimer?.cancel();'));
    expect(shell, contains('_maybeStartSessionIgnition();'));
    final initialRoom = shell.substring(
      shell.indexOf('Future<bool> _openInitialRoom'),
      shell.indexOf('Future<bool> _drainPendingRoomLinks'),
    );
    final roomLinks = shell.substring(
      shell.indexOf('Future<bool> _drainPendingRoomLinks'),
      shell.indexOf('Future<void> _loadFromStorage'),
    );
    final selectTab = shell.substring(
      shell.indexOf('void _selectTab'),
      shell.indexOf('@override\n  Widget build'),
    );
    expect(initialRoom, contains('_maybeStartSessionIgnition();'));
    expect(roomLinks, contains('_maybeStartSessionIgnition();'));
    expect(selectTab, contains('if (i == 1) _maybeStartSessionIgnition();'));
    // Pressable keeps pointer-down visual/haptic only, then routes the accepted
    // tap through one contact owner with its surface material.
    expect(pressable, contains('Sfx.instance.playInteraction('));
    expect(pressable, contains('material: widget.material,'));
    expect(
      pressable,
      contains('if (!widget.enabled || widget.onTapUp == null) return;'),
    );
    final rawPointerDown = pressable.substring(
      pressable.indexOf('onPointerDown:'),
      pressable.indexOf('onPointerMove:'),
    );
    expect(rawPointerDown, contains('_setDown(true);'));
    expect(rawPointerDown, isNot(contains('Sfx.instance')));
    expect(
      pressable,
      contains('onPointerUp: (_) {\n            _setDown(false);'),
    );
    expect(
      pressable,
      contains(
        '_pointerAcknowledged = false;\n          },\n          onPointerCancel',
      ),
    );
    expect(
      RegExp(r'Sfx\.instance\.playInteraction\(').allMatches(pressable),
      hasLength(1),
      reason: 'all accepted activation paths share one contact owner',
    );
    expect(fire, contains("ValueKey('quest-fire-ignition')"));
    expect(fire, contains('widget.reduceMotion'));
  });
}
