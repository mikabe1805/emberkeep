import 'package:emberkeep/class_day_links.dart';
import 'package:emberkeep/clock.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

class _RecordingBoard with ClassDayLinkTarget {
  final List<String> calls = [];

  @override
  void showClassDay() => calls.add('show');

  @override
  Future<bool> markClassFromLink(String occurrenceKey, String dayKey) async {
    calls.add('mark $occurrenceKey $dayKey');
    await Future<void>.delayed(Duration.zero);
    return true;
  }
}

/// A board that has not wired the class day yet: only the defaults.
class _UnwiredBoard with ClassDayLinkTarget {}

ClassDayBoardRequest _mark(String key, [String day = '2026-10-06']) =>
    ClassDayBoardRequest.mark(
      occurrenceKey: key,
      dayKey: day,
      requestedAt: DateTime.utc(2026, 10, 6, 15, 52),
    );

ClassDayBoardRequest _open() =>
    ClassDayBoardRequest.open(requestedAt: DateTime.utc(2026, 10, 6, 15, 52));

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

    test('requests wait for the board and are drained once', () async {
      seam.request(_mark('a'));
      seam.request(_open());
      seam.request(_mark('b'));
      expect(seam.pending, hasLength(3));

      final board = _RecordingBoard();
      seam.attach(board);
      await _flush();
      expect(board.calls, [
        'show',
        'mark a 2026-10-06',
        'show',
        'show',
        'mark b 2026-10-06',
      ]);
      expect(seam.pending, isEmpty);

      // Mounting again (a rebuild, a second board) delivers nothing twice.
      seam.attach(board);
      final second = _RecordingBoard();
      seam.attach(second);
      await _flush();
      expect(board.calls, hasLength(5));
      expect(second.calls, isEmpty);
    });

    test('an attached board gets a new request at once', () async {
      final board = _RecordingBoard();
      seam.attach(board);
      seam.request(_mark('a'));
      await _flush();
      expect(board.calls, ['show', 'mark a 2026-10-06']);
    });

    test('a mark that arrives mid-celebration waits its turn', () async {
      final board = _RecordingBoard();
      seam.attach(board);
      seam.request(_mark('a'));
      seam.request(_mark('b'));
      await _flush();
      expect(board.calls, [
        'show',
        'mark a 2026-10-06',
        'show',
        'mark b 2026-10-06',
      ]);
    });

    test('a detached board leaves requests for the next one', () async {
      final board = _RecordingBoard();
      seam.attach(board);
      seam.detach(board);
      seam.request(_mark('a'));
      await _flush();
      expect(board.calls, isEmpty);
      expect(seam.pending.single.occurrenceKey, 'a');
      // Detaching someone else's board changes nothing.
      final next = _RecordingBoard();
      seam.attach(next);
      seam.detach(board);
      await _flush();
      expect(next.calls, ['show', 'mark a 2026-10-06']);
      expect(seam.pending, isEmpty);
    });

    test('the defaults do nothing and report no keep', () async {
      final board = _UnwiredBoard();
      board.showClassDay();
      expect(await board.markClassFromLink('a', '2026-10-06'), isFalse);
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
      expect(ClassDayBoardSeam.instance.hasTarget, isFalse);
    });
  });
}

class _ThrowingBoard with ClassDayLinkTarget {
  final List<String> marked = [];

  @override
  Future<bool> markClassFromLink(String occurrenceKey, String dayKey) async {
    marked.add(occurrenceKey);
    throw StateError('board is not ready');
  }
}
