import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'audio.dart';
import 'cloud.dart';
import 'engine.dart';
import 'screens/visit_room.dart';
import 'tokens.dart';

/// The appearance-only payload published for a shared space (round-52). Never
/// includes quests, notes, streak details or account data — just what's needed
/// to redraw the room + character for a visitor.
Map<String, dynamic> roomDisplay(GameState s) => {
      'name': (s.playerName ?? '').trim(),
      'title': s.buildTitle,
      'level': s.level,
      'furniture': s.ownedFurniture.toList(),
      'wall': s.wallStyle,
      'floor': s.floorStyle,
      'skin': s.creatureSkin,
      'window': s.windowScene,
      'awake': s.streakDays > 0,
      'v': 1,
    };

void _toast(BuildContext context, String msg) {
  ScaffoldMessenger.of(context)
    ..clearSnackBars()
    ..showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(color: Palette.textHi)),
      backgroundColor: Palette.card,
      behavior: SnackBarBehavior.floating,
    ));
}

/// Publish (or refresh) your space and show its share code.
Future<void> shareSpace(
    BuildContext context, GameState state, VoidCallback onPersist) async {
  final cloud = CloudSync.instance;
  if (!cloud.ready) {
    _toast(context, 'Sharing needs a connection — try again in a moment.');
    return;
  }
  Sfx.instance.play('tick');
  final code = await cloud.shareRoom(roomDisplay(state), code: state.roomCode);
  if (!context.mounted) return;
  if (code == null) {
    _toast(context, 'Couldn’t share right now — try again.');
    return;
  }
  if (state.roomCode != code) {
    state.roomCode = code;
    onPersist();
  }
  Sfx.instance.play('loot');
  await showDialog<void>(
    context: context,
    builder: (_) => _ShareDialog(
      code: code,
      onStop: () async {
        await cloud.unshareRoom(code);
        state.roomCode = null;
        onPersist();
      },
    ),
  );
}

/// Prompt for a code and open that shared space.
Future<void> visitSpace(BuildContext context) async {
  if (!CloudSync.instance.ready) {
    _toast(context, 'Visiting needs a connection — try again in a moment.');
    return;
  }
  final code = await showDialog<String>(
    context: context,
    builder: (_) => const _VisitPrompt(),
  );
  if (code == null || code.trim().isEmpty) return;
  if (!context.mounted) return;
  final room = await CloudSync.instance.fetchRoom(code);
  if (!context.mounted) return;
  if (room == null) {
    _toast(context, 'No space found with that code.');
    return;
  }
  Navigator.of(context).push(MaterialPageRoute(
    builder: (_) => VisitRoomScreen(room: room, code: code.trim().toUpperCase()),
  ));
}

class _ShareDialog extends StatelessWidget {
  const _ShareDialog({required this.code, required this.onStop});
  final String code;
  final Future<void> Function() onStop;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Palette.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text('Your space is live',
          style: Type.display.copyWith(fontSize: 20, color: Palette.textHi)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Share this code — anyone can visit your space:',
              style: Type.body.copyWith(fontSize: 13, color: Palette.textMid)),
          const SizedBox(height: 14),
          Center(
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: Palette.xp.withValues(alpha: 0.14),
                border: Border.all(color: Palette.xp.withValues(alpha: 0.5)),
              ),
              child: Text(
                code,
                style: Type.display.copyWith(
                    fontSize: 30, color: Palette.xpLight, letterSpacing: 6),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Center(
            child: TextButton.icon(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: code));
                Sfx.instance.play('tick');
                _toast(context, 'Code copied');
              },
              icon: const Icon(Icons.copy, size: 16, color: Palette.xpLight),
              label: Text('Copy',
                  style: Type.label
                      .copyWith(fontSize: 12, color: Palette.xpLight)),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Only your room’s look is shared — never your quests, notes or '
            'account. Re-share any time to update it.',
            style: Type.body.copyWith(fontSize: 11, color: Palette.textLo),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () async {
            await onStop();
            if (context.mounted) Navigator.of(context).pop();
          },
          child: Text('Stop sharing',
              style: Type.label.copyWith(fontSize: 12, color: Palette.textLo)),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Done',
              style: Type.label.copyWith(fontSize: 13, color: Palette.xpLight)),
        ),
      ],
    );
  }
}

class _VisitPrompt extends StatefulWidget {
  const _VisitPrompt();
  @override
  State<_VisitPrompt> createState() => _VisitPromptState();
}

class _VisitPromptState extends State<_VisitPrompt> {
  final _c = TextEditingController();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Palette.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text('Visit a space',
          style: Type.display.copyWith(fontSize: 20, color: Palette.textHi)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Enter a friend’s share code:',
              style: Type.body.copyWith(fontSize: 13, color: Palette.textMid)),
          const SizedBox(height: 12),
          TextField(
            controller: _c,
            autofocus: true,
            textCapitalization: TextCapitalization.characters,
            maxLength: 6,
            style: Type.display.copyWith(
                fontSize: 24, color: Palette.xpLight, letterSpacing: 6),
            textAlign: TextAlign.center,
            cursorColor: Palette.xp,
            decoration: InputDecoration(
              counterText: '',
              hintText: 'ABC123',
              hintStyle: Type.display.copyWith(
                  fontSize: 24,
                  color: Palette.textLo,
                  letterSpacing: 6),
              enabledBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(color: Palette.glassRim)),
              focusedBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(color: Palette.xp)),
            ),
            onSubmitted: (v) => Navigator.of(context).pop(v),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Cancel',
              style: Type.label.copyWith(fontSize: 12, color: Palette.textLo)),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(_c.text),
          child: Text('Visit',
              style: Type.label.copyWith(fontSize: 13, color: Palette.xpLight)),
        ),
      ],
    );
  }
}
