import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../audio.dart';
import '../journal_doc.dart';
import '../journal_media.dart' as media;
import '../models.dart';
import '../release_features.dart';
import '../tokens.dart';
import '../widgets/facets.dart';
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
/// back to keep writing. Photos stay on-device and never join cloud backup or
/// the v1 visitor page. A later explicitly enabled visitor-photo build keeps
/// that separate from this composer.
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
    this.reduceMotion = false,
    this.heading = 'Journal',
    this.hint = 'Start writing…',
    this.starter,
    this.trace,
    this.initiallyEditing = true,
    this.onEditRequested,
  });

  final Note? initial;
  final Color accent;
  final Note Function(JournalPayload payload, Note? existing, bool markEdited)
  commit;
  final void Function(Note entry) onDelete;
  final String? themeId;
  final bool reduceMotion;
  final String heading;
  final String hint;
  final JournalTrace? trace;

  /// Existing entries can open as a page to read before any editing controls
  /// appear. Brand-new entries always open ready to write.
  final bool initiallyEditing;

  /// Structured journal pages (currently the closing reflection) keep their
  /// own editor. When supplied, the read page's Edit action opens that flow
  /// instead of turning this block document editable.
  final Future<void> Function(BuildContext context)? onEditRequested;

  /// Optional first line for a guided entry. It is not saved by merely opening
  /// the page; once the user writes, it remains ordinary stored text while the
  /// exact starter prefix is painted distinctly from their answer.
  final String? starter;

  @override
  State<JournalEntryScreen> createState() => _JournalEntryScreenState();
}

/// One editable block: a text paragraph (its own controller + focus) or an
/// inline image (a stored relative filename).
class _Block {
  _Block.text(String t, {String? promptPrefix, Color? promptColor})
    : image = null,
      controller = _JournalTextController(
        text: t,
        promptPrefix: promptPrefix,
        promptColor: promptColor,
      ),
      focus = FocusNode();
  _Block.image(this.image) : controller = null, focus = null;

  final String? image;
  final TextEditingController? controller;
  final FocusNode? focus;
  bool get isImage => image != null;

  void dispose() {
    controller?.dispose();
    focus?.dispose();
  }
}

/// Paints a guided starter differently while leaving the controller text —
/// and therefore the serialized Journal document — completely unchanged.
class _JournalTextController extends TextEditingController {
  _JournalTextController({
    required String text,
    this.promptPrefix,
    this.promptColor,
  }) : super(text: text);

  final String? promptPrefix;
  final Color? promptColor;

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final prompt = promptPrefix;
    if (prompt == null || prompt.isEmpty || !text.startsWith(prompt)) {
      return super.buildTextSpan(
        context: context,
        style: style,
        withComposing: withComposing,
      );
    }

    final composing = withComposing && value.isComposingRangeValid
        ? value.composing
        : TextRange.empty;
    final boundaries = <int>{0, prompt.length, text.length};
    if (!composing.isCollapsed) {
      boundaries
        ..add(composing.start)
        ..add(composing.end);
    }
    final ordered = boundaries.toList()..sort();
    final promptStyle =
        style?.copyWith(
          color: promptColor,
          fontStyle: FontStyle.italic,
          fontWeight: FontWeight.w600,
        ) ??
        TextStyle(
          color: promptColor,
          fontStyle: FontStyle.italic,
          fontWeight: FontWeight.w600,
        );

    return TextSpan(
      style: style,
      children: [
        for (var index = 0; index < ordered.length - 1; index++)
          if (ordered[index] < ordered[index + 1])
            TextSpan(
              text: text.substring(ordered[index], ordered[index + 1]),
              style:
                  (ordered[index] < prompt.length
                          ? promptStyle
                          : const TextStyle())
                      .merge(
                        !composing.isCollapsed &&
                                ordered[index] >= composing.start &&
                                ordered[index] < composing.end
                            ? const TextStyle(
                                decoration: TextDecoration.underline,
                              )
                            : null,
                      ),
            ),
      ],
    );
  }
}

/// A restrained reveal of the authored Journal room. The live editor does not
/// pretend the illustration's handwriting is editable; it sits above it on a
/// separate page surface, while the room remains the place around the page.
class _JournalDeskBackdrop extends StatelessWidget {
  const _JournalDeskBackdrop();

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: RepaintBoundary(
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/pages/journal-desk-v3.webp',
            fit: BoxFit.cover,
            alignment: const Alignment(0, -0.28),
            filterQuality: FilterQuality.medium,
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x36120C08),
                  Color(0x55191210),
                  Color(0xE8191210),
                ],
                stops: [0, 0.48, 1],
              ),
            ),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0x4A120C08),
                  Color(0x00120C08),
                  Color(0x4A120C08),
                ],
                stops: [0, 0.5, 1],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

/// Dark parchment seated inside a book-cloth rim. It keeps the candlelit
/// material language without returning to the bright beige canvas that hurt
/// readability in earlier builds.
class _JournalPageSurface extends StatelessWidget {
  const _JournalPageSurface({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    label: 'Journal writing page',
    child: DecoratedBox(
      decoration: facetedDecoration(
        cut: 18,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF4A342A), Color(0xFF2C1E1B), Color(0xFF1D1413)],
          stops: [0, 0.42, 1],
        ),
        borderColor: const Color(0xB88E6134),
        borderWidth: 1.35,
        shadows: const [
          BoxShadow(
            color: Color(0xA6140C06),
            blurRadius: 22,
            offset: Offset(0, 10),
          ),
          BoxShadow(
            color: Color(0x248E6134),
            blurRadius: 12,
            offset: Offset(-2, -2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(5),
        child: ClipPath(
          clipper: const FacetedClipper(cut: 14),
          child: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF382B24),
                  Color(0xFF2D221F),
                  Color(0xFF241A19),
                ],
                stops: [0, 0.48, 1],
              ),
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                const IgnorePointer(
                  child: RepaintBoundary(
                    child: CustomPaint(painter: _JournalPagePainter()),
                  ),
                ),
                child,
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _JournalPagePainter extends CustomPainter {
  const _JournalPagePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    canvas.drawRect(
      bounds,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.72, -0.88),
          radius: 1.22,
          colors: [Color(0x24E0A865), Color(0x00191210)],
        ).createShader(bounds),
    );

    // Sparse, deterministic fibres: enough to read as paper at rest, never a
    // noisy filter behind someone's actual words.
    final fibre = Paint()
      ..color = const Color(0x16D8BE96)
      ..strokeWidth = 0.7
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 24; i++) {
      final y = 10.0 + i * (size.height - 20) / 24;
      final start = 9.0 + (i % 5) * 7;
      final width = 38.0 + (i % 4) * 19;
      canvas.drawLine(Offset(start, y), Offset(start + width, y + 0.6), fibre);
      final right = size.width - 14 - (i % 3) * 11;
      canvas.drawLine(
        Offset(right - width * 0.52, y + 5),
        Offset(right, y + 4.4),
        fibre,
      );
    }

    final inset = facetedRectPath(
      Rect.fromLTWH(3, 3, size.width - 6, size.height - 6),
      cut: 11,
    );
    canvas.drawPath(
      inset,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8
        ..color = const Color(0x358E6134),
    );

    // One quiet botanical watermark belongs to the Journal's page language.
    // It stays below live ink and never asks for attention.
    final botanical = Paint()
      ..color = const Color(0x248E6134)
      ..strokeWidth = 1.15
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final origin = Offset(size.width - 28, size.height - 24);
    final stem = Path()
      ..moveTo(origin.dx, origin.dy)
      ..quadraticBezierTo(
        origin.dx - 18,
        origin.dy - 34,
        origin.dx - 10,
        origin.dy - 76,
      );
    canvas.drawPath(stem, botanical);
    for (var i = 0; i < 4; i++) {
      final y = origin.dy - 18 - i * 14;
      final x = origin.dx - 8 - i * 1.5;
      canvas.drawOval(
        Rect.fromCenter(center: Offset(x - 8, y), width: 13, height: 6),
        botanical,
      );
      canvas.drawOval(
        Rect.fromCenter(center: Offset(x + 5, y - 7), width: 12, height: 5.5),
        botanical,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _JournalPagePainter oldDelegate) => false;
}

class _JournalEntryScreenState extends State<JournalEntryScreen>
    with WidgetsBindingObserver {
  final List<_Block> _blocks = [];
  Timer? _debounce;
  Note? _current;
  bool _dirty = false;
  bool _everSaved = false;
  late bool _editing;
  int _words = 0;
  _Block? _active; // where the cursor last was (photo inserts after it)

  /// The rich doc as last committed — the truth we diff against. A bare tap
  /// into an entry (which a raw controller listener reports as a change,
  /// because selection moves) must NOT count as an edit: we compare the
  /// encoded doc, so only real words move the "edited" stamp and trigger a
  /// save. (Photos taken in-app aren't in the gallery — a phantom rewrite that
  /// bumped lastModified could even lose a cloud merge, so this matters.)
  String _committedRich = '';

  /// Files whose blocks were removed but not yet flushed to disk — held so an
  /// "Undo" can put the photo back. Deleted for real on exit / next removal.
  final List<String> _pendingPhotoDeletes = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _current = widget.initial;
    _everSaved = widget.initial != null;
    _editing = widget.initial == null || widget.initiallyEditing;
    _initBlocks();
    // remember exactly what we loaded, so re-saving identical content is a
    // no-op and never stamps "edited"
    _committedRich = JournalDoc.encode(_toDoc(trim: true));
    _words = _countWords();
    if (_editing && widget.initial == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _blocks.isNotEmpty) _blocks.first.focus?.requestFocus();
      });
    }
    // Android can reclaim the app while its photo picker is open; the picked
    // files come back on the next launch. Land them in the page the person
    // reopened — almost always the one they were writing — and say so.
    unawaited(_recoverLostPhotos());
  }

  Future<void> _recoverLostPhotos() async {
    final names = await media.recoverLost();
    if (names.isEmpty || !mounted) return;
    _insertImages(names);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Palette.card,
        content: Text(
          names.length == 1
              ? 'The photo you picked before the app closed is here now.'
              : 'The photos you picked before the app closed are here now.',
          style: Type.body.copyWith(fontSize: 13, color: Palette.textHi),
        ),
      ),
    );
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
    if (doc.isEmpty &&
        n == null &&
        (widget.starter?.trim().isNotEmpty ?? false)) {
      doc = [JournalBlock.text(widget.starter!)];
    }
    var textIndex = 0;
    for (final b in doc) {
      final isPrompt =
          !b.isImage &&
          textIndex == 0 &&
          (widget.starter?.isNotEmpty ?? false) &&
          (b.text?.startsWith(widget.starter!) ?? false);
      _blocks.add(
        b.isImage
            ? _Block.image(b.image!)
            : _Block.text(
                b.text ?? '',
                promptPrefix: isPrompt ? widget.starter : null,
                promptColor: isPrompt
                    ? widget.accent.withValues(alpha: 0.92)
                    : null,
              ),
      );
      if (!b.isImage) textIndex++;
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
    // any photo removed but not yet flushed to disk (its undo snackbar still
    // open at exit) gets deleted for real now — leaving nothing orphaned
    for (final name in _pendingPhotoDeletes) {
      media.delete(name);
    }
    _pendingPhotoDeletes.clear();
    for (final b in _blocks) {
      b.dispose();
    }
    super.dispose();
  }

  void _onChanged() {
    // diff against the committed doc — a selection move (which the controller
    // also reports) encodes identically, so it never marks dirty or schedules
    // a phantom save
    final changed = JournalDoc.encode(_toDoc(trim: true)) != _committedRich;
    final words = _countWords();
    if (changed != _dirty || words != _words) {
      setState(() {
        _dirty = changed;
        _words = words;
      });
    }
    _debounce?.cancel();
    if (changed) _debounce = Timer(const Duration(milliseconds: 650), _flush);
  }

  /// Words across every text block — a quiet companion in the status bar.
  int _countWords() {
    var n = 0;
    for (final b in _blocks) {
      if (b.isImage) continue;
      for (final w in b.controller!.text.trim().split(RegExp(r'\s+'))) {
        if (w.isNotEmpty) n++;
      }
    }
    return n;
  }

  int get _starterWords {
    if (widget.starter == null) return 0;
    if (_blocks.isEmpty ||
        _blocks.first.isImage ||
        !_blocks.first.controller!.text.startsWith(widget.starter!)) {
      return 0;
    }
    return widget.starter!
        .trim()
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .length;
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
    // one trimmed doc drives everything: both the plain flattening (feed /
    // search) and the stored rich come from the SAME trimmed blocks, so a
    // preview never carries the blank-line junk of auto-inserted empty
    // paragraphs (the old code flattened the untrimmed doc).
    final doc = _toDoc(trim: true);
    final plain = JournalDoc.plainText(doc);
    final imgs = JournalDoc.images(doc);
    if (plain.isEmpty && imgs.isEmpty) {
      // mid-session, an empty page is a MOMENT (select-all-cut while
      // rewriting), not a decision — deleting now would destroy the entry's
      // identity (id / date / "written as" context) and re-mint it on the next
      // keystroke. Only an exit with an empty page really removes the entry.
      if (!exiting) {
        if (_dirty) setState(() => _dirty = false);
        return;
      }
      final gone = _current;
      _current = null;
      _everSaved = false;
      _dirty = false;
      if (gone != null) widget.onDelete(gone);
      if (mounted) setState(() {});
      return;
    }
    final rich = JournalDoc.encode(doc);
    // nothing actually changed since the last commit → don't rewrite, don't
    // bump editedAt/lastModified (the false-edit fix, belt-and-braces)
    if (rich == _committedRich) {
      if (_dirty) setState(() => _dirty = false);
      return;
    }
    _current = widget.commit(
      JournalPayload(plain, rich, imgs),
      _current,
      widget.initial != null,
    );
    _committedRich = rich;
    _everSaved = true;
    _dirty = false;
    if (mounted) setState(() {});
  }

  /// Puts the cursor at the end of the last paragraph (tap-anywhere-to-write).
  void _focusTail() {
    if (!_editing) return;
    final tail = _blocks.lastWhere(
      (b) => !b.isImage,
      orElse: () => _blocks.last,
    );
    final c = tail.controller;
    if (c == null) return;
    _active = tail;
    tail.focus?.requestFocus();
    c.selection = TextSelection.collapsed(offset: c.text.length);
  }

  Future<void> _beginEditing() async {
    Sfx.instance.playMaterial(MaterialSound.parchment);
    final externalEditor = widget.onEditRequested;
    if (externalEditor != null) {
      await externalEditor(context);
      return;
    }
    if (!mounted || _editing) return;
    setState(() => _editing = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusTail();
    });
  }

  /// DONE: commit, close the keyboard, and show the kept page. A page that
  /// was never anything (nothing typed, no photo) just leaves instead of
  /// presenting an empty read view.
  void _finishEditing() {
    Sfx.instance.playMaterial(MaterialSound.parchment);
    FocusScope.of(context).unfocus();
    _flush();
    if (_current == null) {
      Navigator.of(context).maybePop();
      return;
    }
    setState(() => _editing = false);
  }

  Future<void> _addPhoto(bool fromCamera) async {
    final List<String> names;
    if (fromCamera) {
      final picked = await media.pick(true);
      names = picked == null ? const [] : [picked];
    } else {
      names = await media.pickMany();
    }
    if (names.isEmpty || !mounted) {
      // a FAILURE (denied permission, camera error) must not read as "photos
      // are broken" — tell them warmly what to do. A plain cancel stays silent.
      if (mounted && media.lastPickFailed) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Palette.card,
            content: Text(
              fromCamera
                  ? 'Couldn’t reach your camera — you can allow it in Settings.'
                  : 'Couldn’t reach your photos — you can allow it in Settings.',
              style: Type.body.copyWith(fontSize: 13, color: Palette.textHi),
            ),
          ),
        );
      }
      return;
    }
    Sfx.instance.playMaterial(MaterialSound.parchment);
    _insertImages(names);
  }

  /// Inserts stored photos after the active block and commits immediately —
  /// shared by a fresh pick and by lost-pick recovery on relaunch.
  void _insertImages(List<String> names) {
    var idx = _active == null ? -1 : _blocks.indexOf(_active!);
    if (idx < 0) idx = _blocks.length - 1;
    final after = _Block.text('')..controller!.addListener(_onChanged);
    setState(() {
      _blocks.insertAll(idx + 1, [
        for (final name in names) _Block.image(name),
      ]);
      _blocks.insert(idx + 1 + names.length, after);
      _active = after;
    });
    _dirty = true;
    _flush();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => after.focus?.requestFocus(),
    );
  }

  void _removeImage(_Block b) {
    final name = b.image!;
    final idx = _blocks.indexOf(b);
    if (idx < 0) return;
    // snapshot the page AS IT STANDS (photo still in it) so Undo can restore
    // it exactly — including any paragraph split the photo was sitting in
    final restore = _toDoc();
    Sfx.instance.play('boing');
    setState(() {
      _blocks.removeAt(idx);
      b.dispose();
      // the photo sat between two paragraphs — stitch them back into one so no
      // invisible seam (and no un-selectable split) is left behind
      if (idx > 0 &&
          idx < _blocks.length &&
          !_blocks[idx - 1].isImage &&
          !_blocks[idx].isImage) {
        final prev = _blocks[idx - 1], next = _blocks[idx];
        final a = prev.controller!.text, c = next.controller!.text;
        prev.controller!.text = a.isEmpty ? c : (c.isEmpty ? a : '$a\n$c');
        _blocks.removeAt(idx);
        next.dispose();
      }
      if (_blocks.isEmpty || _blocks.last.isImage) {
        _blocks.add(_Block.text('')..controller!.addListener(_onChanged));
      }
      _active = _blocks.lastWhere(
        (x) => !x.isImage,
        orElse: () => _blocks.first,
      );
    });
    // DON'T delete the file yet — a fat-fingered X on an in-app photo (never in
    // the gallery) would be unrecoverable. Hold it; Undo cancels, the snackbar
    // closing for any other reason commits the delete.
    _pendingPhotoDeletes.add(name);
    _dirty = true;
    _flush();
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    final ctrl = messenger.showSnackBar(
      SnackBar(
        backgroundColor: Palette.card,
        duration: const Duration(seconds: 4),
        content: Text(
          'Photo removed',
          style: Type.body.copyWith(fontSize: 13, color: Palette.textHi),
        ),
        action: SnackBarAction(
          label: 'Undo',
          textColor: widget.accent,
          onPressed: () {
            _pendingPhotoDeletes.remove(name); // keep the file
            _restoreDoc(restore);
          },
        ),
      ),
    );
    ctrl.closed.then((reason) {
      // dismissed / timed out without Undo → the delete is now real
      if (reason != SnackBarClosedReason.action &&
          _pendingPhotoDeletes.remove(name)) {
        media.delete(name);
      }
    });
  }

  /// Rebuild the editor's blocks from a saved [doc] (Undo of a photo removal).
  void _restoreDoc(List<JournalBlock> doc) {
    if (!mounted) return;
    setState(() {
      for (final b in _blocks) {
        b.dispose();
      }
      _blocks.clear();
      var textIndex = 0;
      for (final jb in doc) {
        final isPrompt =
            !jb.isImage &&
            textIndex == 0 &&
            (widget.starter?.isNotEmpty ?? false) &&
            (jb.text?.startsWith(widget.starter!) ?? false);
        _blocks.add(
          jb.isImage
              ? _Block.image(jb.image!)
              : _Block.text(
                  jb.text ?? '',
                  promptPrefix: isPrompt ? widget.starter : null,
                  promptColor: isPrompt
                      ? widget.accent.withValues(alpha: 0.92)
                      : null,
                ),
        );
        if (!jb.isImage) textIndex++;
      }
      if (_blocks.isEmpty || _blocks.last.isImage) {
        _blocks.add(_Block.text(''));
      }
      for (final b in _blocks) {
        b.controller?.addListener(_onChanged);
      }
      _active = _blocks.lastWhere(
        (x) => !x.isImage,
        orElse: () => _blocks.first,
      );
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
                _sourceTile(
                  Icons.photo_library_outlined,
                  'Choose photos',
                  () => Navigator.pop(context, false),
                ),
                const SizedBox(height: 6),
                _sourceTile(
                  Icons.photo_camera_outlined,
                  'Take a photo',
                  () => Navigator.pop(context, true),
                ),
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
              Text(
                label,
                style: Type.body.copyWith(fontSize: 15, color: Palette.textHi),
              ),
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
        title: Text(
          'Delete this entry?',
          style: Type.display.copyWith(fontSize: 18),
        ),
        content: Text(
          'This can’t be undone.',
          style: Type.body.copyWith(fontSize: 14, color: Palette.textMid),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'Keep',
              style: Type.label.copyWith(color: Palette.textMid),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              'Delete',
              style: Type.label.copyWith(color: Palette.streak),
            ),
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
          reduceMotion: widget.reduceMotion,
          tint: widget.accent,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // The editor belongs to the same moonlit desk as the Journal
              // hub. Only the upper scene is exposed; live writing gets a
              // dedicated physical plane instead of floating over scenery.
              const Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: 248,
                child: _JournalDeskBackdrop(),
              ),
              SafeArea(
                child: Column(
                  children: [
                    _bar(),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(10, 6, 10, 10),
                        child: _JournalPageSurface(
                          key: const ValueKey('journal-writing-page'),
                          child: LayoutBuilder(
                            builder: (context, page) {
                              // At very large text on a short phone, the date,
                              // photo action, and attached Quest context can be
                              // taller than the whole paper. Let that metadata
                              // scroll within the upper half so it never pushes
                              // the actual writing field out of the page.
                              final header = Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _pageHeader(),
                                  if (widget.trace != null)
                                    _tracePanel(widget.trace!),
                                  _pageRule(),
                                ],
                              );
                              return Column(
                                children: [
                                  ConstrainedBox(
                                    constraints: BoxConstraints(
                                      maxHeight: page.maxHeight * 0.56,
                                    ),
                                    child: SingleChildScrollView(child: header),
                                  ),
                                  Expanded(
                                    // The whole physical page remains tappable,
                                    // including the space below the last paragraph.
                                    child: GestureDetector(
                                      behavior: HitTestBehavior.translucent,
                                      onTap: _editing ? _focusTail : null,
                                      child: ListView.builder(
                                        padding: const EdgeInsets.fromLTRB(
                                          20,
                                          12,
                                          20,
                                          28,
                                        ),
                                        keyboardDismissBehavior:
                                            ScrollViewKeyboardDismissBehavior
                                                .onDrag,
                                        itemCount: _blocks.length,
                                        itemBuilder: (_, i) =>
                                            _blockView(_blocks[i], i == 0),
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
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
    );
  }

  Widget _pageHeader() {
    final when = Text(
      _whenLine,
      style: Type.label.copyWith(fontSize: 11, color: Palette.textMid),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 13, 14, 9),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (kIsWeb || !_editing) {
            return Align(alignment: Alignment.centerLeft, child: when);
          }
          final stacked =
              MediaQuery.textScalerOf(context).scale(1) > 1.15 ||
              constraints.maxWidth < 350;
          final action = _photoAction();
          if (stacked) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [when, const SizedBox(height: 9), action],
            );
          }
          return Row(
            children: [
              Expanded(child: when),
              const SizedBox(width: 12),
              action,
            ],
          );
        },
      ),
    );
  }

  Widget _pageRule() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 18),
    child: Row(
      children: [
        Container(width: 22, height: 1, color: Palette.brass),
        const SizedBox(width: 5),
        Expanded(
          child: Container(
            height: 1,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0x708E6134), Color(0x148E6134)],
              ),
            ),
          ),
        ),
      ],
    ),
  );

  Widget _tracePanel(JournalTrace trace) {
    final gains = trace.statGains.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final facts = <String>[
      if (trace.questTitles.isNotEmpty)
        '${trace.questTitles.length} ${trace.questTitles.length == 1 ? 'quest' : 'quests'}',
      if (trace.todayXp > 0) '+${trace.todayXp} XP',
      if (gains.isNotEmpty)
        '${gains.first.key.label.toUpperCase()} +${gains.first.value}',
      if (trace.goalTitles.isNotEmpty) trace.goalTitles.first,
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
      child: GlassPanel(
        padding: const EdgeInsets.fromLTRB(12, 9, 12, 9),
        tint: const Color(0xE8251C17),
        child: Row(
          children: [
            const FacetMedallion(
              size: 30,
              accent: Palette.xp,
              child: Icon(Icons.link_rounded, size: 15, color: Palette.xpLight),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ATTACHED TO THIS PAGE',
                    style: Type.label.copyWith(
                      fontSize: Type.minLabel,
                      color: Palette.xpLight,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    facts.isEmpty
                        ? 'Level ${trace.level} · ${trace.totalXp} total XP'
                        : facts.join('  ·  '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Type.body.copyWith(
                      fontSize: 11.5,
                      color: Palette.textLo,
                    ),
                  ),
                  if (trace.questTitles.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      trace.questTitles.take(2).join('  ·  '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Type.body.copyWith(
                        fontSize: 11.5,
                        fontStyle: FontStyle.italic,
                        color: Palette.textMid,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
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
            ClipPath(
              clipper: const FacetedClipper(cut: 12),
              child: media.image(b.image!),
            ),
            if (_editing)
              Positioned(
                top: 2,
                right: 2,
                child: Semantics(
                  button: true,
                  label: 'Remove photo',
                  onTap: () => _removeImage(b),
                  excludeSemantics: true,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _removeImage(b),
                    // A generous transparent margin around the dot keeps the
                    // destructive target at 48px; Undo remains available.
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      color: Colors.transparent,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: facetedDecoration(
                          cut: 6,
                          color: Color(0x99140C06),
                          borderColor: Palette.glassEdge,
                        ),
                        child: const Icon(
                          Icons.close,
                          size: 16,
                          color: Palette.textHi,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
    }
    return TextField(
      key: first ? const ValueKey('journal-entry-body') : null,
      controller: b.controller,
      focusNode: b.focus,
      readOnly: !_editing,
      showCursor: _editing,
      onTap: _editing ? () => _active = b : null,
      maxLines: null,
      textCapitalization: TextCapitalization.sentences,
      keyboardType: TextInputType.multiline,
      cursorColor: widget.accent,
      style: Type.body.copyWith(
        fontFamily: 'EBGaramond',
        fontSize: 19,
        fontWeight: FontWeight.w500,
        height: 1.48,
        color: Palette.textHi,
      ),
      decoration: InputDecoration(
        border: InputBorder.none,
        isCollapsed: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 4),
        hintText: first ? widget.hint : null,
        hintStyle: Type.body.copyWith(
          fontFamily: 'EBGaramond',
          fontSize: 19,
          fontWeight: FontWeight.w500,
          height: 1.48,
          color: const Color(0xFFB8AA99),
        ),
      ),
    );
  }

  Widget _bar() {
    final writtenWords = (_words - _starterWords).clamp(0, _words);
    final statusLabel = _dirty
        ? 'Saving…'
        : _everSaved
        ? 'Saved locally'
        : 'Saves automatically';
    final status = ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 190),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _dirty ? Icons.sync : Icons.check_circle_outline,
            size: 14,
            color: Palette.textLo,
          ),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              statusLabel,
              softWrap: true,
              style: Type.label.copyWith(
                fontSize: Type.minLabel,
                color: Palette.textLo,
              ),
            ),
          ),
        ],
      ),
    );
    final wordLabel = writtenWords > 0
        ? '$writtenWords ${writtenWords == 1 ? 'word' : 'words'}'
        : widget.starter != null
        ? 'PROMPT READY'
        : null;
    final back = Semantics(
      button: true,
      label: 'Back',
      onTap: () {
        Navigator.of(context).maybePop();
      },
      excludeSemantics: true,
      child: SizedBox.square(
        dimension: 48,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => Navigator.of(context).maybePop(),
          child: const Icon(
            Icons.chevron_left,
            size: 26,
            color: Palette.textMid,
          ),
        ),
      ),
    );
    final remove = _current == null
        ? const SizedBox(width: 4)
        : Semantics(
            button: true,
            label: 'Delete entry',
            onTap: _confirmDelete,
            excludeSemantics: true,
            child: SizedBox.square(
              dimension: 48,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _confirmDelete,
                child: const Icon(
                  Icons.delete_outline,
                  size: 20,
                  color: Palette.textLo,
                ),
              ),
            ),
          );
    final edit = Semantics(
      key: const ValueKey('journal-entry-edit'),
      button: true,
      label: 'Edit journal entry',
      onTap: _beginEditing,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _beginEditing,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48, minWidth: 72),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.edit_outlined, size: 17, color: widget.accent),
              const SizedBox(width: 6),
              Text(
                'EDIT',
                style: Type.label.copyWith(
                  fontSize: 11,
                  letterSpacing: 1.1,
                  color: widget.accent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    // Autosave is real, but an editor with no way to say "I'm finished" reads
    // as one that might lose the page. DONE commits, closes the keyboard, and
    // shows the kept entry — the reassurance is seeing it saved.
    final done = Semantics(
      key: const ValueKey('journal-entry-done'),
      button: true,
      label: 'Done writing — entry is saved',
      onTap: _finishEditing,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _finishEditing,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
          decoration: facetedDecoration(
            cut: 7,
            gradient: Palette.honeyGradient,
          ),
          child: Text(
            'DONE',
            style: Type.label.copyWith(
              fontSize: 11,
              letterSpacing: 1.1,
              color: Palette.onHoney,
            ),
          ),
        ),
      ),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 6, 12, 2),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final large =
              MediaQuery.textScalerOf(context).scale(1) > 1.15 ||
              constraints.maxWidth < 370;
          // A Quest title is often more specific than the ordinary "Journal"
          // heading. Give longer authored titles the full row instead of
          // squeezing them beside the save status and fading the final word.
          // While editing, the bar also carries DONE — below ~430dp that row
          // needs the stacked layout to keep every control on screen.
          final stacked =
              large ||
              widget.heading.length > 18 ||
              (_editing && constraints.maxWidth < 430);
          final heading = Expanded(
            child: Text(
              widget.heading,
              maxLines: stacked ? 3 : 2,
              overflow: TextOverflow.fade,
              style: Type.display.copyWith(fontSize: 20, color: widget.accent),
            ),
          );
          final meta = Wrap(
            alignment: WrapAlignment.end,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 10,
            runSpacing: 4,
            children: [
              if (wordLabel != null)
                Text(
                  wordLabel,
                  style: Type.label.copyWith(
                    fontSize: Type.minLabel,
                    color: Palette.textLo,
                  ),
                ),
              status,
            ],
          );
          if (stacked) {
            return Column(
              children: [
                Row(
                  children: [
                    back,
                    heading,
                    if (_editing) ...[done, const SizedBox(width: 2)],
                    _editing ? remove : edit,
                  ],
                ),
                if (_editing)
                  Align(alignment: Alignment.centerRight, child: meta),
              ],
            );
          }
          if (!_editing) {
            return Row(children: [back, heading, edit]);
          }
          return Row(
            children: [
              back,
              heading,
              const SizedBox(width: 8),
              meta,
              const SizedBox(width: 8),
              done,
              const SizedBox(width: 2),
              remove,
            ],
          );
        },
      ),
    );
  }

  Widget _photoAction() {
    final photoCount = _blocks.where((b) => b.isImage).length;
    final privacy = kVisitorPhotoSharingEnabled
        ? 'Photos stay on this device unless you separately share one on your visitor page.'
        : 'Room of Days keeps photos local.';
    final semantics = photoCount == 0
        ? 'Add photos to this journal entry. $privacy'
        : 'Add more photos to this journal entry. $photoCount ${photoCount == 1 ? 'photo' : 'photos'} on this page. $privacy';
    return Semantics(
      key: const ValueKey('journal-photo-action'),
      button: true,
      label: semantics,
      onTap: _pickPhotoSource,
      excludeSemantics: true,
      child: Tooltip(
        message: 'Add photos',
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _pickPhotoSource,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44, maxWidth: 220),
            child: DecoratedBox(
              decoration: facetedDecoration(
                cut: 8,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    widget.accent.withValues(alpha: 0.18),
                    const Color(0x4D160F0C),
                  ],
                ),
                borderColor: widget.accent.withValues(alpha: 0.48),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 7,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.add_photo_alternate_outlined,
                      size: 18,
                      color: widget.accent,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            photoCount == 0 ? 'ADD PHOTOS' : 'ADD MORE',
                            softWrap: true,
                            style: Type.label.copyWith(
                              fontSize: 11,
                              color: widget.accent,
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            photoCount == 0
                                ? 'kept on this device'
                                : '$photoCount on this page \u00B7 local',
                            softWrap: true,
                            style: Type.body.copyWith(
                              fontSize: 10.5,
                              color: Palette.textMid,
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
        ),
      ),
    );
  }
}
