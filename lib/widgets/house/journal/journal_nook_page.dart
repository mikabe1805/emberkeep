// The Journal as the reading nook: the room's painted plate behind, the
// "Write for today" card low in it, and everything the old Journal tab held
// (lenses, Your Journal and Your Week, energy weather, domains, rhythm, the
// last two weeks, the sky) as a quiet lower section you scroll down into.
//
// The plate stays where it is. The first screen is the nook exactly as it was
// painted (the card sits just above the dock, the Keepsakes label on the box),
// and as the page scrolls a warm dark comes up over the painting so the lower
// cards read cleanly. The nook keeps its painted daylight: nothing here tints
// the plate (an evening plate is a one-line change in house_room.dart).
library;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';

import '../../../models.dart';
import '../../class_day/class_day_room.dart' show classStatusAbove;
import '../house_hud.dart' show houseHudBottom;
import '../house_backdrop.dart';
import '../house_room.dart';
import 'journal_nook.dart';

/// Canvas pt (393 x 852) the plate was painted for: the Keepsakes label's top
/// edge and its right inset, from the approved frame.
const double journalTagTop = 398;
const double journalTagRight = 14;

class JournalNookPage extends StatefulWidget {
  const JournalNookPage({
    super.key,
    required this.date,
    required this.prompts,
    required this.recent,
    required this.lower,
    required this.onWrite,
    required this.onPrompt,
    required this.onEntry,
    required this.onAllEntries,
    required this.onKeepsakes,
    this.parallax,
    this.reduceMotion,
  });

  final DateTime date;
  final List<JournalPrompt> prompts;
  final List<Note> recent;

  /// The page's own cards under the nook, top to bottom (each is laid out
  /// with a gap between). Nothing the old Journal tab held is dropped.
  final List<Widget> lower;

  final VoidCallback onWrite;
  final ValueChanged<JournalPrompt> onPrompt;
  final ValueChanged<Note> onEntry;
  final VoidCallback onAllEntries;
  final VoidCallback onKeepsakes;

  final ValueListenable<Offset>? parallax;

  /// Null reads the app's and the system's Reduce Motion.
  final bool? reduceMotion;

  @override
  State<JournalNookPage> createState() => _JournalNookPageState();
}

class _JournalNookPageState extends State<JournalNookPage> {
  final ScrollController _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  double get _offset => _scroll.hasClients ? _scroll.offset : 0;

  @override
  Widget build(BuildContext context) {
    final above = classStatusAbove(context);
    return HouseRoomBackdrop(
      room: HouseRoom.journal,
      parallax: widget.parallax,
      reduceMotion: widget.reduceMotion,
      child: LayoutBuilder(
        builder: (context, box) {
          // The plate is fitted to the width, so one canvas point is this many
          // screen points across and down; the status bar above the page is
          // part of the plate.
          final sx = box.maxWidth / houseCanvasWidth;
          final inset = 21 * sx;
          final dock = 88 + MediaQuery.paddingOf(context).bottom;
          final tagTop = journalTagTop * sx - above;
          // At rest the label hangs on the painted box and the card stays
          // below it. Under large text the card needs the room, so the label
          // rides just above the card instead and the card may cover more of
          // the painting; nothing is ever cut off.
          final large = MediaQuery.textScalerOf(context).scale(1) > 1.15;
          final reserveTop = large ? 12.0 : tagTop + 28 * sx + 14;
          return Stack(
            clipBehavior: Clip.none,
            fit: StackFit.expand,
            children: [
              // The warm dark that comes up over the painting as the page
              // climbs, running up under the status bar so the plate has no
              // seam there.
              Positioned(
                left: 0,
                right: 0,
                top: -above,
                bottom: 0,
                child: IgnorePointer(
                  child: AnimatedBuilder(
                    animation: _scroll,
                    builder: (context, _) => Opacity(
                      opacity: (_offset / (box.maxHeight * 0.4)).clamp(
                        0.0,
                        0.94,
                      ),
                      child: const ColoredBox(color: Color(0xF017100D)),
                    ),
                  ),
                ),
              ),
              ListView(
                key: const ValueKey('journal-nook-scroll'),
                controller: _scroll,
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                padding: EdgeInsets.zero,
                children: [
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: box.maxHeight - dock,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(height: reserveTop),
                        if (large)
                          Padding(
                            padding: EdgeInsets.only(
                              right: journalTagRight * sx,
                              bottom: 2,
                            ),
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: JournalKeepsakesTag(
                                onTap: widget.onKeepsakes,
                              ),
                            ),
                          ),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: inset),
                          child: JournalNookCard(
                            date: widget.date,
                            prompts: widget.prompts,
                            recent: widget.recent,
                            onWrite: widget.onWrite,
                            onPrompt: widget.onPrompt,
                            onEntry: widget.onEntry,
                            onAllEntries: widget.onAllEntries,
                          ),
                        ),
                        const SizedBox(height: 6),
                      ],
                    ),
                  ),
                  Padding(
                    key: const ValueKey('journal-nook-lower'),
                    padding: EdgeInsets.fromLTRB(inset, 4, inset, dock + 42),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (var i = 0; i < widget.lower.length; i++) ...[
                          if (i > 0) const SizedBox(height: 14),
                          widget.lower[i],
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              // Pages that climb past the top dissolve into the dark instead
              // of being cut by a hard edge.
              Positioned(
                left: 0,
                right: 0,
                top: -above,
                // Down past the shell's HUD, so a card climbing under it
                // dissolves instead of crossing its numbers.
                height:
                    above +
                    houseHudBottom(
                      textScale: MediaQuery.textScalerOf(context).scale(1),
                    ) +
                    14,
                child: IgnorePointer(
                  child: AnimatedBuilder(
                    animation: _scroll,
                    builder: (context, _) => Opacity(
                      opacity: (_offset / 60).clamp(0.0, 1.0),
                      child: const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Color(0xFF17100D), Color(0x0017100D)],
                            stops: [0.84, 1],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              // The label belongs to the painted box, so it stays with the
              // plate and gives way as the page climbs over it.
              if (!large)
                Positioned(
                  top: tagTop - 8,
                  right: journalTagRight * sx,
                  child: AnimatedBuilder(
                    animation: _scroll,
                    child: JournalKeepsakesTag(onTap: widget.onKeepsakes),
                    builder: (context, child) {
                      final shown = (1 - _offset / 70).clamp(0.0, 1.0);
                      return IgnorePointer(
                        ignoring: shown < 0.4,
                        child: Opacity(opacity: shown, child: child),
                      );
                    },
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
