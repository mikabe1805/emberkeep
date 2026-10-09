import 'dart:async';

import 'package:emberkeep/class_day_links.dart';
import 'package:emberkeep/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _RecordingBoard with ClassDayLinkTarget {
  final List<String> calls = [];
  final List<DateTime?> ats = [];

  @override
  void showClassDay() => calls.add('show');

  @override
  Future<bool> markClassFromLink(
    String occurrenceKey,
    String dayKey, {
    DateTime? at,
  }) async {
    calls.add('mark $occurrenceKey $dayKey');
    ats.add(at);
    await Future<void>.delayed(Duration.zero);
    return true;
  }

  @override
  Future<bool> markClassesFromLink(
    List<String> occurrenceKeys,
    String dayKey, {
    DateTime? at,
  }) async {
    calls.add('mark all ${occurrenceKeys.join(',')} $dayKey');
    ats.add(at);
    return true;
  }
}

/// A board whose keeps finish only when the test says the celebration
/// closed.
class _HoldingBoard with ClassDayLinkTarget {
  final List<String> calls = [];
  final List<Completer<bool>> holds = [];

  @override
  void showClassDay() => calls.add('show');

  @override
  Future<bool> markClassFromLink(
    String occurrenceKey,
    String dayKey, {
    DateTime? at,
  }) {
    calls.add('mark $occurrenceKey');
    final hold = Completer<bool>();
    holds.add(hold);
    return hold.future;
  }
}

/// A board that has not wired the class day yet: only the defaults.
class _UnwiredBoard with ClassDayLinkTarget {}

class _WiredBoard with ClassDayLinkTarget {
  @override
  bool get marksClassesFromLinks => true;
}

final _tap = DateTime.utc(2026, 10, 6, 15, 52);

ClassDayBoardRequest _mark(String key, [String day = '2026-10-06']) =>
    ClassDayBoardRequest.mark(
      occurrenceKey: key,
      dayKey: day,
      requestedAt: _tap,
    );

ClassDayBoardRequest _open() => ClassDayBoardRequest.open(requestedAt: _tap);

Future<void> _flush() async {
  for (var i = 0; i < 10; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  group('parsing', () {
    test('the open link', () {
      expect(
        ClassDayLink.fromUri(Uri.parse('roomofdays://class-day')),
        const ClassDayLink.open(),
      );
      expect(
        ClassDayLink.fromUri(Uri.parse('roomofdays://class-day/')),
        const ClassDayLink.open(),
      );
      expect(classDayOpenUrl, 'roomofdays://class-day');
    });

    test('a mark link round-trips any occurrence key', () {
      const key = 'occ_9f3a@rutgers-f26-ece331-tu:2026-10-06 &x=1';
      final url = classDayMarkUrl(key, '2026-10-06');
      expect(url, startsWith('roomofdays://class-day/mark?occurrence='));
      expect(url, isNot(contains(' ')));
      expect(
        ClassDayLink.fromUri(Uri.parse(url)),
        const ClassDayLink.mark(occurrenceKey: key, dayKey: '2026-10-06'),
      );
      final link = ClassDayLink.fromUri(
        Uri.parse(
          'roomofdays://class-day/mark?occurrence=abc123&day=2026-10-06',
        ),
      )!;
      expect(link.isMark, isTrue);
      expect(link.occurrenceKey, 'abc123');
      expect(link.dayKey, '2026-10-06');
    });

    test('a mark-all link round-trips its day', () {
      final url = classDayMarkAllUrl('2026-10-05');
      expect(url, 'roomofdays://class-day/mark-all?day=2026-10-05');
      final link = ClassDayLink.fromUri(Uri.parse(url))!;
      expect(link, const ClassDayLink.markAll(dayKey: '2026-10-05'));
      expect(link.isMarkAll, isTrue);
      expect(link.isMark, isFalse);
      expect(link.occurrenceKey, isNull);
      expect(
        ClassDayLink.fromUri(
          Uri.parse('https://roomofdays.com/class-day/mark-all?day=2026-10-05'),
        ),
        const ClassDayLink.markAll(dayKey: '2026-10-05'),
      );
    });

    test('the path form a universal link would use', () {
      expect(
        ClassDayLink.fromUri(
          Uri.parse(
            'https://roomofdays.com/class-day/mark?occurrence=k&day=2026-10-06',
          ),
        ),
        const ClassDayLink.mark(occurrenceKey: 'k', dayKey: '2026-10-06'),
      );
      expect(
        ClassDayLink.fromUri(Uri.parse('/class-day')),
        const ClassDayLink.open(),
      );
      expect(
        ClassDayLink.fromUri(
          Uri.parse('roomofdays:///class-day/mark?occurrence=k&day=2026-10-06'),
        ),
        const ClassDayLink.mark(occurrenceKey: 'k', dayKey: '2026-10-06'),
      );
    });

    test('a damaged mark link still opens the class day', () {
      for (final raw in [
        'roomofdays://class-day/mark',
        'roomofdays://class-day/mark?occurrence=k',
        'roomofdays://class-day/mark?occurrence=k&day=2026-02-31',
        'roomofdays://class-day/mark?occurrence=&day=2026-10-06',
        'roomofdays://class-day/mark?occurrence=${'k' * 201}&day=2026-10-06',
        'roomofdays://class-day/mark-all',
        'roomofdays://class-day/mark-all?day=yesterday',
        'roomofdays://class-day/mark/extra?occurrence=k&day=2026-10-06',
        'roomofdays://class-day/somewhere-else',
      ]) {
        expect(
          ClassDayLink.fromUri(Uri.parse(raw)),
          const ClassDayLink.open(),
          reason: raw,
        );
      }
    });

    test('other links are not class-day links', () {
      for (final raw in [
        'https://roomofdays.com/?space=ABCD2345',
        'https://roomofdays.com/space/ABCD2345',
        'roomofdays://space/ABCD2345',
        'roomofdays://',
        'mailto:support@roomofdays.com',
        '/',
        'https://example.com/class-days',
        'https://example.com/class-day/mark?occurrence=k&day=2026-10-06',
      ]) {
        expect(ClassDayLink.fromUri(Uri.parse(raw)), isNull, reason: raw);
      }
    });
  });

  group('inbox', () {
    tearDown(Clock.reset);

    test('takes links in order, stamped with their arrival', () {
      Clock.freeze(DateTime.utc(2026, 10, 6, 15, 52));
      final inbox = ClassDayLinkInbox();
      var notified = 0;
      inbox.addListener(() => notified++);
      expect(inbox.enqueueUri(Uri.parse('https://roomofdays.com/')), isFalse);
      expect(inbox.enqueueUri(Uri.parse('roomofdays://class-day')), isTrue);
      expect(
        inbox.enqueueUri(
          Uri.parse('roomofdays://class-day/mark?occurrence=k&day=2026-10-06'),
        ),
        isTrue,
      );
      expect(notified, 2);
      final first = inbox.takeNext()!;
      final second = inbox.takeNext()!;
      expect(first.link.isMark, isFalse);
      expect(second.link.occurrenceKey, 'k');
      expect(second.sequence, greaterThan(first.sequence));
      expect(second.receivedAt, DateTime.utc(2026, 10, 6, 15, 52));
      expect(inbox.takeNext(), isNull);
      inbox.dispose();
    });

    test('a burst keeps only the newest links', () {
      final inbox = ClassDayLinkInbox();
      for (var i = 0; i < ClassDayLinkInbox.maxPending + 3; i++) {
        inbox.enqueue(
          ClassDayLink.mark(occurrenceKey: 'k$i', dayKey: '2026-10-06'),
        );
      }
      final keys = <String?>[];
      for (
        var event = inbox.takeNext();
        event != null;
        event = inbox.takeNext()
      ) {
        keys.add(event.link.occurrenceKey);
      }
      expect(keys, hasLength(ClassDayLinkInbox.maxPending));
      expect(keys.last, 'k${ClassDayLinkInbox.maxPending + 2}');
      inbox.dispose();
    });
  });

  group('board seam', () {
    late ClassDayBoardSeam seam;
    setUp(() => seam = ClassDayBoardSeam());
    tearDown(Clock.reset);

    test('requests wait for the board and are drained once', () async {
      seam.request(_mark('a'));
      seam.request(_open());
      seam.request(_mark('b'));
      expect(seam.pending, hasLength(3));

      final board = _RecordingBoard();
      seam.attach(board);
      // Nothing is handed over inside attach (a board attaches in initState).
      expect(board.calls, isEmpty);
      await _flush();
      expect(board.calls, [
        'show',
        'mark a 2026-10-06',
        'show',
        'show',
        'mark b 2026-10-06',
      ]);
      expect(board.ats, [_tap, _tap], reason: 'the keep is judged by the tap');
      expect(seam.pending, isEmpty);
      expect(seam.debugReceived.map((request) => request.sequence), [1, 2, 3]);

      // Mounting again (a rebuild, a second board) delivers nothing twice.
      seam.attach(board);
      final second = _RecordingBoard();
      seam.attach(second);
      await _flush();
      expect(board.calls, hasLength(5));
      expect(second.calls, isEmpty);
    });

    test(
      'an attached board gets a new request after the current frame',
      () async {
        final board = _RecordingBoard();
        seam.attach(board);
        seam.request(_mark('a'));
        expect(board.calls, isEmpty);
        await _flush();
        expect(board.calls, ['show', 'mark a 2026-10-06']);
      },
    );

    test('a mark-all request reaches markClassesFromLink once', () async {
      final board = _RecordingBoard();
      seam.attach(board);
      seam.request(
        ClassDayBoardRequest.markAll(
          occurrenceKeys: const ['a', 'b', 'c'],
          dayKey: '2026-10-05',
          requestedAt: _tap,
        ),
      );
      await _flush();
      expect(board.calls, ['show', 'mark all a,b,c 2026-10-05']);
      expect(board.ats.single, _tap);
      expect(seam.debugReceived.single.isMarkAll, isTrue);
      expect(seam.debugReceived.single.occurrenceKeys, ['a', 'b', 'c']);
    });

    test(
      'one celebration at a time: the next mark waits for the first to close',
      () async {
        final board = _HoldingBoard();
        seam.attach(board);
        seam.request(_mark('a'));
        seam.request(_mark('b'));
        await _flush();
        expect(board.calls, ['show', 'mark a']);

        board.holds.single.complete(true);
        await _flush();
        expect(board.calls, ['show', 'mark a', 'show', 'mark b']);
        board.holds.last.complete(true);
        await _flush();
        expect(seam.pending, isEmpty);
      },
    );

    test('a board disposed mid-celebration never holds the seam', () async {
      final board = _HoldingBoard();
      seam.attach(board);
      seam.request(_mark('a'));
      await _flush();
      expect(board.calls, ['show', 'mark a']);

      // The page goes away with its celebration's future never completed.
      seam.detach(board);
      seam.request(_mark('b'));
      final next = _RecordingBoard();
      seam.attach(next);
      await _flush();
      expect(next.calls, ['show', 'mark b 2026-10-06']);
      expect(board.calls, ['show', 'mark a'], reason: 'the old loop stopped');

      // The stale future completing late changes nothing.
      board.holds.single.complete(true);
      seam.request(_mark('c'));
      await _flush();
      expect(next.calls.last, 'mark c 2026-10-06');
      expect(board.calls, hasLength(2));
    });

    test(
      'a request that waited over a minute for a board is dropped',
      () async {
        Clock.freeze(DateTime.utc(2026, 10, 6, 15, 52));
        seam.request(_mark('a'));
        Clock.freeze(DateTime.utc(2026, 10, 6, 15, 52, 50));
        seam.request(_mark('b'));
        // A board attaches 90 seconds after the first: that one is dropped.
        Clock.freeze(DateTime.utc(2026, 10, 6, 15, 53, 30));
        final board = _RecordingBoard();
        seam.attach(board);
        await _flush();
        expect(board.calls, ['show', 'mark b 2026-10-06']);
        expect(seam.pending, isEmpty);
      },
    );

    test('a request queued behind a long celebration is not stale', () async {
      Clock.freeze(DateTime.utc(2026, 10, 6, 15, 52));
      final board = _HoldingBoard();
      seam.attach(board);
      seam.request(_mark('a'));
      seam.request(_mark('b'));
      await _flush();
      // The day-tier celebration holds for a tap for three minutes.
      Clock.freeze(DateTime.utc(2026, 10, 6, 15, 55));
      board.holds.single.complete(true);
      await _flush();
      expect(board.calls, ['show', 'mark a', 'show', 'mark b']);
    });

    testWidgets(
      'a board that attaches in initState is handed requests after its frame',
      (tester) async {
        seam.request(_mark('a'));
        final key = GlobalKey<_SeamPageState>();
        await tester.pumpWidget(
          MaterialApp(
            home: _SeamPage(key: key, seam: seam),
          ),
        );
        await tester.pump();
        expect(tester.takeException(), isNull);
        final page = key.currentState!;
        expect(page.calls, ['show', 'mark a']);
        expect(find.text('class day'), findsOneWidget);
      },
    );

    test('a board says whether it keeps from links', () {
      expect(seam.boardMarksClasses.value, isFalse);
      seam.attach(_UnwiredBoard());
      expect(seam.boardMarksClasses.value, isFalse);
      final wired = _WiredBoard();
      seam.attach(wired);
      expect(seam.boardMarksClasses.value, isTrue);
      // A rebuild between boards keeps the widget's controls steady.
      seam.detach(wired);
      expect(seam.boardMarksClasses.value, isTrue);
      seam.debugReset();
      expect(seam.boardMarksClasses.value, isFalse);
    });

    test('the defaults do nothing and report no keep', () async {
      final board = _UnwiredBoard();
      board.showClassDay();
      expect(await board.markClassFromLink('a', '2026-10-06'), isFalse);
      expect(
        await board.markClassesFromLink(['a', 'b'], '2026-10-06', at: _tap),
        isFalse,
      );
      expect(board.marksClassesFromLinks, isFalse);
      seam.attach(board);
      seam.request(_mark('a'));
      await _flush();
      expect(seam.pending, isEmpty);
    });

    test('a board that throws does not stall the queue', () async {
      final errors = <FlutterErrorDetails>[];
      final previous = FlutterError.onError;
      FlutterError.onError = errors.add;
      try {
        final board = _ThrowingBoard();
        seam.attach(board);
        seam.request(_mark('a'));
        seam.request(_mark('b'));
        await _flush();
        expect(board.marked, ['a', 'b']);
        expect(errors, hasLength(2));
      } finally {
        FlutterError.onError = previous;
      }
    });

    test('the app has one seam', () {
      expect(
        identical(ClassDayBoardSeam.instance, ClassDayBoardSeam.instance),
        isTrue,
      );
      ClassDayBoardSeam.instance.request(_open());
      ClassDayBoardSeam.instance.debugReset();
      expect(ClassDayBoardSeam.instance.pending, isEmpty);
      expect(ClassDayBoardSeam.instance.debugReceived, isEmpty);
      expect(ClassDayBoardSeam.instance.hasTarget, isFalse);
    });
  });
}

class _ThrowingBoard with ClassDayLinkTarget {
  final List<String> marked = [];

  @override
  Future<bool> markClassFromLink(
    String occurrenceKey,
    String dayKey, {
    DateTime? at,
  }) async {
    marked.add(occurrenceKey);
    throw StateError('board is not ready');
  }
}

/// A page that attaches in initState and sets state when it is shown the
/// class day, the way the Quests page will.
class _SeamPage extends StatefulWidget {
  const _SeamPage({super.key, required this.seam});

  final ClassDayBoardSeam seam;

  @override
  State<_SeamPage> createState() => _SeamPageState();
}

class _SeamPageState extends State<_SeamPage> with ClassDayLinkTarget {
  final List<String> calls = [];
  bool _classDay = false;

  @override
  void initState() {
    super.initState();
    widget.seam.attach(this);
  }

  @override
  void dispose() {
    widget.seam.detach(this);
    super.dispose();
  }

  @override
  void showClassDay() {
    calls.add('show');
    setState(() => _classDay = true);
  }

  @override
  Future<bool> markClassFromLink(
    String occurrenceKey,
    String dayKey, {
    DateTime? at,
  }) async {
    calls.add('mark $occurrenceKey');
    // The celebration goes into the overlay, outside any build.
    final entry = OverlayEntry(builder: (_) => const SizedBox.shrink());
    Overlay.of(context).insert(entry);
    entry.remove();
    return true;
  }

  @override
  Widget build(BuildContext context) => Text(_classDay ? 'class day' : 'board');
}
