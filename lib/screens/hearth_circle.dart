import 'dart:async';

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../audio.dart';
import '../clock.dart';
import '../cloud.dart';
import '../content/creature_skins.dart';
import '../content/room_styles.dart';
import '../engine.dart';
import '../models.dart';
import '../social.dart';
import '../tokens.dart';
import '../widgets/detail_header.dart';
import '../widgets/ember_flame_icon.dart';
import '../widgets/facets.dart';
import '../widgets/glass.dart';
import '../widgets/home_room.dart';
import '../widgets/spark_picker.dart';
import 'visit_room.dart';

export '../widgets/spark_picker.dart';

class HearthCircleScreen extends StatefulWidget {
  const HearthCircleScreen({
    super.key,
    required this.state,
    required this.onPersist,
    this.parallax = const AlwaysStoppedAnimation(Offset.zero),
    this.roomFetcher,
    this.sparkSender,
    this.socialInboxFetcher,
  });

  final GameState state;
  final VoidCallback onPersist;
  final ValueListenable<Offset> parallax;
  final RoomFetcher? roomFetcher;
  final SparkSender? sparkSender;
  final SocialInboxFetcher? socialInboxFetcher;

  @override
  State<HearthCircleScreen> createState() => _HearthCircleScreenState();
}

class _HearthCircleScreenState extends State<HearthCircleScreen>
    with WidgetsBindingObserver {
  final Map<String, Map<String, dynamic>> _rooms = {};
  List<Map<String, dynamic>> _sparks = const [];
  List<Map<String, dynamic>> _circleAdds = const [];
  bool _loading = true;
  Timer? _ticker;
  int _now = Clock.now().millisecondsSinceEpoch;
  bool _wasCounting = false;

  GameState get _state => widget.state;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
    // The clock keeps time every second, but the screen only rebuilds while a
    // company countdown is actually running (plus one frame past its end so
    // the expired state lands) — a quiet Circle costs no frames.
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      _now = Clock.now().millisecondsSinceEpoch;
      final counting =
          _state.quietCompanyActive ||
          _rooms.values.any(
            (room) => ((room['focusUntil'] as num?)?.toInt() ?? 0) > _now,
          );
      if (counting || _wasCounting) setState(() {});
      _wasCounting = counting;
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Coming back to the app with the Circle open should show the circle as
    // it is now, not as it was when the screen first loaded.
    if (state == AppLifecycleState.resumed) _load();
  }

  Future<void> _load() async {
    final fetcher = widget.roomFetcher ?? CloudSync.instance.fetchRoom;
    if (widget.roomFetcher == null && !CloudSync.instance.available) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    final pairs = await Future.wait([
      for (final code in _state.hearthCircleCodes)
        fetcher(code).then((room) => (code, room)),
    ]);
    final code = _state.roomCode;
    ({List<Map<String, dynamic>> sparks, List<Map<String, dynamic>> circleAdds})
    inbox = (sparks: const [], circleAdds: const []);
    if (code != null && widget.socialInboxFetcher != null) {
      inbox = await widget.socialInboxFetcher!(code);
    } else if (code != null && CloudSync.instance.available) {
      await CloudSync.instance.ensureSocialSession();
      final receipts = await Future.wait([
        CloudSync.instance.fetchSparks(code),
        CloudSync.instance.fetchCircleAdds(code),
      ]);
      inbox = (sparks: receipts[0], circleAdds: receipts[1]);
    }
    if (!mounted) return;
    setState(() {
      _rooms.clear();
      for (final pair in pairs) {
        if (pair.$2 != null) _rooms[pair.$1] = pair.$2!;
      }
      _sparks = inbox.sparks;
      _circleAdds = inbox.circleAdds;
      _loading = false;
    });
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: Palette.card,
          content: Text(
            message,
            style: Type.body.copyWith(color: Palette.textHi),
          ),
        ),
      );
  }

  Future<void> _notifyOwnerOfCircleAdd(String code) async {
    final cloud = CloudSync.instance;
    if (!await cloud.ensureAvailable() || !await cloud.ensureSocialSession()) {
      return;
    }
    await cloud.sendCircleAdd(code);
  }

  Future<void> _addKeep() async {
    final visit = await promptForSharedRoom(
      context,
      fetcher: widget.roomFetcher,
    );
    if (visit == null || !mounted) return;
    final clean = visit.code;
    if (!_state.addCircleCode(clean)) {
      _toast(
        _state.hearthCircleCodes.length >= 5
            ? 'A Circle holds up to five trusted spaces.'
            : 'That space is already in your Circle.',
      );
      return;
    }
    widget.onPersist();
    unawaited(_notifyOwnerOfCircleAdd(clean));
    Sfx.instance.play('loot');
    HapticFeedback.mediumImpact();
    setState(() => _rooms[clean] = visit.room);
    // The other half of a mutual circle: they can only see you back if they
    // hold your code. One dismissible offer, right when it's most natural.
    // The whole snackbar is the tap target — a separate action slot cannot
    // survive 2x accessibility text on a 320dp phone.
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: Palette.card,
          content: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              messenger.hideCurrentSnackBar();
              shareSpace(context, _state, widget.onPersist);
            },
            child: Text.rich(
              TextSpan(
                text: 'Kept. ',
                children: [
                  TextSpan(
                    text: 'Tap to send your code back.',
                    style: TextStyle(color: Palette.xpLight),
                  ),
                ],
              ),
              style: Type.body.copyWith(color: Palette.textHi),
            ),
          ),
        ),
      );
  }

  Future<bool> _publishNow() async {
    final cloud = CloudSync.instance;
    if (!await cloud.ensureAvailable() || !await cloud.ensureSocialSession()) {
      _toast('Couldn’t connect quiet company right now.');
      return false;
    }
    final result = await publishSpaceRoomState(
      _state,
      current: _state,
      code: _state.roomCode,
    );
    final code = result.code;
    if (!mounted || code == null) {
      if (mounted) _toast('Couldn’t update your shared space right now.');
      return false;
    }
    if (_state.roomCode != code) _state.setRoomCode(code);
    widget.onPersist();
    return true;
  }

  Future<void> _startCompany(String kind, int minutes) async {
    _state.startQuietCompany(kind, Duration(minutes: minutes));
    final ok = await _publishNow();
    if (!ok) {
      _state.stopQuietCompany();
      return;
    }
    if (!mounted) return;
    setState(() => _now = Clock.now().millisecondsSinceEpoch);
    Sfx.instance.play('streak');
    HapticFeedback.mediumImpact();
  }

  Future<void> _joinCompany(String code, Map<String, dynamic> room) async {
    final until = room['focusUntil'] is num
        ? (room['focusUntil'] as num).toInt()
        : 0;
    final left = until - _now;
    if (left <= 0) {
      _toast('That quiet-company session has just settled.');
      return;
    }
    final kind = room['focusKind'] is String
        ? room['focusKind'] as String
        : 'quiet';
    if (!await _confirmFirstShare()) return;
    _state.startQuietCompany(kind, Duration(milliseconds: left));
    final ok = await _publishNow();
    if (!ok) {
      _state.stopQuietCompany();
    } else {
      // Sitting down should be felt on the other side of the fire. A steady
      // note is the app's quietest receipt; the one-pending-per-sender rule
      // keeps it from ever stacking.
      unawaited(CloudSync.instance.sendSpark(code, kind: 'steady'));
    }
    if (mounted) setState(() {});
  }

  Future<void> _endCompany() async {
    _state.stopQuietCompany();
    widget.onPersist();
    await _publishNow();
    if (mounted) setState(() {});
  }

  Future<void> _chooseSpark(String code) async {
    Sfx.instance.play('tick');
    final kind = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Palette.dialogBarrier,
      builder: (_) => const SparkPickerSheet(),
    );
    if (kind == null || !mounted) return;
    await _sendSpark(code, kind);
  }

  Future<void> _sendSpark(String code, String kind) async {
    Sfx.instance.play('tick');
    final sender = widget.sparkSender;
    if (sender == null && !await CloudSync.instance.ensureSocialSession()) {
      if (mounted) _toast('Couldn’t connect your note right now.');
      return;
    }
    final safeKind = normalizedSparkKind(kind);
    final result = sender == null
        ? await CloudSync.instance.sendSpark(code, kind: safeKind)
        : (await sender(code, safeKind)
              ? SparkSendResult.sent
              : SparkSendResult.failed);
    if (!mounted) return;
    switch (result) {
      case SparkSendResult.sent:
        Sfx.instance.play('streak');
        HapticFeedback.mediumImpact();
        _toast('${sparkSupportReceiptLabel(safeKind)} is waiting in $code.');
      case SparkSendResult.alreadyWaiting:
        _toast('A note from you is already waiting by their fire.');
      case SparkSendResult.failed:
        _toast('The connection went quiet — try again in a bit.');
    }
  }

  Future<void> _collectInbox() async {
    final code = _state.roomCode;
    if (code == null || (_sparks.isEmpty && _circleAdds.isEmpty)) return;
    final results = await Future.wait([
      _sparks.isEmpty
          ? Future.value(true)
          : CloudSync.instance.collectSparks(
              code,
              _sparks.map((e) => e['id']).whereType<String>(),
            ),
      _circleAdds.isEmpty
          ? Future.value(true)
          : CloudSync.instance.collectCircleAdds(
              code,
              _circleAdds.map((e) => e['id']).whereType<String>(),
            ),
    ]);
    if (!mounted || results.any((ok) => !ok)) return;
    setState(() {
      _sparks = const [];
      _circleAdds = const [];
    });
    Sfx.instance.play('loot');
    HapticFeedback.mediumImpact();
  }

  void _openSessionPicker() {
    Sfx.instance.play('tick');
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Palette.dialogBarrier,
      // Quiet company lives on the shared-room record. An unshared space gets
      // the honest version of the sheet: the line that says lighting the
      // timer shares the room, and a button that owns it.
      builder: (_) => _QuietCompanySheet(
        onStart: _startCompany,
        firstShare: _state.roomCode == null,
      ),
    );
  }

  /// Joining company also publishes your room. Someone who has never shared
  /// gets asked once, in plain words, before a code is minted on their behalf
  /// — sharing must never switch itself on (see shell.dart's invariant).
  Future<bool> _confirmFirstShare() async {
    if (_state.roomCode != null) return true;
    final agreed = await showDialog<bool>(
      context: context,
      barrierColor: Palette.dialogBarrier,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: GlassPanel(
          tint: const Color(0xF22A211D),
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const EmberFlameIcon(size: 26, color: Palette.xpLight),
              const SizedBox(height: 10),
              Text(
                'Share your space to sit together?',
                textAlign: TextAlign.center,
                style: Type.display.copyWith(fontSize: 18),
              ),
              const SizedBox(height: 6),
              Text(
                'Your space isn’t shared yet. Sitting in company shares it '
                'with a room code — that’s how friends see you beside their '
                'fire. You can stop sharing any time from Me.',
                textAlign: TextAlign.center,
                style: Type.body.copyWith(
                  fontSize: 13.5,
                  color: Palette.textMid,
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 10,
                runSpacing: 10,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(ctx).pop(false),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 9,
                      ),
                      decoration: facetedDecoration(
                        cut: 8,
                        borderColor: Palette.glassEdge,
                      ),
                      child: Text(
                        'NOT NOW',
                        style: Type.label.copyWith(
                          fontSize: 11,
                          color: Palette.textMid,
                        ),
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.of(ctx).pop(true),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 9,
                      ),
                      decoration: facetedDecoration(
                        cut: 8,
                        gradient: Palette.honeyGradient,
                      ),
                      child: Text(
                        'SHARE + SIT DOWN',
                        style: Type.label.copyWith(
                          fontSize: 11,
                          color: Palette.onHoney,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    return agreed == true && mounted;
  }

  int get _circleLit {
    var lit = (widget.state.history[Days.key(Clock.now())] ?? 0) > 0 ? 1 : 0;
    lit += _rooms.values.where((room) => room['todayLit'] == true).length;
    return lit;
  }

  @override
  Widget build(BuildContext context) {
    final total = _state.hearthCircleCodes.length + 1;
    return Scaffold(
      backgroundColor: Palette.parchment,
      body: WarmBackground(
        themeId: _state.canvasTheme,
        tint: Palette.streak,
        reduceMotion: _state.reduceMotion,
        child: SafeArea(
          child: Column(
            children: [
              DetailHeader(
                title: 'Circle',
                subtitle:
                    'trusted spaces · quiet encouragement · no leaderboard',
                accent: Palette.xp,
                pill: '${_state.hearthCircleCodes.length}/5',
              ),
              Expanded(
                child: RefreshIndicator(
                  color: Palette.xp,
                  backgroundColor: Palette.card,
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 40),
                    children: [
                      _CircleLantern(lit: _circleLit, total: total),
                      const SizedBox(height: 12),
                      if (_sparks.isNotEmpty || _circleAdds.isNotEmpty) ...[
                        _IncomingSparks(
                          sparks: _sparks,
                          circleCount: _circleAdds.length,
                          onCollect: _collectInbox,
                        ),
                        const SizedBox(height: 12),
                      ],
                      _QuietCompanyCard(
                        active: _state.quietCompanyActive,
                        kind: _state.quietCompanyKind,
                        remainingMs: (_state.quietCompanyUntil - _now).clamp(
                          0,
                          75 * 60 * 1000,
                        ),
                        onStart: _openSessionPicker,
                        onEnd: _endCompany,
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'TRUSTED SPACES',
                              style: Type.label.copyWith(
                                fontSize: 11,
                                color: Palette.textHi,
                              ),
                            ),
                          ),
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: _addKeep,
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(
                                minWidth: 44,
                                minHeight: 44,
                              ),
                              child: Center(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                  ),
                                  child: Text(
                                    '+ ADD CODE',
                                    textAlign: TextAlign.center,
                                    style: Type.label.copyWith(
                                      fontSize: Type.minLabel,
                                      color: Palette.xpLight,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (_loading)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(28),
                            child: CircularProgressIndicator(
                              color: Palette.xp,
                              strokeWidth: 2,
                            ),
                          ),
                        )
                      else if (_state.hearthCircleCodes.isEmpty)
                        _EmptyCircle(
                          state: _state,
                          parallax: widget.parallax,
                          onAdd: _addKeep,
                          onShare: () =>
                              shareSpace(context, _state, widget.onPersist),
                        )
                      else
                        for (final code in _state.hearthCircleCodes) ...[
                          _CircleKeepCard(
                            code: code,
                            room: _rooms[code],
                            nowMs: _now,
                            parallax: widget.parallax,
                            onVisit: _rooms[code] == null
                                ? null
                                : () => Navigator.of(context)
                                      .push(
                                        MaterialPageRoute(
                                          builder: (_) => VisitRoomScreen(
                                            room: _rooms[code]!,
                                            code: code,
                                            themeId: _state.canvasTheme,
                                            lively: !_state.reduceMotion,
                                            parallax: widget.parallax,
                                            localState: _state,
                                            onPersist: widget.onPersist,
                                          ),
                                        ),
                                      )
                                      // Fresh presence on the way back — the
                                      // room may have lit or sat down while
                                      // you were inside it.
                                      .then((_) {
                                        if (mounted) _load();
                                      }),
                            onSpark: _rooms[code] == null
                                ? null
                                : () => _chooseSpark(code),
                            onJoin:
                                _rooms[code] != null &&
                                    ((_rooms[code]!['focusUntil'] as num?)
                                                ?.toInt() ??
                                            0) >
                                        _now
                                ? () => _joinCompany(code, _rooms[code]!)
                                : null,
                            onRemove: () {
                              _state.removeCircleCode(code);
                              widget.onPersist();
                              setState(() => _rooms.remove(code));
                            },
                          ),
                          const SizedBox(height: 10),
                        ],
                      const SizedBox(height: 8),
                      Text(
                        'You see the spaces you keep here. They see yours only if they hold your code too. Your quests and Journal stay private.',
                        textAlign: TextAlign.center,
                        style: Type.body.copyWith(
                          fontSize: 11,
                          height: 1.4,
                          fontStyle: FontStyle.italic,
                          color: Palette.textLo,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CircleLantern extends StatelessWidget {
  const _CircleLantern({required this.lit, required this.total});
  final int lit;
  final int total;

  @override
  Widget build(BuildContext context) {
    final medallion = FacetMedallion(
      size: 62,
      accent: Palette.streak,
      glow: lit > 0,
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Palette.specular.withValues(alpha: lit > 0 ? 0.34 : 0.1),
          Palette.streak.withValues(alpha: lit > 0 ? 0.24 : 0.07),
        ],
      ),
      child: Icon(
        Icons.light_outlined,
        size: 29,
        color: lit > 0 ? Palette.xpLight : Palette.textLo,
      ),
    );
    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('The Circle Lantern', style: Type.display.copyWith(fontSize: 21)),
        const SizedBox(height: 3),
        Text(
          '$lit of $total room${total == 1 ? '' : 's'} active today',
          style: Type.body.copyWith(fontSize: 12.5, color: Palette.textLo),
        ),
        const SizedBox(height: 9),
        FacetedMeter(
          value: total == 0 ? 0 : lit / total,
          color: Palette.streak,
          glow: lit > 0,
        ),
      ],
    );
    final large =
        MediaQuery.textScalerOf(context).scale(1) > 1.15 ||
        MediaQuery.sizeOf(context).width < 360;
    return GlassPanel(
      glow: lit > 0,
      child: large
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [medallion, const SizedBox(height: 12), details],
            )
          : Row(
              children: [
                medallion,
                const SizedBox(width: 14),
                Expanded(child: details),
              ],
            ),
    );
  }
}

class _IncomingSparks extends StatelessWidget {
  const _IncomingSparks({
    required this.sparks,
    required this.circleCount,
    required this.onCollect,
  });
  final List<Map<String, dynamic>> sparks;
  final int circleCount;
  final VoidCallback onCollect;

  String get message {
    if (circleCount > 0 && sparks.isNotEmpty) {
      return '${circleCount == 1 ? 'Someone added your space' : '$circleCount people added your space'} to their Circle · support is waiting too';
    }
    if (circleCount > 0) {
      return circleCount == 1
          ? 'Someone added your space to their Circle'
          : '$circleCount people added your space to their Circle';
    }
    return 'Support is waiting by your door';
  }

  Map<String, int> get counts {
    final result = <String, int>{};
    for (final spark in sparks) {
      final kind = normalizedSparkKind(spark['kind']);
      result[kind] = (result[kind] ?? 0) + 1;
    }
    return result;
  }

  @override
  Widget build(BuildContext context) => GlassPanel(
    glow: true,
    padding: const EdgeInsets.all(13),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.auto_awesome, size: 20, color: Palette.xpLight),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: Type.body.copyWith(fontSize: 13, color: Palette.textHi),
              ),
            ),
            Semantics(
              button: true,
              label: 'Collect Circle support',
              onTap: onCollect,
              child: GestureDetector(
                excludeFromSemantics: true,
                behavior: HitTestBehavior.opaque,
                onTap: onCollect,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    minWidth: 48,
                    minHeight: 48,
                  ),
                  child: Center(
                    child: Text(
                      'COLLECT',
                      style: Type.label.copyWith(
                        fontSize: Type.minLabel,
                        color: Palette.xpLight,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        if (sparks.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              for (final kind in sparkSupportKinds)
                if ((counts[kind] ?? 0) > 0)
                  _SparkReceiptChip(kind: kind, count: counts[kind]!),
            ],
          ),
        ],
      ],
    ),
  );
}

class _SparkReceiptChip extends StatelessWidget {
  const _SparkReceiptChip({required this.kind, required this.count});

  final String kind;
  final int count;

  @override
  Widget build(BuildContext context) {
    final title = sparkSupportTitle(kind);
    return Semantics(
      label: count == 1
          ? sparkSupportReceiptLabel(kind)
          : '$count ${sparkSupportReceiptPlural(kind)}',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
        decoration: facetedDecoration(
          cut: 6,
          color: sparkSupportColor(kind).withValues(alpha: 0.1),
          borderColor: sparkSupportColor(kind).withValues(alpha: 0.38),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              sparkSupportIcon(kind),
              size: 13,
              color: sparkSupportColor(kind),
            ),
            const SizedBox(width: 5),
            Text(
              '${count > 1 ? '$count× ' : ''}${title.toUpperCase()}',
              style: Type.label.copyWith(
                fontSize: Type.minLabel,
                color: sparkSupportColor(kind),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuietCompanyCard extends StatelessWidget {
  const _QuietCompanyCard({
    required this.active,
    required this.kind,
    required this.remainingMs,
    required this.onStart,
    required this.onEnd,
  });
  final bool active;
  final String kind;
  final int remainingMs;
  final VoidCallback onStart;
  final VoidCallback onEnd;

  @override
  Widget build(BuildContext context) {
    final seconds = (remainingMs / 1000).ceil();
    final time =
        '${(seconds ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';
    final action = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: active ? onEnd : onStart,
      child: Container(
        constraints: const BoxConstraints(minHeight: 44),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
        decoration: facetedDecoration(
          cut: 7,
          color: Palette.unlock.withValues(alpha: 0.1),
          borderColor: Palette.unlock.withValues(alpha: 0.42),
        ),
        child: Text(
          active ? 'END' : 'BEGIN',
          style: Type.label.copyWith(
            fontSize: Type.minLabel,
            color: Palette.unlock,
          ),
        ),
      ),
    );
    final copy = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          active ? '$time · ${kind.toUpperCase()}' : 'Quiet Company',
          style: Type.display.copyWith(fontSize: 18),
        ),
        const SizedBox(height: 2),
        Text(
          active
              ? 'your presence is visible · your actual task is not'
              : 'light a private focus timer friends can sit beside',
          style: Type.body.copyWith(fontSize: 11.5, color: Palette.textLo),
        ),
      ],
    );
    final large =
        MediaQuery.textScalerOf(context).scale(1) > 1.15 ||
        MediaQuery.sizeOf(context).width < 360;
    return GlassPanel(
      glow: active,
      child: large
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FacetMedallion(
                      size: 44,
                      accent: Palette.unlock,
                      glow: active,
                      child: Icon(
                        active ? Icons.hourglass_top : Icons.people_outline,
                        size: 21,
                        color: Palette.unlock,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: copy),
                  ],
                ),
                const SizedBox(height: 10),
                SizedBox(width: double.infinity, child: action),
              ],
            )
          : Row(
              children: [
                FacetMedallion(
                  size: 44,
                  accent: Palette.unlock,
                  glow: active,
                  child: Icon(
                    active ? Icons.hourglass_top : Icons.people_outline,
                    size: 21,
                    color: Palette.unlock,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(child: copy),
                const SizedBox(width: 8),
                action,
              ],
            ),
    );
  }
}

class _CircleKeepCard extends StatelessWidget {
  const _CircleKeepCard({
    required this.code,
    required this.room,
    required this.nowMs,
    required this.parallax,
    required this.onVisit,
    required this.onSpark,
    required this.onJoin,
    required this.onRemove,
  });
  final String code;
  final Map<String, dynamic>? room;
  final int nowMs;
  final ValueListenable<Offset> parallax;
  final VoidCallback? onVisit;
  final VoidCallback? onSpark;
  final VoidCallback? onJoin;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final data = room;
    if (data == null) {
      return GlassPanel(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            const Icon(Icons.cloud_off_outlined, color: Palette.textLo),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '$code · space unavailable',
                style: Type.body.copyWith(fontSize: 13, color: Palette.textLo),
              ),
            ),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onRemove,
              child: const SizedBox.square(
                dimension: 44,
                child: Center(
                  child: Icon(Icons.close, size: 17, color: Palette.textLo),
                ),
              ),
            ),
          ],
        ),
      );
    }
    String string(String key, [String fallback = '', int max = 80]) {
      final value = data[key];
      if (value is! String) return fallback;
      return String.fromCharCodes(value.trim().runes.take(max));
    }

    final sharedName = data['profileVisible'] == true
        ? string('displayName', '', 40)
        : '';
    final keeperName = sharedName.isNotEmpty
        ? sharedName
        : string('name', 'Fellow keeper', 40);
    final buildTitle = string('title', 'KEEPER', 64);
    final level = data['level'] is num ? (data['level'] as num).toInt() : 1;
    final furniture = data['furniture'] is List
        ? (data['furniture'] as List).whereType<String>().toSet()
        : <String>{};
    final memories = data['memories'] is num
        ? (data['memories'] as num).toInt()
        : 0;
    final focusUntil = data['focusUntil'] is num
        ? (data['focusUntil'] as num).toInt()
        : 0;
    return GlassPanel(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipPath(
            clipper: const FacetedClipper(cut: 10),
            child: SizedBox(
              height: 112,
              child: HomeRoom(
                lively: false,
                level: level,
                unlocked: furniture,
                wall: wallColorsById(string('wall')),
                plateId: string('wall'),
                floor: floorColorsById(string('floor')),
                window: string('window', 'moon'),
                petAwake: data['awake'] == true,
                emberGlow: flameHueById(string('skin')),
                heirloomFlame: heirloomFlameById(string('skin')),
                memoryArtifacts: memories,
                parallax: parallax,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      keeperName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Type.display.copyWith(fontSize: 17),
                    ),
                    Text(
                      '$code · $buildTitle · LEVEL $level · $memories MEMORIES',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Type.label.copyWith(fontSize: Type.minLabel),
                    ),
                  ],
                ),
              ),
              if (data['todayLit'] == true)
                const Icon(Icons.auto_awesome, size: 16, color: Palette.streak),
              if (focusUntil > nowMs) ...[
                const SizedBox(width: 7),
                const Icon(
                  Icons.hourglass_top,
                  size: 16,
                  color: Palette.unlock,
                ),
              ],
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onRemove,
                child: const SizedBox.square(
                  dimension: 44,
                  child: Center(
                    child: Icon(Icons.close, size: 16, color: Palette.textLo),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              _CircleAction(
                label: 'VISIT',
                icon: Icons.visibility_outlined,
                onTap: onVisit,
              ),
              _CircleAction(
                label: 'SEND A NOTE',
                icon: Icons.auto_awesome,
                onTap: onSpark,
              ),
              if (onJoin != null)
                _CircleAction(
                  label: 'SIT IN QUIET COMPANY',
                  icon: Icons.people_outline,
                  onTap: onJoin,
                  highlight: true,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CircleAction extends StatelessWidget {
  const _CircleAction({
    required this.label,
    required this.icon,
    required this.onTap,
    this.highlight = false,
  });
  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final bool highlight;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    enabled: onTap != null,
    label: label,
    onTap: onTap,
    child: GestureDetector(
      excludeFromSemantics: true,
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: facetedDecoration(
          cut: 7,
          color: highlight
              ? Palette.unlock.withValues(alpha: 0.13)
              : Colors.transparent,
          borderColor: highlight
              ? Palette.unlock.withValues(alpha: 0.5)
              : Palette.glassEdge,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 12,
              color: onTap == null
                  ? Palette.textLo
                  : highlight
                  ? Palette.unlock
                  : Palette.xpLight,
            ),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                label,
                maxLines: 2,
                textAlign: TextAlign.center,
                style: Type.label.copyWith(
                  fontSize: Type.minLabel,
                  color: onTap == null
                      ? Palette.textLo
                      : highlight
                      ? Palette.unlock
                      : Palette.xpLight,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _EmptyCircle extends StatelessWidget {
  const _EmptyCircle({
    required this.state,
    required this.parallax,
    required this.onAdd,
    required this.onShare,
  });
  final GameState state;
  final ValueListenable<Offset> parallax;
  final VoidCallback onAdd;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) => GlassPanel(
    child: Column(
      children: [
        ClipPath(
          clipper: const FacetedClipper(cut: 10),
          child: SizedBox(
            height: 132,
            child: HomeRoom(
              plateId: state.wallStyle,
              lively: !state.reduceMotion,
              level: state.level,
              unlocked: const {},
              window: state.windowScene,
              petAwake: state.streakDays > 0,
              emberGlow: flameHueFor(state),
              heirloomFlame: heirloomFlameFor(state),
              memoryArtifacts: state.memoryPins.length,
              parallax: state.reduceMotion ? null : parallax,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Your room is ready for company',
          style: Type.display.copyWith(fontSize: 19),
        ),
        const SizedBox(height: 5),
        Text(
          'A Circle has two halves: keep the code of someone you trust, and '
          'send them yours. Each code shows its holder one room.',
          textAlign: TextAlign.center,
          style: Type.body.copyWith(fontSize: 12.5, color: Palette.textLo),
        ),
        const SizedBox(height: 12),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            _CircleAction(label: 'ADD A SPACE', icon: Icons.add, onTap: onAdd),
            _CircleAction(
              label: state.roomCode == null
                  ? 'SHARE MY CODE'
                  : 'SEND MY CODE · ${state.roomCode}',
              icon: Icons.ios_share,
              onTap: onShare,
            ),
          ],
        ),
      ],
    ),
  );
}

class _QuietCompanySheet extends StatefulWidget {
  const _QuietCompanySheet({required this.onStart, required this.firstShare});

  /// True when the room has never been shared — starting the timer will mint
  /// a share code, and the sheet says so before the button is pressed.
  final bool firstShare;
  final Future<void> Function(String kind, int minutes) onStart;

  @override
  State<_QuietCompanySheet> createState() => _QuietCompanySheetState();
}

class _QuietCompanySheetState extends State<_QuietCompanySheet> {
  String _kind = 'quiet';
  int _minutes = 25;
  bool _busy = false;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: GlassPanel(
      tint: Palette.dialogSurface,
      radius: 24,
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 46,
              height: 3,
              color: Palette.textLo.withValues(alpha: 0.45),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Start quiet company',
            style: Type.display.copyWith(fontSize: 22),
          ),
          const SizedBox(height: 5),
          Text(
            'Friends may join the timer. Nobody sees what you are working on, and there is no camera or chat.',
            style: Type.body.copyWith(
              fontSize: 12.5,
              height: 1.4,
              color: Palette.textLo,
            ),
          ),
          if (widget.firstShare) ...[
            const SizedBox(height: 8),
            Text(
              'Your space isn’t shared yet — lighting the timer shares it '
              'with a room code, so friends who hold it can sit with you.',
              style: Type.body.copyWith(
                fontSize: 12.5,
                height: 1.4,
                color: Palette.textMid,
              ),
            ),
          ],
          const SizedBox(height: 18),
          Text(
            'WHAT KIND OF COMPANY?',
            style: Type.label.copyWith(fontSize: Type.minLabel),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              for (final item in const [
                ('quiet', 'QUIET', Icons.air),
                ('study', 'STUDY', Icons.school_outlined),
                ('making', 'MAKING', Icons.auto_awesome_outlined),
                ('reset', 'HOME RESET', Icons.cottage_outlined),
              ])
                _SheetChoice(
                  label: item.$2,
                  icon: item.$3,
                  selected: _kind == item.$1,
                  onTap: () => setState(() => _kind = item.$1),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'HOW LONG?',
            style: Type.label.copyWith(fontSize: Type.minLabel),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              for (final minutes in const [25, 50, 75]) ...[
                Expanded(
                  child: _SheetChoice(
                    label: '$minutes MIN',
                    icon: Icons.hourglass_bottom,
                    selected: _minutes == minutes,
                    onTap: () => setState(() => _minutes = minutes),
                  ),
                ),
                if (minutes != 75) const SizedBox(width: 7),
              ],
            ],
          ),
          const SizedBox(height: 18),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _busy
                ? null
                : () async {
                    setState(() => _busy = true);
                    Navigator.of(context).pop();
                    await widget.onStart(_kind, _minutes);
                  },
            child: Container(
              width: double.infinity,
              constraints: const BoxConstraints(minHeight: 50),
              alignment: Alignment.center,
              decoration: facetedDecoration(
                cut: 10,
                gradient: Palette.honeyGradient,
                borderColor: Palette.xpLight.withValues(alpha: 0.8),
              ),
              child: Text(
                widget.firstShare
                    ? 'SHARE + LIGHT THE TIMER'
                    : 'LIGHT THE TIMER',
                style: Type.label.copyWith(
                  fontSize: 11,
                  color: Palette.onHoney,
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _SheetChoice extends StatelessWidget {
  const _SheetChoice({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () {
      Sfx.instance.play('tick');
      HapticFeedback.selectionClick();
      onTap();
    },
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: facetedDecoration(
        cut: 7,
        color: selected
            ? Palette.unlock.withValues(alpha: 0.16)
            : Colors.transparent,
        borderColor: selected
            ? Palette.unlock.withValues(alpha: 0.55)
            : Palette.glassEdge,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 13,
            color: selected ? Palette.unlock : Palette.textLo,
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: Type.label.copyWith(
              fontSize: Type.minLabel,
              color: selected ? Palette.unlock : Palette.textMid,
            ),
          ),
        ],
      ),
    ),
  );
}
