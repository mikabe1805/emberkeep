import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../audio.dart';
import '../models.dart';
import '../tokens.dart';
import 'glass.dart';

/// Warm, human relative time for a note: "just now" / "2h ago" / "yesterday" /
/// "3 days ago" / "Mar 4" — never a raw timestamp.
String relativeWhen(DateTime then, {DateTime? now}) {
  final n = now ?? DateTime.now();
  final today = DateTime(n.year, n.month, n.day);
  final thatDay = DateTime(then.year, then.month, then.day);
  final dayGap = today.difference(thatDay).inDays;
  if (dayGap == 0) {
    final mins = n.difference(then).inMinutes;
    if (mins < 1) return 'just now';
    if (mins < 60) return '${mins}m ago';
    return '${n.difference(then).inHours}h ago';
  }
  if (dayGap == 1) return 'yesterday';
  if (dayGap < 7) return '$dayGap days ago';
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${months[then.month - 1]} ${then.day}';
}

/// The one notes surface — used for a quest log, a goal journal, a domain base,
/// or a free reflection. The owner keeps the list; this sheet reads it via
/// [read] and reports edits through [onAdd]/[onDelete] so persistence stays at
/// the call site. Notes are shown newest-first.
Future<void> showNotesSheet(
  BuildContext context, {
  required String kicker, // "LOG" / "JOURNAL" / "NOTES"
  required String title,
  required Color accent,
  required IconData icon,
  required List<Note> Function() read,
  required void Function(String text) onAdd,
  required void Function(Note note) onDelete,
  void Function(Note original, String newText)? onEdit,
  String? subtitle,
  String hint = 'Add a note…',
  String emptyHint = 'Nothing here yet. Jot whatever you’ll want to remember.',
  void Function(String text)? onMakeQuest,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _NotesSheet(
      kicker: kicker,
      title: title,
      accent: accent,
      icon: icon,
      read: read,
      onAdd: onAdd,
      onDelete: onDelete,
      onEdit: onEdit,
      subtitle: subtitle,
      hint: hint,
      emptyHint: emptyHint,
      onMakeQuest: onMakeQuest,
    ),
  );
}

/// The in-place journal preview used on the goal sheet and the domain base: a
/// glass panel showing the latest entry (with its "where I was" marker) and a
/// count, that opens the full [showNotesSheet] on tap. Self-managing — refreshes
/// its preview after an edit — so both screens share ONE implementation.
class JournalPanel extends StatefulWidget {
  const JournalPanel({
    super.key,
    required this.title,
    required this.accent,
    required this.read,
    required this.onAdd,
    required this.onDelete,
    required this.emptyPreview,
    required this.emptyHint,
    this.onEdit,
    this.subtitle,
    this.hint = 'How’s it going?',
    this.onMakeQuest,
  });

  final String title;
  final Color accent;
  final List<Note> Function() read;
  final void Function(String text) onAdd;
  final void Function(Note note) onDelete;

  /// Optional — edit an existing entry in place (replace by id).
  final void Function(Note original, String newText)? onEdit;

  /// Optional — turns a journal entry into a quest (notes-with-consequence).
  final void Function(String text)? onMakeQuest;

  /// In-panel prompt when there are no entries yet.
  final String emptyPreview;

  /// Empty-state copy inside the opened sheet.
  final String emptyHint;
  final String? subtitle;
  final String hint;

  @override
  State<JournalPanel> createState() => _JournalPanelState();
}

class _JournalPanelState extends State<JournalPanel> {
  void _open() {
    Sfx.instance.play('tick');
    showNotesSheet(
      context,
      kicker: 'JOURNAL',
      title: widget.title,
      icon: Icons.auto_stories_outlined,
      accent: widget.accent,
      subtitle: widget.subtitle,
      hint: widget.hint,
      emptyHint: widget.emptyHint,
      read: widget.read,
      onAdd: (t) {
        widget.onAdd(t);
        if (mounted) setState(() {});
      },
      onDelete: (n) {
        widget.onDelete(n);
        if (mounted) setState(() {});
      },
      onEdit: widget.onEdit == null
          ? null
          : (orig, t) {
              widget.onEdit!(orig, t);
              if (mounted) setState(() {});
            },
      onMakeQuest: widget.onMakeQuest,
    );
  }

  @override
  Widget build(BuildContext context) {
    final notes = widget.read();
    final latest = notes.isEmpty ? null : notes.last;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _open,
      child: GlassPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.auto_stories_outlined,
                  size: 15,
                  color: widget.accent,
                ),
                const SizedBox(width: 8),
                Text('JOURNAL', style: Type.label.copyWith(fontSize: 11)),
                if (notes.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  Text(
                    '${notes.length}',
                    style: Type.numerals.copyWith(
                      fontSize: 12,
                      color: widget.accent,
                    ),
                  ),
                ],
                const Spacer(),
                Icon(
                  latest == null ? Icons.add : Icons.chevron_right,
                  size: 18,
                  color: Palette.textLo,
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (latest == null)
              Text(
                widget.emptyPreview,
                style: Type.body.copyWith(fontSize: 13, color: Palette.textLo),
              )
            else ...[
              Text(
                latest.text,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: Type.body.copyWith(fontSize: 14, color: Palette.textHi),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  if (latest.context != null) ...[
                    Text(
                      latest.context!,
                      style: Type.label.copyWith(
                        fontSize: 11,
                        color: widget.accent,
                      ),
                    ),
                    Text(
                      '  ·  ',
                      style: Type.label.copyWith(
                        fontSize: 11,
                        color: Palette.textLo,
                      ),
                    ),
                  ],
                  Text(
                    relativeWhen(latest.at),
                    style: Type.label.copyWith(
                      fontSize: 11,
                      color: Palette.textLo,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _NotesSheet extends StatefulWidget {
  const _NotesSheet({
    required this.kicker,
    required this.title,
    required this.accent,
    required this.icon,
    required this.read,
    required this.onAdd,
    required this.onDelete,
    required this.onEdit,
    required this.subtitle,
    required this.hint,
    required this.emptyHint,
    required this.onMakeQuest,
  });
  final String kicker;
  final String title;
  final Color accent;
  final IconData icon;
  final List<Note> Function() read;
  final void Function(String text) onAdd;
  final void Function(Note note) onDelete;
  final void Function(Note original, String newText)? onEdit;
  final String? subtitle;
  final String hint;
  final String emptyHint;
  final void Function(String text)? onMakeQuest;

  @override
  State<_NotesSheet> createState() => _NotesSheetState();
}

class _NotesSheetState extends State<_NotesSheet> {
  final _controller = TextEditingController();
  final _focus = FocusNode();

  /// When set, the composer is editing this existing entry rather than adding.
  Note? _editing;

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    Sfx.instance.play('tick');
    HapticFeedback.selectionClick();
    final editing = _editing;
    if (editing != null && widget.onEdit != null) {
      widget.onEdit!(editing, text);
    } else {
      widget.onAdd(text);
    }
    setState(() {
      _controller.clear();
      _editing = null;
    });
    _focus.requestFocus(); // stay ready to jot another
  }

  void _startEdit(Note note) {
    setState(() {
      _editing = note;
      _controller.text = note.text;
      _controller.selection =
          TextSelection.collapsed(offset: note.text.length);
    });
    _focus.requestFocus();
  }

  void _cancelEdit() {
    setState(() {
      _editing = null;
      _controller.clear();
    });
  }

  void _delete(Note note) {
    Sfx.instance.play('boing');
    if (_editing?.id == note.id) {
      _editing = null;
      _controller.clear();
    }
    widget.onDelete(note);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final notes = widget.read().reversed.toList(); // newest first
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: GlassPanel(
            tint: const Color(0xF22A211D),
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(widget.icon, size: 16, color: widget.accent),
                    const SizedBox(width: 8),
                    Text(
                      widget.kicker,
                      style: Type.label.copyWith(
                        fontSize: 12,
                        color: widget.accent,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  widget.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Type.display.copyWith(fontSize: 17),
                ),
                if (widget.subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    widget.subtitle!,
                    style: Type.body.copyWith(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                      color: Palette.textLo,
                    ),
                  ),
                ],
                const SizedBox(height: 14),

                // ── past notes ──────────────────────────────────────
                if (notes.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      widget.emptyHint,
                      style: Type.body.copyWith(
                        fontSize: 13,
                        color: Palette.textLo,
                      ),
                    ),
                  )
                else
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 320),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: notes.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (_, i) => _NoteRow(
                        note: notes[i],
                        accent: widget.accent,
                        editing: _editing?.id == notes[i].id,
                        onDelete: () => _delete(notes[i]),
                        onEdit: widget.onEdit == null
                            ? null
                            : () => _startEdit(notes[i]),
                        onMakeQuest: widget.onMakeQuest == null
                            ? null
                            : () {
                                // close the sheet first so the creation sheet
                                // opens cleanly (not modal-over-modal)
                                Navigator.of(context).pop();
                                widget.onMakeQuest!(notes[i].text);
                              },
                      ),
                    ),
                  ),
                const SizedBox(height: 12),

                // ── editing banner (tap an entry to revise it) ──────
                if (_editing != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Icon(Icons.edit_outlined,
                            size: 14, color: widget.accent),
                        const SizedBox(width: 6),
                        Text(
                          'Editing entry',
                          style: Type.label.copyWith(
                              fontSize: 11, color: widget.accent),
                        ),
                        const Spacer(),
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: _cancelEdit,
                          child: Padding(
                            padding: const EdgeInsets.all(2),
                            child: Text(
                              'cancel',
                              style: Type.label.copyWith(
                                  fontSize: 11, color: Palette.textLo),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                // ── add / save a note ───────────────────────────────
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        focusNode: _focus,
                        autofocus: notes.isEmpty,
                        minLines: 1,
                        maxLines: 4,
                        textInputAction: TextInputAction.newline,
                        textCapitalization: TextCapitalization.sentences,
                        style: Type.body.copyWith(
                          fontSize: 14,
                          color: Palette.textHi,
                        ),
                        cursorColor: widget.accent,
                        decoration: InputDecoration(
                          hintText: widget.hint,
                          hintStyle: Type.body.copyWith(
                            fontSize: 14,
                            color: Palette.textLo,
                          ),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          filled: true,
                          fillColor: Palette.glassFill,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(
                              color: Palette.glassEdge,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(
                              color: Palette.glassEdge,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                              color: widget.accent.withValues(alpha: 0.7),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _submit,
                      child: Container(
                        width: 46,
                        height: 46,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Color(0xFFF6D9A2),
                              Color(0xFFEFC074),
                              Color(0xFFC08B4F),
                            ],
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: Palette.honeyGlow,
                              blurRadius: 14,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Icon(
                          _editing != null ? Icons.check : Icons.add,
                          size: 22,
                          color: const Color(0xFF4A2F1A),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NoteRow extends StatelessWidget {
  const _NoteRow({
    required this.note,
    required this.accent,
    required this.onDelete,
    this.editing = false,
    this.onEdit,
    this.onMakeQuest,
  });
  final Note note;
  final Color accent;
  final VoidCallback onDelete;

  /// Whether this row is the one currently loaded in the composer for editing.
  final bool editing;

  /// When set, tapping the row loads it into the composer to revise in place.
  final VoidCallback? onEdit;

  /// When set, a small "→ quest" affordance turns this reflection into a quest.
  final VoidCallback? onMakeQuest;

  @override
  Widget build(BuildContext context) {
    final row = Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: editing ? accent.withValues(alpha: 0.10) : Palette.glassFill,
        border: Border.all(
          color: editing ? accent.withValues(alpha: 0.6) : Palette.glassEdge,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 5, right: 10),
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accent.withValues(alpha: 0.8),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  note.text,
                  style: Type.body.copyWith(
                    fontSize: 14,
                    color: Palette.textHi,
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    // the "where I was" marker — proof of becoming
                    if (note.context != null) ...[
                      Text(
                        note.context!,
                        style: Type.label.copyWith(fontSize: 11, color: accent),
                      ),
                      Text(
                        '  ·  ',
                        style: Type.label.copyWith(
                          fontSize: 11,
                          color: Palette.textLo,
                        ),
                      ),
                    ],
                    Text(
                      relativeWhen(note.at),
                      style: Type.label.copyWith(
                        fontSize: 11,
                        color: Palette.textLo,
                      ),
                    ),
                    if (note.editedAt != null)
                      Text(
                        '  ·  edited',
                        style: Type.label.copyWith(
                          fontSize: 11,
                          color: Palette.textLo,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          if (onMakeQuest != null)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onMakeQuest,
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Icon(Icons.bolt, size: 16, color: accent),
              ),
            ),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onDelete,
            child: const Padding(
              padding: EdgeInsets.all(6),
              child: Icon(Icons.close, size: 16, color: Palette.textLo),
            ),
          ),
        ],
      ),
    );
    if (onEdit == null) return row;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onEdit,
      child: row,
    );
  }
}
