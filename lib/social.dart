import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'audio.dart';
import 'clock.dart';
import 'cloud.dart';
import 'engine.dart';
import 'models.dart';
import 'platform/share_stub.dart'
    if (dart.library.js_interop) 'platform/share_web.dart';
import 'screens/visit_room.dart';
import 'tokens.dart';

bool _sharingSpace = false;
final RegExp _roomCodePattern = RegExp(
  r'^[ABCDEFGHJKMNPQRSTUVWXYZ23456789]{6}$',
);

typedef RoomFetcher = Future<Map<String, dynamic>?> Function(String code);

String _sharedProfileText(String? value, int maxCharacters) {
  final collapsed = (value ?? '').replaceAll(RegExp(r'\s+'), ' ').trim();
  return String.fromCharCodes(collapsed.runes.take(maxCharacters));
}

/// The bounded payload published for a shared space. Quests, notes, streak
/// details, and account data never travel. A name, short introduction, and up
/// to three chosen goal titles are included only after explicit profile consent.
Map<String, dynamic> roomDisplay(GameState s) {
  final milestoneGoals = s.goals
      .where((g) => g.complete || g.progress >= 25)
      .length;
  final hearthMemories = [
    5,
    10,
    16,
    24,
    34,
  ].where((level) => s.level >= level).length;
  final memories =
      s.memoryPins.length +
      s.unlockedAchievements.length +
      milestoneGoals +
      hearthMemories;
  final weather = s.energyWeatherDay == Days.key(Clock.now())
      ? s.energyWeather.name
      : 'unknown';
  final profileVisible = s.shareSpaceProfile;
  final aboutVisible = !s.hiddenSpaceCards.contains(SpaceCardKind.about);
  final rightNowVisible = !s.hiddenSpaceCards.contains(SpaceCardKind.rightNow);
  final displayName = profileVisible
      ? _sharedProfileText(s.playerName, 40)
      : '';
  final about = profileVisible && aboutVisible
      ? _sharedProfileText(s.spaceIntro, 180)
      : '';
  final featuredGoals = profileVisible && rightNowVisible
      ? <String>[
          for (final title in s.featuredGoalTitles)
            _sharedProfileText(title, 100),
        ].where((title) => title.isNotEmpty).toSet().take(3).toList()
      : const <String>[];
  return {
    // Fixed copy keeps code-gated visits personal without turning shared rooms
    // into an unmoderated user-generated-content surface.
    'name': 'Fellow keeper',
    'title': s.buildTitle,
    'level': s.level,
    'furniture': s.ownedFurniture.toList(),
    'wall': s.wallStyle,
    'floor': s.floorStyle,
    'skin': s.creatureSkin,
    'window': s.windowScene,
    'awake': s.streakDays > 0,
    'memories': memories.clamp(0, 9999),
    'weather': weather,
    'todayLit': (s.history[Days.key(Clock.now())] ?? 0) > 0,
    'focusKind': s.quietCompanyActive ? s.quietCompanyKind : 'none',
    'focusUntil': s.quietCompanyActive ? s.quietCompanyUntil : 0,
    'profileVisible': profileVisible,
    'displayName': displayName,
    'about': about,
    'featuredGoals': featuredGoals,
    'v': 3,
  };
}

void _toast(BuildContext context, String msg) {
  ScaffoldMessenger.of(context)
    ..clearSnackBars()
    ..showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(color: Palette.textHi)),
        backgroundColor: Palette.card,
        behavior: SnackBarBehavior.floating,
      ),
    );
}

/// Publish (or refresh) your space and show its share code.
Future<void> shareSpace(
  BuildContext context,
  GameState state,
  VoidCallback onPersist,
) async {
  final cloud = CloudSync.instance;
  if (_sharingSpace) {
    _toast(context, 'Your share is already opening.');
    return;
  }
  if (!cloud.available) {
    _toast(context, 'Sharing needs a connection — try again in a moment.');
    return;
  }
  _sharingSpace = true;
  if (!await cloud.ensureSocialSession()) {
    _sharingSpace = false;
    if (context.mounted) {
      _toast(context, 'Couldn’t connect sharing — try again.');
    }
    return;
  }
  Sfx.instance.play('tick');
  final code = await cloud.shareRoom(roomDisplay(state), code: state.roomCode);
  if (!context.mounted) {
    _sharingSpace = false;
    return;
  }
  if (code == null) {
    _sharingSpace = false;
    _toast(context, 'Couldn’t share right now — try again.');
    return;
  }
  if (state.roomCode != code) {
    state.setRoomCode(code);
    onPersist();
  }
  Sfx.instance.play('loot');
  await showShareSpaceDialog(
    context,
    code: code,
    onStop: () async {
      final stopped = await cloud.unshareRoom(code);
      if (!stopped) return false;
      state.setRoomCode(null);
      onPersist();
      return true;
    },
  );
  _sharingSpace = false;
}

Future<void> showShareSpaceDialog(
  BuildContext context, {
  required String code,
  required Future<bool> Function() onStop,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => _ShareDialog(code: code, onStop: onStop),
  );
}

/// Prompt for a room code and keep the dialog open while the shared room is
/// validated and fetched. Circle and one-off visits share this exact handoff.
Future<SharedRoomVisit?> promptForSharedRoom(
  BuildContext context, {
  RoomFetcher? fetcher,
}) async {
  if (fetcher == null) {
    final cloud = CloudSync.instance;
    if (!cloud.available) {
      _toast(context, 'Visiting needs a connection — try again in a moment.');
      return null;
    }
    // Visiting is an explicit social action. A lightweight anonymous session
    // keeps this compatible with already-deployed authenticated room rules,
    // without opting the person's save into cloud backup.
    if (!await cloud.ensureSocialSession()) {
      if (context.mounted) {
        _toast(context, 'Couldn’t connect visiting — try again.');
      }
      return null;
    }
    if (!context.mounted) return null;
  }
  return showDialog<SharedRoomVisit>(
    context: context,
    builder: (_) =>
        _VisitPrompt(fetcher: fetcher ?? CloudSync.instance.fetchRoom),
  );
}

/// Prompt for a code and open that shared space.
Future<void> visitSpace(
  BuildContext context, {
  String? themeId,
  bool lively = true,
  ValueListenable<Offset>? parallax,
  GameState? state,
  VoidCallback? onPersist,
  RoomFetcher? fetcher,
}) async {
  final result = await promptForSharedRoom(context, fetcher: fetcher);
  if (result == null || !context.mounted) return;
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => VisitRoomScreen(
        room: result.room,
        code: result.code,
        themeId: themeId,
        lively: lively,
        parallax: parallax,
        localState: state,
        onPersist: onPersist,
      ),
    ),
  );
}

class SharedRoomVisit {
  const SharedRoomVisit({required this.code, required this.room});

  final String code;
  final Map<String, dynamic> room;
}

class _ShareDialog extends StatefulWidget {
  const _ShareDialog({required this.code, required this.onStop});
  final String code;
  final Future<bool> Function() onStop;

  @override
  State<_ShareDialog> createState() => _ShareDialogState();
}

class _ShareDialogState extends State<_ShareDialog> {
  bool _inviting = false;
  bool _stopping = false;

  String get _invite =>
      'Come visit my space. Open the app, tap “Visit a space”, and enter '
      '${widget.code}.';

  Future<void> _invitePeople() async {
    if (_inviting) return;
    setState(() => _inviting = true);
    final box = context.findRenderObject() as RenderBox?;
    final origin = box == null
        ? null
        : box.localToGlobal(Offset.zero) & box.size;
    final shared = await shareText(_invite, origin: origin);
    if (!mounted) return;
    setState(() => _inviting = false);
    if (!shared) {
      await Clipboard.setData(ClipboardData(text: _invite));
      if (mounted) _toast(context, 'Invite copied');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      scrollable: true,
      backgroundColor: Palette.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(
        'Your space is live',
        style: Type.display.copyWith(fontSize: 20, color: Palette.textHi),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Share this code — anyone can visit your space:',
            style: Type.body.copyWith(fontSize: 13, color: Palette.textMid),
          ),
          const SizedBox(height: 14),
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: Palette.xp.withValues(alpha: 0.14),
                border: Border.all(color: Palette.xp.withValues(alpha: 0.5)),
              ),
              child: Text(
                widget.code,
                style: Type.display.copyWith(
                  fontSize: 30,
                  color: Palette.xpLight,
                  letterSpacing: 6,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _inviting ? null : _invitePeople,
              icon: _inviting
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send_outlined, size: 18),
              label: Text(_inviting ? 'Opening…' : 'Invite people'),
            ),
          ),
          SizedBox(
            width: double.infinity,
            child: TextButton.icon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: widget.code));
                Sfx.instance.play('tick');
                if (context.mounted) _toast(context, 'Code copied');
              },
              icon: const Icon(Icons.copy, size: 16),
              label: const Text('Copy code'),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Your chosen name, intro, and featured goals are shared only when '
            'you turn on your visitor page. Journal entries, photos, quests, '
            'and account details stay private.',
            style: Type.body.copyWith(fontSize: 11, color: Palette.textLo),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _stopping
              ? null
              : () async {
                  setState(() => _stopping = true);
                  final stopped = await widget.onStop();
                  if (!context.mounted) return;
                  if (stopped) {
                    Navigator.of(context).pop();
                  } else {
                    setState(() => _stopping = false);
                    _toast(
                      context,
                      'Couldn’t stop sharing yet — your code is still safe here.',
                    );
                  }
                },
          child: Text(
            _stopping ? 'Stopping…' : 'Stop sharing',
            style: Type.label.copyWith(fontSize: 12, color: Palette.textLo),
          ),
        ),
        TextButton(
          key: const Key('share-space-done'),
          onPressed: _stopping ? null : () => Navigator.of(context).pop(),
          child: Text(
            'Done',
            style: Type.label.copyWith(fontSize: 13, color: Palette.xpLight),
          ),
        ),
      ],
    );
  }
}

class _VisitPrompt extends StatefulWidget {
  const _VisitPrompt({required this.fetcher});

  final RoomFetcher fetcher;

  @override
  State<_VisitPrompt> createState() => _VisitPromptState();
}

class _VisitPromptState extends State<_VisitPrompt> {
  final _c = TextEditingController();
  bool _loading = false;
  String? _error;

  Future<void> _visit() async {
    if (_loading) return;
    final code = _c.text.trim().toUpperCase();
    if (!_roomCodePattern.hasMatch(code)) {
      setState(() {
        _error = 'Enter the full six-character code. Codes skip I, O, 0 and 1.';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final room = await widget.fetcher(code);
      if (!mounted) return;
      if (room == null) {
        setState(() {
          _loading = false;
          _error =
              'No shared space found with that code. Check it and try again.';
        });
        return;
      }
      Navigator.of(context).pop(SharedRoomVisit(code: code, room: room));
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error =
            'Couldn’t reach that space. Check your connection and try again.';
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
    return AlertDialog(
      scrollable: true,
      backgroundColor: Palette.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(
        'Visit a space',
        style: Type.display.copyWith(fontSize: 20, color: Palette.textHi),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Enter a friend’s share code:',
            style: Type.body.copyWith(fontSize: 13, color: Palette.textMid),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('visit-space-code'),
            controller: _c,
            autofocus: true,
            enabled: !_loading,
            textCapitalization: TextCapitalization.characters,
            maxLength: 6,
            inputFormatters: [
              FilteringTextInputFormatter.allow(
                RegExp(r'[A-HJ-NP-Za-hj-np-z2-9]'),
              ),
              LengthLimitingTextInputFormatter(6),
            ],
            style: Type.display.copyWith(
              fontSize: 24,
              color: Palette.xpLight,
              letterSpacing: 6,
            ),
            textAlign: TextAlign.center,
            cursorColor: Palette.xp,
            decoration: InputDecoration(
              counterText: '',
              hintText: 'ABC123',
              hintStyle: Type.display.copyWith(
                fontSize: 24,
                color: Palette.textLo,
                letterSpacing: 6,
              ),
              enabledBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: Palette.glassRim),
              ),
              focusedBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: Palette.xp),
              ),
            ),
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
            onSubmitted: (_) => _visit(),
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(
              _error!,
              key: const Key('visit-space-error'),
              style: Type.body.copyWith(fontSize: 12, color: Palette.danger),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.of(context).pop(),
          child: Text(
            'Cancel',
            style: Type.label.copyWith(fontSize: 12, color: Palette.textLo),
          ),
        ),
        TextButton(
          key: const Key('visit-space-submit'),
          onPressed: _loading ? null : _visit,
          child: _loading
              ? const SizedBox.square(
                  key: Key('visit-space-loading'),
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(
                  'Visit',
                  style: Type.label.copyWith(
                    fontSize: 13,
                    color: Palette.xpLight,
                  ),
                ),
        ),
      ],
    );
  }
}
