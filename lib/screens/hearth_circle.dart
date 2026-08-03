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
import '../widgets/facets.dart';
import '../widgets/glass.dart';
import '../widgets/home_room.dart';
import 'visit_room.dart';

class HearthCircleScreen extends StatefulWidget {
  const HearthCircleScreen({
    super.key,
    required this.state,
    required this.onPersist,
    this.parallax = const AlwaysStoppedAnimation(Offset.zero),
    this.roomFetcher,
  });

  final GameState state;
  final VoidCallback onPersist;
  final ValueListenable<Offset> parallax;
  final RoomFetcher? roomFetcher;

  @override
  State<HearthCircleScreen> createState() => _HearthCircleScreenState();
}

class _HearthCircleScreenState extends State<HearthCircleScreen> {
  final Map<String, Map<String, dynamic>> _rooms = {};
  List<Map<String, dynamic>> _sparks = const [];
  bool _loading = true;
  Timer? _ticker;
  int _now = Clock.now().millisecondsSinceEpoch;

  GameState get _state => widget.state;

  @override
  void initState() {
    super.initState();
    _load();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _now = Clock.now().millisecondsSinceEpoch);
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    if (!CloudSync.instance.available) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    final pairs = await Future.wait([
      for (final code in _state.hearthCircleCodes)
        CloudSync.instance.fetchRoom(code).then((room) => (code, room)),
    ]);
    final sparks = _state.roomCode == null
        ? const <Map<String, dynamic>>[]
        : await CloudSync.instance.fetchSparks(_state.roomCode!);
    if (!mounted) return;
    setState(() {
      _rooms.clear();
      for (final pair in pairs) {
        if (pair.$2 != null) _rooms[pair.$1] = pair.$2!;
      }
      _sparks = sparks;
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
    Sfx.instance.play('loot');
    HapticFeedback.mediumImpact();
    setState(() => _rooms[clean] = visit.room);
  }

  Future<bool> _publishNow() async {
    final cloud = CloudSync.instance;
    if (!cloud.available || !await cloud.ensureSocialSession()) {
      _toast('Couldn’t connect quiet company right now.');
      return false;
    }
    final code = await cloud.shareRoom(
      roomDisplay(_state),
      code: _state.roomCode,
    );
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

  Future<void> _joinCompany(Map<String, dynamic> room) async {
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
    _state.startQuietCompany(kind, Duration(milliseconds: left));
    final ok = await _publishNow();
    if (!ok) _state.stopQuietCompany();
    if (mounted) setState(() {});
  }

  Future<void> _endCompany() async {
    _state.stopQuietCompany();
    widget.onPersist();
    await _publishNow();
    if (mounted) setState(() {});
  }

  Future<void> _sendSpark(String code) async {
    Sfx.instance.play('tick');
    if (!await CloudSync.instance.ensureSocialSession()) {
      if (mounted) _toast('Couldn’t connect your note right now.');
      return;
    }
    final ok = await CloudSync.instance.sendSpark(code);
    if (!mounted) return;
    if (ok) {
      Sfx.instance.play('streak');
      HapticFeedback.mediumImpact();
      _toast('A warm note is waiting in $code.');
    } else {
      _toast('A note from you may already be waiting there.');
    }
  }

  Future<void> _collectSparks() async {
    final code = _state.roomCode;
    if (code == null || _sparks.isEmpty) return;
    final ids = _sparks.map((e) => e['id']).whereType<String>();
    final ok = await CloudSync.instance.collectSparks(code, ids);
    if (!mounted || !ok) return;
    setState(() => _sparks = const []);
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
      builder: (_) => _QuietCompanySheet(onStart: _startCompany),
    );
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
                      if (_sparks.isNotEmpty) ...[
                        _IncomingSparks(
                          count: _sparks.length,
                          onCollect: _collectSparks,
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
                                      fontSize: 10.5,
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
                                : () => Navigator.of(context).push(
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
                                  ),
                            onSpark: _rooms[code] == null
                                ? null
                                : () => _sendSpark(code),
                            onJoin:
                                _rooms[code] != null &&
                                    ((_rooms[code]!['focusUntil'] as num?)
                                                ?.toInt() ??
                                            0) >
                                        _now
                                ? () => _joinCompany(_rooms[code]!)
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
                        'People in your Circle can see your room and whether you’re around. Your quests and Journal stay private.',
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
  const _IncomingSparks({required this.count, required this.onCollect});
  final int count;
  final VoidCallback onCollect;

  @override
  Widget build(BuildContext context) => GlassPanel(
    glow: true,
    padding: const EdgeInsets.all(13),
    child: Row(
      children: [
        const Icon(Icons.auto_awesome, size: 20, color: Palette.xpLight),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            '$count warm ${count == 1 ? 'note is' : 'notes are'} waiting by your door',
            style: Type.body.copyWith(fontSize: 13, color: Palette.textHi),
          ),
        ),
        GestureDetector(
          onTap: onCollect,
          child: Text(
            'COLLECT',
            style: Type.label.copyWith(fontSize: 10, color: Palette.xpLight),
          ),
        ),
      ],
    ),
  );
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
          style: Type.label.copyWith(fontSize: 9.5, color: Palette.unlock),
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
    String string(String key, [String fallback = '']) =>
        data[key] is String ? data[key] as String : fallback;
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
                heirloomFlame: string('skin') == 'gilded',
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
                      string('title', 'FELLOW KEEPER'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Type.display.copyWith(fontSize: 17),
                    ),
                    Text(
                      '$code · LEVEL $level · $memories MEMORIES',
                      style: Type.label.copyWith(fontSize: 8.5),
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
                  fontSize: 8.5,
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
  });
  final GameState state;
  final ValueListenable<Offset> parallax;
  final VoidCallback onAdd;

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
              heirloomFlame: state.creatureSkin == 'gilded',
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
          'Add the room code of someone you trust. You’ll see each other’s rooms and can share quiet encouragement.',
          textAlign: TextAlign.center,
          style: Type.body.copyWith(fontSize: 12.5, color: Palette.textLo),
        ),
        const SizedBox(height: 12),
        _CircleAction(label: 'ADD A SPACE', icon: Icons.add, onTap: onAdd),
      ],
    ),
  );
}

class _QuietCompanySheet extends StatefulWidget {
  const _QuietCompanySheet({required this.onStart});
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
          const SizedBox(height: 18),
          Text(
            'WHAT KIND OF COMPANY?',
            style: Type.label.copyWith(fontSize: 10),
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
          Text('HOW LONG?', style: Type.label.copyWith(fontSize: 10)),
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
                'LIGHT THE TIMER',
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
              fontSize: 8.5,
              color: selected ? Palette.unlock : Palette.textMid,
            ),
          ),
        ],
      ),
    ),
  );
}
