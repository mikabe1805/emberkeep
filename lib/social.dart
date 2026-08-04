import 'dart:collection';

import 'package:flutter/foundation.dart' show ChangeNotifier, ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'audio.dart';
import 'clock.dart';
import 'cloud.dart';
import 'content/creature_skins.dart';
import 'content/links.dart';
import 'engine.dart';
import 'models.dart';
import 'platform/share_stub.dart'
    if (dart.library.js_interop) 'platform/share_web.dart';
import 'screens/visit_room.dart';
import 'shared_room_media.dart';
import 'tokens.dart';
import 'widgets/facets.dart';
import 'widgets/glass.dart';
import 'widgets/honey_button.dart';

bool _sharingSpace = false;
final RegExp _roomCodePattern = RegExp(
  r'^[ABCDEFGHJKMNPQRSTUVWXYZ23456789]{6}$',
);

typedef RoomFetcher = Future<Map<String, dynamic>?> Function(String code);

// The single public origin lives in content/links.dart; this alias keeps
// the existing call sites and the SHARE_BASE_URL dart-define working.
const String _defaultRoomInviteBaseUrl = PublicLinks.home;

/// Extracts the bearer code from a shared Room of Days link. Query links are
/// the stable public format; the path form is accepted so a future native
/// universal-link setup will not need a second parser.
String? roomCodeFromUri(Uri uri) {
  final candidates = <String?>[
    uri.queryParameters['space'],
    uri.queryParameters['room'],
    if (uri.pathSegments.length >= 2 &&
        const {'space', 'room'}.contains(uri.pathSegments.first.toLowerCase()))
      uri.pathSegments[1],
  ];
  for (final raw in candidates) {
    final code = raw?.trim().toUpperCase() ?? '';
    if (_roomCodePattern.hasMatch(code)) return code;
  }
  return null;
}

/// One accepted room-link delivery.
///
/// The sequence makes two taps on the same link distinct events. A friend can
/// send the same room again later and the already-running app should still
/// open it, rather than silently treating the string as unchanged state.
class RoomLinkEvent {
  const RoomLinkEvent({required this.code, required this.sequence});

  final String code;
  final int sequence;
}

/// A small FIFO between Flutter's platform route channel and the loaded app.
///
/// iOS can deliver a universal link shortly after a cold launch, while Android
/// may put it in the initial route. Keeping accepted links here means neither
/// case races cloud startup or onboarding, and a warm link can arrive while a
/// visitor sheet for another room is still open.
class RoomLinkInbox extends ChangeNotifier {
  final Queue<RoomLinkEvent> _pending = Queue<RoomLinkEvent>();
  var _sequence = 0;

  bool get isNotEmpty => _pending.isNotEmpty;

  bool enqueueUri(Uri uri) {
    final code = roomCodeFromUri(uri);
    return code != null && enqueueCode(code);
  }

  bool enqueueCode(String raw) {
    final code = raw.trim().toUpperCase();
    if (!_roomCodePattern.hasMatch(code)) return false;
    _pending.add(RoomLinkEvent(code: code, sequence: ++_sequence));
    notifyListeners();
    return true;
  }

  RoomLinkEvent? takeNext() => _pending.isEmpty ? null : _pending.removeFirst();

  @override
  void dispose() {
    _pending.clear();
    super.dispose();
  }
}

String roomInviteUrl(
  String code, {
  String baseUrl = const String.fromEnvironment(
    'SHARE_BASE_URL',
    defaultValue: _defaultRoomInviteBaseUrl,
  ),
}) {
  final clean = code.trim().toUpperCase();
  final base = Uri.parse(baseUrl);
  final query = Map<String, String>.from(base.queryParameters)
    ..remove('space')
    ..remove('room');
  return base
      .replace(
        pathSegments: [
          ...base.pathSegments.where((segment) => segment.isNotEmpty),
          'space',
          clean,
        ],
        queryParameters: query,
      )
      .toString();
}

/// The message a person actually sends a friend, so it has to read like one.
///
/// The previous copy announced itself in the third person ("X is sharing a
/// Room of Days space with you"), which reads as a notification from an app
/// rather than a note from someone you know, and then spent its last and most
/// visible line explaining what to do when the link fails. Leading with an
/// apology for your own link is the fastest way to make it look unsafe to tap.
///
/// What a recipient needs, in order: who this is and why they'd care, the
/// link, and only then the fallback — plus one clause telling them the link
/// costs them nothing, because an unfamiliar host in a text message is the
/// real reason people don't tap.
String roomInviteText(String code, {String? ownerName}) {
  final clean = code.trim().toUpperCase();
  final name = _sharedProfileText(ownerName, 40);
  final opening = name.isEmpty
      ? 'Come see my room. It’s built out of the days I’ve actually been '
            'keeping.'
      : 'Come see my room. I’m $name in there, and it’s built out of the days '
            'I’ve actually been keeping.';
  return '$opening\n\n${roomInviteUrl(clean)}\n\n'
      'It opens in a browser—nothing to install. If you already use Room of '
      'Days, the code is $clean.';
}

/// A local name enters the platform share sheet only under the same explicit
/// visitor-page consent that publishes it with the room. Keeping the visitor
/// page closed must also keep the invite itself anonymous.
String? roomInviteOwnerName(GameState state) =>
    state.shareSpaceProfile ? state.playerName : null;

String circleAddNoticeText(int count) => count == 1
    ? 'Someone added your space to their Circle.'
    : '$count people added your space to their Circles.';

String _sharedProfileText(String? value, int maxCharacters) {
  final collapsed = (value ?? '').replaceAll(RegExp(r'\s+'), ' ').trim();
  return String.fromCharCodes(collapsed.runes.take(maxCharacters));
}

/// The bounded payload published for a shared space. Account data, quest
/// Returns the two device-local files the keeper separately chose to place on
/// their visitor page. These names are used only at the upload boundary and
/// never enter the public room document.
Map<SharedRoomMediaSlot, String> selectedSharedRoomPhotoFiles(GameState s) {
  if (!s.shareSpaceProfile) return const {};
  final selected = <SharedRoomMediaSlot, String>{};
  final profile = s.spaceProfilePhotoNote;
  if (s.shareSpaceProfilePhoto && profile != null) {
    selected[SharedRoomMediaSlot.profile] = profile.images.first;
  }
  final season = s.spaceSeasonPhotoNote;
  if (s.shareSpaceSeasonPhoto &&
      s.visitorSpaceCards.contains(SpaceCardKind.thisSeason) &&
      season != null) {
    selected[SharedRoomMediaSlot.season] = season.images.first;
  }
  return Map.unmodifiable(selected);
}

String _sharedPhotoPath({
  required Map<SharedRoomMediaSlot, String> selected,
  required SharedRoomMediaSlot slot,
  required String? ownerUid,
  required String? roomCode,
}) {
  if (!selected.containsKey(slot) || ownerUid == null || roomCode == null) {
    return '';
  }
  try {
    return sharedRoomMediaObjectPath(
      ownerUid: ownerUid,
      roomCode: roomCode,
      slot: slot.wireName,
    );
  } on SharedRoomMediaException {
    return '';
  }
}

/// The bounded payload published for a shared space. Account data, quest
/// history, and unselected Journal pages stay out. A photo contributes only a
/// deterministic Storage object path after separate consent; local filenames,
/// download URLs, and bytes never enter this map.
Map<String, dynamic> roomDisplay(
  GameState s, {
  String? mediaOwnerUid,
  String? mediaRoomCode,
}) {
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
  final sharedCards = profileVisible
      ? <SpaceCardKind>[
          for (final kind in s.spaceCardOrder)
            if (s.visitorSpaceCards.contains(kind)) kind,
        ]
      : const <SpaceCardKind>[];
  final aboutVisible = sharedCards.contains(SpaceCardKind.about);
  final rightNowVisible = sharedCards.contains(SpaceCardKind.rightNow);
  final momentsVisible = sharedCards.contains(SpaceCardKind.pinnedMoments);
  final seasonVisible = sharedCards.contains(SpaceCardKind.thisSeason);
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
  final pinnedMoments = momentsVisible
      ? <Map<String, dynamic>>[
          for (final note in s.journal.reversed)
            if (s.memoryPins.contains(note.id) &&
                _sharedProfileText(note.text, 240).isNotEmpty)
              {
                'text': _sharedProfileText(note.text, 240),
                'at': note.at.millisecondsSinceEpoch,
              },
        ].take(4).toList()
      : const <Map<String, dynamic>>[];
  final season = seasonVisible
      ? _sharedProfileText(s.spaceSeasonText, 180)
      : '';
  final selectedPhotos = selectedSharedRoomPhotoFiles(s);
  return {
    // The legacy fixed field remains for older clients; bounded, deliberately
    // selected profile writing lives only in the explicit v4 fields below.
    'name': 'Fellow keeper',
    'title': s.buildTitle,
    'level': s.level,
    'furniture': s.ownedFurniture.toList(),
    'wall': s.wallStyle,
    'floor': s.floorStyle,
    'skin': flameSkinIdFor(s),
    'window': s.windowScene,
    'awake': s.streakDays > 0,
    'memories': memories.clamp(0, 9999),
    'weather': weather,
    'todayLit': (s.history[Days.key(Clock.now())] ?? 0) > 0,
    'focusKind': s.quietCompanyActive ? s.quietCompanyKind : 'none',
    'focusUntil': s.quietCompanyActive ? s.quietCompanyUntil : 0,
    'profileVisible': profileVisible,
    'displayName': displayName,
    'cardOrder': [for (final kind in sharedCards) kind.name],
    'about': about,
    'featuredGoals': featuredGoals,
    'pinnedMoments': pinnedMoments,
    'season': season,
    'profilePhotoPath': _sharedPhotoPath(
      selected: selectedPhotos,
      slot: SharedRoomMediaSlot.profile,
      ownerUid: mediaOwnerUid,
      roomCode: mediaRoomCode,
    ),
    'seasonPhotoPath': _sharedPhotoPath(
      selected: selectedPhotos,
      slot: SharedRoomMediaSlot.season,
      ownerUid: mediaOwnerUid,
      roomCode: mediaRoomCode,
    ),
    'v': 5,
  };
}

/// Publishes one exact visitor-page state while coordinating its two optional
/// Storage objects. The current public state is refreshed first so a failed
/// photo operation cannot accidentally publish an uncommitted text edit.
Future<RoomPublishResult> publishSpaceRoomState(
  GameState target, {
  required GameState current,
  required String? code,
  CloudSync? cloudSync,
  SharedRoomMediaService? mediaService,
}) async {
  final cloud = cloudSync ?? CloudSync.instance;
  if (!await cloud.ensureAvailable() || !await cloud.ensureSocialSession()) {
    return const RoomPublishResult.failed(RoomPublishFailure.unavailable);
  }
  final ownerUid = cloud.socialUid;
  if (ownerUid == null) {
    return const RoomPublishResult.failed(RoomPublishFailure.unavailable);
  }

  final normalizedInputCode = code?.trim().toUpperCase();
  final currentDisplay = roomDisplay(
    current,
    mediaOwnerUid: ownerUid,
    mediaRoomCode: normalizedInputCode,
  );
  final reserved = await cloud.publishRoom(currentDisplay, code: code);
  final finalCode = reserved.code;
  if (finalCode == null) return reserved;

  final createdNew =
      normalizedInputCode == null || normalizedInputCode != finalCode;
  final previous = createdNew
      ? const <SharedRoomMediaSlot, String>{}
      : selectedSharedRoomPhotoFiles(current);
  final selected = selectedSharedRoomPhotoFiles(target);
  final removed = previous.keys
      .where((slot) => !selected.containsKey(slot))
      .toSet();
  final changed = <SharedRoomMediaSlot, String>{
    for (final entry in selected.entries)
      if (createdNew || previous[entry.key] != entry.value)
        entry.key: entry.value,
  };
  final media = mediaService ?? SharedRoomMediaService.instance;

  Future<void> abandonNewRoom() async {
    if (createdNew) await cloud.unshareRoom(finalCode);
  }

  try {
    if (removed.isNotEmpty) {
      await media.deleteSlots(
        ownerUid: ownerUid,
        roomCode: finalCode,
        slots: removed,
      );
    }
    if (changed.isNotEmpty) {
      await media.syncSelected(
        ownerUid: ownerUid,
        roomCode: finalCode,
        selectedLocalFilenames: changed,
      );
    }
  } on SharedRoomMediaException {
    final safeToRemove = changed.keys
        .where((slot) => createdNew || !previous.containsKey(slot))
        .toSet();
    if (safeToRemove.isNotEmpty) {
      try {
        await media.deleteSlots(
          ownerUid: ownerUid,
          roomCode: finalCode,
          slots: safeToRemove,
        );
      } on SharedRoomMediaException {
        // The room remains uncommitted and the action reports failure. Stop
        // Sharing/reset will retry any bounded object that did make it up.
      }
    }
    await abandonNewRoom();
    return const RoomPublishResult.failed(RoomPublishFailure.media);
  }

  final display = roomDisplay(
    target,
    mediaOwnerUid: ownerUid,
    mediaRoomCode: finalCode,
  );
  final published = await cloud.publishRoom(display, code: finalCode);
  if (!published.ok) {
    final newlyPublic = selected.keys
        .where((slot) => createdNew || !previous.containsKey(slot))
        .toSet();
    if (newlyPublic.isNotEmpty) {
      try {
        await media.deleteSlots(
          ownerUid: ownerUid,
          roomCode: finalCode,
          slots: newlyPublic,
        );
      } on SharedRoomMediaException {
        // The publish failure remains the primary result. A later Stop
        // Sharing/reset attempts the same bounded cleanup again.
      }
    }
    await abandonNewRoom();
    return published;
  }
  return RoomPublishResult.success(
    published.code!,
    rotatedStaleCode: reserved.rotatedStaleCode || published.rotatedStaleCode,
  );
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
  _sharingSpace = true;
  try {
    if (!await cloud.ensureAvailable()) {
      if (context.mounted) {
        _toast(context, 'Sharing needs a connection — try again in a moment.');
      }
      return;
    }
    if (!await cloud.ensureSocialSession()) {
      if (context.mounted) {
        _toast(context, 'Couldn’t connect sharing — try again.');
      }
      return;
    }
    Sfx.instance.play('tick');
    final published = await publishSpaceRoomState(
      state,
      current: state,
      code: state.roomCode,
      cloudSync: cloud,
    );
    if (!context.mounted) return;
    final code = published.code;
    if (code == null) {
      final message = switch (published.failure) {
        RoomPublishFailure.permissionDenied =>
          'Sharing is updating on our side. Please try again shortly.',
        RoomPublishFailure.timedOut || RoomPublishFailure.network =>
          'The connection went quiet. Your space is safe — try again.',
        RoomPublishFailure.media =>
          'That photo could not be shared. Try another JPEG, PNG, or WebP under 3 MB.',
        RoomPublishFailure.exhaustedCodes =>
          'Couldn’t reserve a share code. Please try once more.',
        _ => 'Couldn’t share right now — try again.',
      };
      _toast(context, message);
      return;
    }
    if (state.roomCode != code) {
      state.setRoomCode(code);
      onPersist();
    }
    final sharedRoom = roomDisplay(
      state,
      mediaOwnerUid: cloud.socialUid,
      mediaRoomCode: code,
    );
    Sfx.instance.play('loot');
    await showShareSpaceDialog(
      context,
      code: code,
      ownerName: roomInviteOwnerName(state),
      rotatedCode: published.rotatedStaleCode,
      onPreview: () => Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => VisitRoomScreen(
            room: sharedRoom,
            code: code,
            themeId: state.canvasTheme,
            lively: !state.reduceMotion,
          ),
        ),
      ),
      onStop: () async {
        final stopped = await cloud.unshareRoom(code);
        if (!stopped) return false;
        state.setRoomCode(null);
        onPersist();
        return true;
      },
    );
  } finally {
    _sharingSpace = false;
  }
}

Future<void> showShareSpaceDialog(
  BuildContext context, {
  required String code,
  required Future<bool> Function() onStop,
  String? ownerName,
  bool rotatedCode = false,
  VoidCallback? onPreview,
}) {
  return showDialog<void>(
    context: context,
    barrierColor: Palette.dialogBarrier,
    builder: (_) => _ShareDialog(
      code: code,
      ownerName: ownerName,
      rotatedCode: rotatedCode,
      onPreview: onPreview,
      onStop: onStop,
    ),
  );
}

/// Prompt for a room code and keep the dialog open while the shared room is
/// validated and fetched. Circle and one-off visits share this exact handoff.
Future<SharedRoomVisit?> promptForSharedRoom(
  BuildContext context, {
  RoomFetcher? fetcher,
  String? initialCode,
  bool autoSubmit = false,
}) async {
  if (fetcher == null) {
    final cloud = CloudSync.instance;
    if (!await cloud.ensureAvailable()) {
      if (context.mounted) {
        _toast(context, 'Visiting needs a connection — try again in a moment.');
      }
      return null;
    }
    if (!context.mounted) return null;
    // Exact-code room reads are public bearer-key reads. Visiting should not
    // create an anonymous identity; one is acquired later only if the visitor
    // chooses a social write such as keeping the room in their Circle.
  }
  return showDialog<SharedRoomVisit>(
    context: context,
    builder: (_) => _VisitPrompt(
      fetcher: fetcher ?? CloudSync.instance.fetchRoom,
      initialCode: initialCode,
      autoSubmit: autoSubmit,
    ),
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
  String? initialCode,
  bool autoSubmit = false,
}) async {
  final result = await promptForSharedRoom(
    context,
    fetcher: fetcher,
    initialCode: initialCode,
    autoSubmit: autoSubmit,
  );
  if (result == null || !context.mounted) return;
  await Navigator.of(context).push(
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
  const _ShareDialog({
    required this.code,
    required this.onStop,
    this.ownerName,
    this.rotatedCode = false,
    this.onPreview,
  });
  final String code;
  final Future<bool> Function() onStop;
  final String? ownerName;
  final bool rotatedCode;
  final VoidCallback? onPreview;

  @override
  State<_ShareDialog> createState() => _ShareDialogState();
}

class _ShareDialogState extends State<_ShareDialog> {
  bool _inviting = false;
  bool _stopping = false;

  String get _invite =>
      roomInviteText(widget.code, ownerName: widget.ownerName);

  String get _inviteUrl => roomInviteUrl(widget.code);

  Future<void> _invitePeople() async {
    if (_inviting) return;
    setState(() => _inviting = true);
    final box = context.findRenderObject() as RenderBox?;
    final origin = box == null
        ? null
        : box.localToGlobal(Offset.zero) & box.size;
    final result = await shareText(_invite, origin: origin);
    if (!mounted) return;
    setState(() => _inviting = false);
    if (result == ShareTextResult.unavailable) {
      await Clipboard.setData(ClipboardData(text: _invite));
      if (mounted) {
        _toast(context, 'Sharing isn’t available here — invite copied');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: SingleChildScrollView(
          child: GlassPanel(
            blur: true,
            radius: 24,
            tint: Palette.dialogSurface,
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SHARE YOUR SPACE',
                  style: Type.label.copyWith(
                    fontSize: 10,
                    letterSpacing: 2.1,
                    color: Palette.textLo,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'Your space is live',
                  style: Type.display.copyWith(
                    fontSize: 22,
                    color: Palette.textHi,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  widget.rotatedCode
                      ? 'Your old code belonged to another sign-in, so this fresh one keeps both spaces safe.'
                      : 'This code is the key to your space.',
                  style: Type.body.copyWith(
                    fontSize: 13,
                    height: 1.4,
                    color: Palette.textMid,
                  ),
                ),
                const SizedBox(height: 15),
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 22,
                      vertical: 12,
                    ),
                    decoration: facetedDecoration(
                      cut: 10,
                      color: Palette.xp.withValues(alpha: 0.12),
                      borderColor: Palette.xp.withValues(alpha: 0.52),
                      shadows: const [
                        BoxShadow(
                          color: Palette.honeyGlow,
                          blurRadius: 18,
                          offset: Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Semantics(
                      label: 'Share code ${widget.code.split('').join(' ')}',
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
                ),
                const SizedBox(height: 15),
                HoneyButton(
                  key: const Key('share-space-invite'),
                  label: _inviting ? 'OPENING SHARE SHEET…' : 'INVITE PEOPLE',
                  icon: Icons.send_outlined,
                  enabled: !_inviting && !_stopping,
                  expand: true,
                  onTap: _invitePeople,
                ),
                const SizedBox(height: 7),
                Text(
                  'Choose Messages, Mail, WhatsApp, or another app. The invite opens this room in a browser.',
                  style: Type.body.copyWith(
                    fontSize: 11.5,
                    height: 1.35,
                    color: Palette.textLo,
                  ),
                ),
                const SizedBox(height: 11),
                if (widget.onPreview != null) ...[
                  _ShareUtilityAction(
                    key: const Key('share-space-preview'),
                    icon: Icons.visibility_outlined,
                    label: 'PREVIEW WHAT VISITORS SEE',
                    onTap: widget.onPreview!,
                    expand: true,
                  ),
                  const SizedBox(height: 8),
                ],
                LayoutBuilder(
                  builder: (context, constraints) {
                    final stacked =
                        constraints.maxWidth < 290 ||
                        MediaQuery.textScalerOf(context).scale(1) > 1.3;
                    final width = stacked
                        ? constraints.maxWidth
                        : (constraints.maxWidth - 8) / 2;
                    return Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        SizedBox(
                          width: width,
                          child: _ShareUtilityAction(
                            key: const Key('share-space-copy-link'),
                            icon: Icons.link_rounded,
                            label: 'COPY LINK',
                            onTap: () async {
                              await Clipboard.setData(
                                ClipboardData(text: _inviteUrl),
                              );
                              Sfx.instance.play('tick');
                              if (context.mounted) {
                                _toast(context, 'Invite link copied');
                              }
                            },
                          ),
                        ),
                        SizedBox(
                          width: width,
                          child: _ShareUtilityAction(
                            key: const Key('share-space-copy-code'),
                            icon: Icons.copy_rounded,
                            label: 'COPY CODE',
                            onTap: () async {
                              await Clipboard.setData(
                                ClipboardData(text: widget.code),
                              );
                              Sfx.instance.play('tick');
                              if (context.mounted) {
                                _toast(context, 'Code copied');
                              }
                            },
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: facetedDecoration(
                    cut: 8,
                    color: Palette.glassFill,
                    borderColor: Palette.glassEdge,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 1),
                        child: Icon(
                          Icons.shield_outlined,
                          size: 16,
                          color: Palette.success,
                        ),
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          'Anyone with this link can visit until you stop sharing. They see only the cards and photos you chose. A profile or This season photo appears only when you separately allow it; every other photo, Journal page, quest, and account detail stays private.',
                          style: Type.body.copyWith(
                            fontSize: 11,
                            height: 1.42,
                            color: Palette.textMid,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 2,
                    children: [
                      TextButton(
                        key: const Key('share-space-stop'),
                        onPressed: _stopping ? null : _stopSharing,
                        style: TextButton.styleFrom(
                          minimumSize: const Size(48, 48),
                          foregroundColor: Palette.textLo,
                        ),
                        child: Text(
                          _stopping ? 'STOPPING…' : 'STOP SHARING',
                          style: Type.label.copyWith(
                            fontSize: 10.5,
                            color: Palette.textLo,
                          ),
                        ),
                      ),
                      TextButton(
                        key: const Key('share-space-done'),
                        onPressed: _stopping
                            ? null
                            : () => Navigator.of(context).pop(),
                        style: TextButton.styleFrom(
                          minimumSize: const Size(48, 48),
                          foregroundColor: Palette.xpLight,
                        ),
                        child: Text(
                          'DONE',
                          style: Type.label.copyWith(
                            fontSize: 11.5,
                            color: Palette.xpLight,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _stopSharing() async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: Palette.dialogBarrier,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Palette.dialogSurface,
        shape: const FacetedBorder(cut: 12),
        title: Text(
          'Stop sharing this space?',
          style: Type.display.copyWith(fontSize: 20, color: Palette.textHi),
        ),
        content: Text(
          'This invite and code will stop working. Friends who kept it in their Circle will see that the space is unavailable.',
          style: Type.body.copyWith(
            fontSize: 13,
            height: 1.4,
            color: Palette.textMid,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(
              'KEEP SHARING',
              style: Type.label.copyWith(fontSize: 10.5),
            ),
          ),
          TextButton(
            key: const Key('share-space-confirm-stop'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              'STOP SHARING',
              style: Type.label.copyWith(fontSize: 10.5, color: Palette.danger),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _stopping = true);
    final stopped = await widget.onStop();
    if (!mounted) return;
    if (stopped) {
      Navigator.of(context).pop();
    } else {
      setState(() => _stopping = false);
      _toast(
        context,
        'Couldn’t stop sharing yet — your code is still safe here.',
      );
    }
  }
}

class _ShareUtilityAction extends StatelessWidget {
  const _ShareUtilityAction({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.expand = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool expand;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        customBorder: const FacetedBorder(cut: 8),
        onTap: onTap,
        child: Ink(
          decoration: facetedDecoration(
            cut: 8,
            color: Palette.glassFill,
            borderColor: Palette.glassEdge,
          ),
          child: Container(
            constraints: const BoxConstraints(minHeight: 48),
            width: expand ? double.infinity : null,
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 15, color: Palette.xpLight),
                const SizedBox(width: 7),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    style: Type.label.copyWith(
                      fontSize: 9.5,
                      color: Palette.xpLight,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _VisitPrompt extends StatefulWidget {
  const _VisitPrompt({
    required this.fetcher,
    this.initialCode,
    this.autoSubmit = false,
  });

  final RoomFetcher fetcher;
  final String? initialCode;
  final bool autoSubmit;

  @override
  State<_VisitPrompt> createState() => _VisitPromptState();
}

class _VisitPromptState extends State<_VisitPrompt> {
  late final TextEditingController _c;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _c = TextEditingController(text: widget.initialCode?.toUpperCase() ?? '');
    if (widget.autoSubmit && _roomCodePattern.hasMatch(_c.text)) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _visit());
    }
  }

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
            autofocus: !widget.autoSubmit,
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
