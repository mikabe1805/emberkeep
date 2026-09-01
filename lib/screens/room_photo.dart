import 'dart:math' show max, min;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';

import '../content/creature_skins.dart';
import '../content/room_styles.dart';
import '../engine.dart';
import '../media_picker_intent.dart';
import '../room_photo.dart';
import '../tokens.dart';
import '../widgets/detail_header.dart';
import '../widgets/facets.dart';
import '../widgets/glass.dart';
import '../widgets/home_room.dart';
import '../widgets/honey_button.dart';
import '../widgets/room_photo_frame.dart';

/// The private, on-device source photo for the frame over the owner's hearth.
///
/// This screen deliberately works on a draft: choosing, replacing, removing,
/// or backing out cannot change the room behind it until [Save] succeeds.
class RoomPhotoScreen extends StatefulWidget {
  const RoomPhotoScreen({
    super.key,
    required this.state,
    required this.ownerKey,
    this.parallax = const AlwaysStoppedAnimation(Offset.zero),
    this.store,
    this.pickerIntentCoordinator,
  });

  final GameState state;
  final String ownerKey;
  final ValueListenable<Offset> parallax;

  /// Test seam. Production always uses the locally scoped singleton.
  final RoomPhotoStore? store;

  /// Test seam for the durable Android picker-intent boundary.
  final MediaPickerIntentCoordinator? pickerIntentCoordinator;

  @override
  State<RoomPhotoScreen> createState() => _RoomPhotoScreenState();
}

class _RoomPhotoScreenState extends State<RoomPhotoScreen> {
  late final RoomPhotoStore _store;
  late final MediaPickerIntentCoordinator _pickerIntent;
  RoomPhotoData? _saved;
  RoomPhotoData? _draft;
  bool _saving = false;
  bool _picking = false;
  bool _recovering = false;
  bool _ownerRejected = false;
  String? _error;
  String? _notice;

  @override
  void initState() {
    super.initState();
    _store = widget.store ?? RoomPhotoStore.instance;
    _pickerIntent =
        widget.pickerIntentCoordinator ?? MediaPickerIntentCoordinator.instance;
    _saved = _store.ownerKey == widget.ownerKey ? _store.photo : null;
    _draft = _saved;
    _store.addListener(_onStoreChanged);
    _recoverInterruptedPick();
  }

  @override
  void dispose() {
    _store.removeListener(_onStoreChanged);
    super.dispose();
  }

  void _onStoreChanged() {
    if (!mounted) return;
    if (_store.ownerKey != widget.ownerKey) {
      // A photo is tied to the local owner. Never let a draft from the prior
      // account be saved into the newly active one.
      setState(() {
        _ownerRejected = true;
        _draft = null;
        _saved = null;
        _picking = false;
        _recovering = false;
      });
      Navigator.of(context).maybePop();
      return;
    }
    // Start over and an external deliberate removal both publish an empty
    // store value. Clear any uncommitted editor draft too: it belongs to the
    // old local life and must never be able to resurrect after a reset.
    if (!_saving &&
        _store.photo == null &&
        (_saved != null || _draft != null)) {
      setState(() {
        _saved = null;
        _draft = null;
        _notice = 'The room photo was cleared on this device.';
      });
      return;
    }
    // Initial local-photo loading is asynchronous. Until the owner makes a
    // draft change, let its finished value seed both sides of this editor.
    if (!_changed && !_saving) {
      setState(() {
        _saved = _store.photo;
        _draft = _store.photo;
      });
    } else {
      setState(() {});
    }
    if (_store.loaded) _recoverInterruptedPick();
  }

  bool get _changed => !identical(_draft, _saved);

  Future<void> _recoverInterruptedPick() async {
    if (!_store.loaded || _recovering || _picking || _ownerRejected) return;
    setState(() => _recovering = true);
    try {
      final recovered = await _pickerIntent.recoverRoomPhotoDraft(
        _store,
        widget.ownerKey,
      );
      if (!mounted || recovered == null || _store.ownerKey != widget.ownerKey) {
        return;
      }
      // Recovery returns only a draft. The owner still sees the room, can
      // choose whole-photo or fill framing, and explicitly presses Save.
      setState(() {
        _draft = recovered;
        _notice = 'Your earlier photo choice is ready to review.';
      });
    } catch (_) {
      // A lost-picker check is best effort; it should never make the editor
      // feel broken or touch the currently stored room photo.
    } finally {
      if (mounted) setState(() => _recovering = false);
    }
  }

  Future<void> _choose() async {
    if (_saving ||
        _picking ||
        _recovering ||
        _ownerRejected ||
        !_store.loaded ||
        _store.ownerKey != widget.ownerKey) {
      return;
    }
    setState(() {
      _picking = true;
      _error = null;
      _notice = null;
    });
    RoomPhotoData? picked;
    var began = false;
    try {
      began = await _pickerIntent.beginRoomPhoto(widget.ownerKey);
      if (!began) {
        if (mounted) {
          setState(
            () => _notice =
                _pickerIntent.lastError ??
                'Review the earlier room photo choice first.',
          );
        }
        return;
      }
      picked = await _store.pickFromLibrary();
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Couldn’t open your photo library. Try again.');
      }
    } finally {
      if (began) {
        await _pickerIntent.completeRoomPhoto(widget.ownerKey);
      }
      if (mounted) setState(() => _picking = false);
    }
    if (!mounted || _store.ownerKey != widget.ownerKey) return;
    if (picked == null) {
      if (_store.lastError != null) setState(() => _error = _store.lastError);
      return;
    }
    setState(() => _draft = picked);
  }

  Future<void> _save() async {
    if (_saving || _picking || _recovering || _ownerRejected || !_changed) {
      return;
    }
    if (_store.ownerKey != widget.ownerKey) {
      setState(() => _error = 'This room changed. Open your photo again.');
      return;
    }
    final draftToSave = _draft;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await _store.save(draftToSave, ownerKey: widget.ownerKey);
      if (!mounted) return;
      if (_store.ownerKey != widget.ownerKey) return;
      setState(() {
        _saved = draftToSave;
        _draft = draftToSave;
        _saving = false;
      });
      // [PopScope] still has the old saving state until this frame commits.
      // Let it rebuild before closing the editor after a confirmed write.
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = error is RoomPhotoException
            ? error.message
            : _store.lastError ?? 'Couldn’t save that photo. Try again.';
      });
    }
  }

  void _setFillFrame(bool value) {
    final draft = _draft;
    if (draft == null || _saving || _picking || _recovering || _ownerRejected) {
      return;
    }
    setState(
      () => _draft = draft.copyWith(
        fillFrame: value,
        alignment: value ? draft.alignment : Alignment.center,
      ),
    );
  }

  void _resetPosition() {
    final draft = _draft;
    if (draft == null || _saving || _picking || _recovering || _ownerRejected) {
      return;
    }
    setState(() => _draft = draft.copyWith(alignment: Alignment.center));
  }

  void _position(Offset delta, Size size) {
    final draft = _draft;
    if (draft == null ||
        !draft.fillFrame ||
        _saving ||
        _picking ||
        _recovering ||
        _ownerRejected) {
      return;
    }
    final frameAspect = roomPhotoImageAspect(draft);
    final imageAspect = draft.pixelWidth / draft.pixelHeight;
    final overflowX = max(0, size.width * (imageAspect / frameAspect - 1));
    final overflowY = max(0, size.height * (frameAspect / imageAspect - 1));
    // Alignment selects the source crop. Moving the visible image right means
    // selecting farther left, hence the inverse sign. A non-overflowing axis
    // stays centered rather than pretending it can be positioned.
    final next = Alignment(
      overflowX == 0
          ? 0
          : (draft.alignment.x - 2 * delta.dx / overflowX).clamp(-1.0, 1.0),
      overflowY == 0
          ? 0
          : (draft.alignment.y - 2 * delta.dy / overflowY).clamp(-1.0, 1.0),
    );
    setState(() => _draft = draft.copyWith(fillFrame: true, alignment: next));
  }

  void _setAlignment(Alignment alignment) {
    final draft = _draft;
    if (draft == null || _saving || _picking || _recovering || _ownerRejected) {
      return;
    }
    setState(() => _draft = draft.copyWith(alignment: alignment));
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final hasDraft = _draft != null;
    final busy =
        _saving || _picking || _recovering || _ownerRejected || !_store.loaded;
    final mediaSize = MediaQuery.sizeOf(context);
    final compactLargeText =
        mediaSize.width <= 360 &&
        mediaSize.height <= 600 &&
        MediaQuery.textScalerOf(context).scale(1) >= 1.8;
    return PopScope(
      canPop: !_saving,
      child: Scaffold(
        backgroundColor: Palette.parchment,
        body: SafeArea(
          child: Column(
            children: [
              DetailHeader(
                title: compactLargeText ? 'Photo' : 'Above the fireplace',
                subtitle: compactLargeText
                    ? 'Private on device.'
                    : 'Starts private on this device.',
                accent: Palette.xpLight,
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _RoomPhotoPreview(
                        state: state,
                        photo: _draft,
                        parallax: state.reduceMotion ? null : widget.parallax,
                      ),
                      const SizedBox(height: 14),
                      if (_draft?.fillFrame == true) ...[
                        _CropPositioner(
                          photo: _draft!,
                          onPan: _position,
                          onAlignment: _setAlignment,
                        ),
                        const SizedBox(height: 14),
                      ],
                      GlassPanel(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Private source • Stored on this device',
                              style: Type.body.copyWith(
                                color: Palette.textHi,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              state.shareRoomPhoto
                                  ? 'Edits here change only this device. Your shared room keeps its current uploaded copy until you choose Update shared copy—or turn it off—from Personalize your space.'
                                  : 'It appears to room visitors only if you later choose Show in my shared room from Personalize your space. Discover cards never show it.',
                              style: Type.body.copyWith(
                                fontSize: 13,
                                color: Palette.textMid,
                                height: 1.35,
                              ),
                            ),
                            const SizedBox(height: 16),
                            if (!hasDraft)
                              HoneyButton(
                                key: const Key('choose-room-photo'),
                                label: 'CHOOSE FROM LIBRARY',
                                icon: Icons.photo_library_outlined,
                                expand: true,
                                enabled: !busy,
                                onTap: _choose,
                              )
                            else ...[
                              if (compactLargeText) ...[
                                _QuietAction(
                                  key: const Key('replace-room-photo'),
                                  label: 'Replace',
                                  icon: Icons.photo_library_outlined,
                                  onTap: busy ? null : _choose,
                                ),
                                const SizedBox(height: 10),
                                _QuietAction(
                                  key: const Key('remove-room-photo'),
                                  label: 'Remove',
                                  icon: Icons.delete_outline,
                                  danger: true,
                                  onTap: busy
                                      ? null
                                      : () => setState(() => _draft = null),
                                ),
                              ] else
                                Row(
                                  children: [
                                    Expanded(
                                      child: _QuietAction(
                                        key: const Key('replace-room-photo'),
                                        label: 'Replace',
                                        icon: Icons.photo_library_outlined,
                                        onTap: busy ? null : _choose,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: _QuietAction(
                                        key: const Key('remove-room-photo'),
                                        label: 'Remove',
                                        icon: Icons.delete_outline,
                                        danger: true,
                                        onTap: busy
                                            ? null
                                            : () =>
                                                  setState(() => _draft = null),
                                      ),
                                    ),
                                  ],
                                ),
                              const SizedBox(height: 14),
                              SwitchListTile.adaptive(
                                contentPadding: EdgeInsets.zero,
                                value: _draft!.fillFrame,
                                activeThumbColor: Palette.xpLight,
                                title: Text(
                                  'Fill the frame',
                                  style: Type.body.copyWith(
                                    color: Palette.textHi,
                                  ),
                                ),
                                subtitle: Text(
                                  _draft!.fillFrame
                                      ? 'Drag the photo gently to set its view.'
                                      : 'Show the whole photo without stretching it.',
                                  style: Type.body.copyWith(
                                    fontSize: 12,
                                    color: Palette.textMid,
                                  ),
                                ),
                                onChanged: busy ? null : _setFillFrame,
                              ),
                              if (_draft!.fillFrame)
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: TextButton.icon(
                                    key: const Key('reset-room-photo-position'),
                                    onPressed: busy ? null : _resetPosition,
                                    icon: const Icon(
                                      Icons.center_focus_strong,
                                      size: 17,
                                    ),
                                    label: const Text('Center photo'),
                                  ),
                                ),
                            ],
                          ],
                        ),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Semantics(
                          liveRegion: true,
                          child: Text(
                            _error!,
                            textAlign: TextAlign.center,
                            style: Type.body.copyWith(color: Palette.danger),
                          ),
                        ),
                      ],
                      if (_notice != null) ...[
                        const SizedBox(height: 12),
                        Semantics(
                          liveRegion: true,
                          child: Text(
                            _notice!,
                            textAlign: TextAlign.center,
                            style: Type.body.copyWith(color: Palette.textMid),
                          ),
                        ),
                      ],
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              key: const Key('cancel-room-photo'),
                              onPressed: busy
                                  ? null
                                  : () => Navigator.of(context).maybePop(),
                              child: const Text('Cancel'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: HoneyButton(
                              key: const Key('save-room-photo'),
                              label: _saving ? 'SAVING…' : 'SAVE',
                              expand: true,
                              enabled: _changed && !busy,
                              onTap: _save,
                            ),
                          ),
                        ],
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

class _RoomPhotoPreview extends StatelessWidget {
  const _RoomPhotoPreview({
    required this.state,
    required this.photo,
    required this.parallax,
  });

  final GameState state;
  final RoomPhotoData? photo;
  final ValueListenable<Offset>? parallax;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final roomAspect = state.wallStyle == 'wall_walnut' ? 1.7 : 1.5;
      final size = Size(
        constraints.maxWidth,
        constraints.maxWidth / roomAspect,
      );
      return Semantics(
        label: photo == null
            ? 'Your room, with no photo above the fireplace'
            : 'Your room photo.',
        child: ClipPath(
          clipper: const FacetedClipper(cut: 14),
          child: SizedBox(
            height: size.height,
            child: HomeRoom(
              aspect: roomAspect,
              lively: !state.reduceMotion,
              unlocked: state.ownedFurniture,
              wall: wallColorsFor(state),
              plateId: state.wallStyle,
              floor: floorColorsFor(state),
              window: state.windowScene,
              petAwake: state.streakDays > 0,
              emberGlow: flameHueFor(state),
              heirloomFlame: heirloomFlameFor(state),
              level: state.level,
              roomPhoto: photo,
              parallax: parallax,
            ),
          ),
        ),
      );
    },
  );
}

class _QuietAction extends StatelessWidget {
  const _QuietAction({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
    this.danger = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    onPressed: onTap,
    icon: Icon(icon, size: 18),
    label: Text(label),
    style: OutlinedButton.styleFrom(
      foregroundColor: danger ? Palette.danger : Palette.textHi,
      side: BorderSide(
        color: (danger ? Palette.danger : Palette.xp).withValues(alpha: 0.45),
      ),
      minimumSize: const Size.fromHeight(46),
    ),
  );
}

/// A deliberately larger crop surface than the real room frame. It uses the
/// renderer's same aspect and BoxFit.cover behavior, so a positioning gesture
/// has enough physical room to be precise without inventing zoom controls.
class _CropPositioner extends StatelessWidget {
  const _CropPositioner({
    required this.photo,
    required this.onPan,
    required this.onAlignment,
  });

  final RoomPhotoData photo;
  final void Function(Offset delta, Size size) onPan;
  final ValueChanged<Alignment> onAlignment;

  @override
  Widget build(BuildContext context) {
    final aspect = roomPhotoImageAspect(photo);
    final imageAspect = photo.pixelWidth / photo.pixelHeight;
    final horizontal = imageAspect > aspect;
    final vertical = imageAspect < aspect;
    return GlassPanel(
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Position in frame',
            style: Type.label.copyWith(color: Palette.textMid),
          ),
          const SizedBox(height: 8),
          Center(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = min(constraints.maxWidth, 280.0);
                final size = Size(width, width / aspect);
                return Semantics(
                  label: 'Photo position. Drag to set the crop.',
                  child: GestureDetector(
                    onPanUpdate: (details) => onPan(details.delta, size),
                    child: ClipPath(
                      clipper: const FacetedClipper(cut: 10),
                      child: SizedBox(
                        width: size.width,
                        height: size.height,
                        child: Image.memory(
                          photo.bytes,
                          fit: BoxFit.cover,
                          alignment: photo.alignment,
                          filterQuality: FilterQuality.medium,
                          gaplessPlayback: true,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          if (horizontal)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Horizontal position',
                  style: Type.body.copyWith(color: Palette.textHi),
                ),
                Slider(
                  value: photo.alignment.x,
                  min: -1,
                  max: 1,
                  divisions: 20,
                  label: 'Horizontal position',
                  onChanged: (value) =>
                      onAlignment(Alignment(value, photo.alignment.y)),
                ),
              ],
            ),
          if (vertical)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Vertical position',
                  style: Type.body.copyWith(color: Palette.textHi),
                ),
                Slider(
                  value: photo.alignment.y,
                  min: -1,
                  max: 1,
                  divisions: 20,
                  label: 'Vertical position',
                  onChanged: (value) =>
                      onAlignment(Alignment(photo.alignment.x, value)),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

/// The quiet way into the device-private frame editor from the owner's room.
class RoomPhotoEntry extends StatelessWidget {
  const RoomPhotoEntry({super.key, required this.state, required this.onTap});

  final GameState state;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final photo = RoomPhotoStore.instance.photo;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: const Key('edit-room-photo'),
        onTap: onTap,
        customBorder: const FacetedBorder(cut: 9),
        child: Ink(
          decoration: facetedDecoration(
            cut: 9,
            color: const Color(0xFF261E18),
            borderColor: Palette.xp.withValues(alpha: 0.26),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(15, 14, 12, 14),
            child: Row(
              children: [
                const Icon(
                  Icons.photo_size_select_large_outlined,
                  color: Palette.xpLight,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Your room photo',
                        style: Type.display.copyWith(fontSize: 20),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        photo == null
                            ? 'Add one photo above the fireplace. It starts private.'
                            : state.shareRoomPhoto &&
                                  state.spaceRoomPhotoPath.isNotEmpty
                            ? 'Your private photo hangs here; a separate copy is shared with room visitors.'
                            : state.shareRoomPhoto
                            ? 'Your photo hangs here and is ready to join the room you share.'
                            : 'A photo hangs here. It stays private unless you choose to share it.',
                        style: Type.body.copyWith(
                          fontSize: 12,
                          color: Palette.textMid,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right,
                  color: Palette.textMid,
                  size: 22,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
