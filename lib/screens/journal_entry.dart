import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../audio.dart';
import '../journal_doc.dart';
import '../journal_media.dart' as media;
import '../models.dart';
import '../tokens.dart';
import '../widgets/glass.dart';
import '../widgets/notes_sheet.dart' show relativeWhen;

/// What the editor hands back on each autosave.
class JournalPayload {
  JournalPayload(this.text, this.rich, this.images);

  /// Plain-text flattening (for the feed preview / search).
  final String text;

  /// The block document JSON (text + inline photos), stored in Note.rich.
  final String rich;

  /// The photo filenames referenced, in order.
  final List<String> images;
}

/// The full-page journal editor (round-53) — a whole page you really write on,
/// with photos you can drop between paragraphs the way a notes app does. It
/// AUTOSAVES as you go (debounced + on the way out), so you can leave and come
/// back to keep writing. Photos are kept on-device (a free app can't sync images
/// for free) — said plainly in the composer, never implied to follow the cloud.
///
/// Persistence stays at the call site: [commit] inserts-or-replaces and returns
/// the saved [Note]; an emptied entry is removed via [onDelete].
class JournalEntryScreen extends StatefulWidget {
  const JournalEntryScreen({
    super.key,
    required this.accent,
    required this.commit,
    required this.onDelete,
    this.initial,
    this.themeId,
    this.heading = 'Journal',
    this.hint = 'Start writing…',
  });

  final Note? initial;
  final Color accent;
  final Note Function(JournalPayload payload, Note? existing, bool markEdited)
      commit;
  final void Function(Note entry) onDelete;
  final String? themeId;
  final String heading;
  final String hint;

  @override
  State<JournalEntryScreen> createState() => _JournalEntryScreenState();
}

/// One editable block: a text paragraph (its own controller + focus) or an
/// inline image (a stored relative filename).
class _Block {
  _Block.text(String t)
      : image = null,
        controller = TextEditingController(text: t),
        focus = FocusNode();
  _Block.image(this.image)
      : controller = null,
        focus = null;

  final String? image;
  final TextEditingController? controller;
  final FocusNode? focus;
  bool get isImage => image != null;

  void dispose() {
    controller?.dispose();
    focus?.dispose();
  }
}

class _JournalEntryScreenState extends State<JournalEntryScreen>
    with WidgetsBindingObserver {
  final List<_Block> _blocks = [];
  Timer? _debounce;
  Note? _current;
  bool _dirty = false;
  bool _everSaved = false;
  _Block? _active; // where the cursor last was (photo inserts after it)

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _current = widget.initial;
    _everSaved = widget.initial != null;
    _initBlocks();
    if (widget.initial == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _blocks.isNotEmpty) _blocks.first.focus?.requestFocus();
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    // the debounce Timer never fires while suspended — write the last
    // keystrokes through NOW, or a type-and-switch-away loses them despite
    // the "Saving…" chip
    if (s == AppLifecycleState.paused || s == AppLifecycleState.inactive) {
      _flush();
    }
  }

  void _initBlocks() {
    final n = widget.initial;
    var doc = <JournalBlock>[];
    if (n?.rich != null) {
      doc = JournalDoc.decode(n!.rich);
    }
    // fall back to the plain text when there is no rich doc OR it failed to
    // decode (corrupt rich must never open a blank page over real words —
    // one keystroke later the autosave would overwrite them)
    if (doc.isEmpty && n != null && n.text.isNotEmpty) {
      doc = [JournalBlock.text(n.text)];
    }
    for (final b in doc) {
      _blocks.add(b.isImage ? _Block.image(b.image!) : _Block.text(b.text ?? ''));
    }
    // always end on a text block so there's somewhere to keep writing
    if (_blocks.isEmpty || _blocks.last.isImage) _blocks.add(_Block.text(''));
    for (final b in _blocks) {
      b.controller?.addListener(_onChanged);
    }
    _active = _blocks.lastWhere((b) => !b.isImage, orElse: () => _blocks.first);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _debounce?.cancel();
    for (final b in _blocks) {
      b.dispose();
    }
    super.dispose();
  }

  void _onChanged() {
    if (!_dirty) setState(() => _dirty = true);
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 650), _flush);
  }

  List<JournalBlock> _toDoc({bool trim = false}) {
    final out = <JournalBlock>[];
    for (final b in _blocks) {
      if (b.isImage) {
        out.add(JournalBlock.image(b.image!));
      } else {
        final t = b.controller!.text;
        // when trimming for storage, drop empty paragraphs (kept live for
        // editing, but they'd just be clutter in the saved doc)
        if (!trim || t.trim().isNotEmpty) out.add(JournalBlock.text(t));
      }
    }
    return out;
  }

  void _flush({bool exiting = false}) {
    _debounce?.cancel();
    if (!_dirty) return;
    final live = _toDoc();
    final plain = JournalDoc.plainText(live);
    final imgs = JournalDoc.images(live);
    if (plain.isEmpty && imgs.isEmpty) {
      // mid-session, an empty page is a MOMENT (select-all-cut while
      // rewriting), not a decision — deleting now would destroy the entry's
      // identity (id / date / "written as" context) and re-mint it on the next
      // keystroke. Only an exit with an empty page really removes the entry.
      if (!exiting) return;
      final gone = _current;
      _current = null;
      _everSaved = false;
      _dirty = false;
      if (gone != null) widget.onDelete(gone);
      if (mounted) setState(() {});
      return;
    }
    final rich = JournalDoc.encode(_toDoc(trim: true));
    _current =
        widget.commit(JournalPayload(plain, rich, imgs), _current, widget.initial != null);
    _everSaved = true;
    _dirty = false;
    if (mounted) setState(() {});
  }

  /// Puts the cursor at the end of the last paragraph (tap-anywhere-to-write).
  void _focusTail() {
    final tail = _blocks.lastWhere((b) => !b.isImage, orElse: () => _blocks.last);
    final c = tail.controller;
    if (c == null) return;
    _active = tail;
    tail.focus?.requestFocus();
    c.selection = TextSelection.collapsed(offset: c.text.length);
  }

  Future<void> _addPhoto(bool fromCamera) async {
    final name = await media.pick(fromCamera);
    if (name == null || !mounted) {
      // a FAILURE (denied permission, camera error) must not read as "photos
      // are broken" — tell them warmly what to do. A plain cancel stays silent.
      if (mounted && media.lastPickFailed) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: Palette.card,
          content: Text(
            fromCamera
                ? 'Emberkeep couldn’t reach your camera — you can allow it in Settings.'
                : 'Emberkeep couldn’t reach your photos — you can allow it in Settings.',
            style: Type.body.copyWith(fontSize: 13, color: Palette.textHi),
          ),
        ));
      }
      return;
    }
    Sfx.instance.play('tick');
    var idx = _active == null ? -1 : _blocks.indexOf(_active!);
    if (idx < 0) idx = _blocks.length - 1;
    final after = _Block.text('')..controller!.addListener(_onChanged);
    setState(() {
      _blocks.insert(idx + 1, _Block.image(name));
      _blocks.insert(idx + 2, after);
      _active = after;
    });
    _dirty = true;
    _flush();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => after.focus?.requestFocus());
  }

  void _removeImage(_Block b) {
    Sfx.instance.play('boing');
    media.delete(b.image!);
    setState(() {
      _blocks.remove(b);
      b.dispose();
      if (_blocks.isEmpty || _blocks.last.isImage) {
        _blocks.add(_Block.text('')..controller!.addListener(_onChanged));
      }
    });
    _dirty = true;
    _flush();
  }

  Future<void> _pickPhotoSource() async {
    final cam = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: GlassPanel(
            tint: const Color(0xF22A211D),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _sourceTile(Icons.photo_library_outlined, 'Choose from library',
                    () => Navigator.pop(context, false)),
                const SizedBox(height: 6),
                _sourceTile(Icons.photo_camera_outlined, 'Take a photo',
                    () => Navigator.pop(context, true)),
              ],
            ),
          ),
        ),
      ),
    );
    if (cam != null) await _addPhoto(cam);
  }

  Widget _sourceTile(IconData icon, String label, VoidCallback onTap) =>
      GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
          child: Row(
            children: [
              Icon(icon, size: 20, color: widget.accent),
              const SizedBox(width: 14),
              Text(label,
                  style: Type.body.copyWith(fontSize: 15, color: Palette.textHi)),
            ],
          ),
        ),
      );

  Future<void> _confirmDelete() async {
    final entry = _current;
    if (entry == null) {
      Navigator.of(context).maybePop();
      return;
    }
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Palette.card,
        title:
            Text('Delete this entry?', style: Type.display.copyWith(fontSize: 18)),
        content: Text('This can’t be undone.',
            style: Type.body.copyWith(fontSize: 14, color: Palette.textMid)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child:
                Text('Keep', style: Type.label.copyWith(color: Palette.textMid)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child:
                Text('Delete', style: Type.label.copyWith(color: Palette.streak)),
          ),
        ],
      ),
    );
    if (yes != true) return;
    Sfx.instance.play('boing');
    _debounce?.cancel();
    _dirty = false;
    for (final b in _blocks) {
      if (b.isImage) media.delete(b.image!);
    }
    widget.onDelete(entry);
    if (mounted) Navigator.of(context).maybePop();
  }

  String get _whenLine {
    final n = _current;
    if (n == null) return 'New entry';
    final parts = <String>[relativeWhen(n.at)];
    if (n.context != null && n.context!.isNotEmpty) {
      parts.add('written as ${n.context}');
    }
    if (n.editedAt != null) parts.add('edited');
    return parts.join('  ·  ');
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) => _flush(exiting: true),
      child: Scaffold(
        backgroundColor: Palette.parchment,
        body: WarmBackground(
          themeId: widget.themeId,
          tint: widget.accent,
          child: SafeArea(
            child: Column(
              children: [
                _bar(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 0, 22, 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _whenLine,
                      style:
                          Type.label.copyWith(fontSize: 11, color: Palette.textLo),
                    ),
                  ),
                ),
                Expanded(
                  // the WHOLE page is the writing surface: tapping the empty
                  // space below the last paragraph puts the cursor at the end
                  // (the first friction every notes-app writer hits otherwise)
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: _focusTail,
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      itemCount: _blocks.length,
                      itemBuilder: (_, i) => _blockView(_blocks[i], i == 0),
                    ),
                  ),
                ),
                if (!kIsWeb) _photoBar(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _blockView(_Block b, bool first) {
    if (b.isImage) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Stack(
          children: [
            media.image(b.image!),
            Positioned(
              top: 8,
              right: 8,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _removeImage(b),
                child: Container(
                  padding: const EdgeInsets.all(5),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0x99140C06),
                  ),
                  child: const Icon(Icons.close, size: 16, color: Palette.textHi),
                ),
              ),
            ),
          ],
        ),
      );
    }
    return TextField(
      controller: b.controller,
      focusNode: b.focus,
      onTap: () => _active = b,
      maxLines: null,
      textCapitalization: TextCapitalization.sentences,
      keyboardType: TextInputType.multiline,
      cursorColor: widget.accent,
      style: Type.body.copyWith(fontSize: 17, height: 1.5, color: Palette.textHi),
      decoration: InputDecoration(
        border: InputBorder.none,
        isCollapsed: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 4),
        hintText: first ? widget.hint : null,
        hintStyle:
            Type.body.copyWith(fontSize: 17, height: 1.5, color: Palette.textLo),
      ),
    );
  }

  Widget _bar() {
    final saved = _everSaved && !_dirty;
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 6, 12, 2),
      child: Row(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            // PopScope runs the exiting flush on the way out
            onTap: () => Navigator.of(context).maybePop(),
            child: const Padding(
              padding: EdgeInsets.all(8),
              child: Icon(Icons.chevron_left, size: 26, color: Palette.textMid),
            ),
          ),
          Text(widget.heading,
              style: Type.display.copyWith(fontSize: 20, color: widget.accent)),
          const Spacer(),
          if (_dirty || _everSaved)
            Row(
              children: [
                // a plain check, not a cloud — this save is proudly local
                Icon(saved ? Icons.check_circle_outline : Icons.sync,
                    size: 14, color: Palette.textLo),
                const SizedBox(width: 5),
                Text(saved ? 'Saved' : 'Saving…',
                    style:
                        Type.label.copyWith(fontSize: 10, color: Palette.textLo)),
              ],
            ),
          if (_current != null) ...[
            const SizedBox(width: 6),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _confirmDelete,
              child: const Padding(
                padding: EdgeInsets.all(8),
                child:
                    Icon(Icons.delete_outline, size: 20, color: Palette.textLo),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _photoBar() {
    final hasPhotos = _blocks.any((b) => b.isImage);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Palette.glassEdge)),
      ),
      child: Row(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _pickPhotoSource,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                color: widget.accent.withValues(alpha: 0.14),
                border:
                    Border.all(color: widget.accent.withValues(alpha: 0.4)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add_photo_alternate_outlined,
                      size: 18, color: widget.accent),
                  const SizedBox(width: 7),
                  Text('Photo',
                      style: Type.label
                          .copyWith(fontSize: 12, color: widget.accent)),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          if (hasPhotos)
            Expanded(
              child: Text(
                'Photos are kept on this device',
                style: Type.label.copyWith(fontSize: 10, color: Palette.textLo),
              ),
            ),
        ],
      ),
    );
  }
}
