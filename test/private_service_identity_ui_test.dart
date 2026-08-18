import 'package:emberkeep/cloud.dart';
import 'package:emberkeep/engine.dart';
import 'package:emberkeep/screens/me.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

final class _FakeCloudAccountView extends ChangeNotifier
    implements CloudAccountView {
  _FakeCloudAccountView({
    this.accountEmail,
    this.ready = false,
    this.optedIn = false,
    this.canDeleteAnonymousServiceIdentity = true,
  });

  @override
  String? accountEmail;

  @override
  bool ready;

  @override
  bool available = true;

  @override
  bool optedIn;

  @override
  bool socialReady = true;

  @override
  bool canDeleteAnonymousServiceIdentity;

  void markDeleted() {
    socialReady = false;
    canDeleteAnonymousServiceIdentity = false;
    notifyListeners();
  }
}

Widget _page({
  required CloudAccountView account,
  required Future<String?> Function() removeIdentity,
}) {
  final state = GameState()..reduceMotion = true;
  return MaterialApp(
    home: Scaffold(
      body: MePage(
        state: state,
        quests: const [],
        onPersist: () {},
        onPublishRoom: (_, {required code}) async =>
            RoomPublishResult.success(code),
        onAddQuest: (_) => true,
        onExport: () async => true,
        onImport: (_) async => true,
        onReset: () async => null,
        onNotifyChanged: () async {},
        onEnableCloud: () async => null,
        onLinkAccount: (_, _) async => null,
        onSignIn: (_, _) async => null,
        onSignOut: () async {},
        onDeleteAccount: (_) async => null,
        onRemovePrivateServiceIdentity: removeIdentity,
        cloudAccountView: account,
      ),
    ),
  );
}

Future<void> _showRemovalControl(WidgetTester tester) async {
  final control = find.byKey(const ValueKey('remove-private-service-identity'));
  await tester.scrollUntilVisible(
    control,
    360,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pump();
  expect(control, findsOneWidget);
}

void main() {
  testWidgets(
    'private identity control is visible only for anonymous backup-off service state',
    (tester) async {
      final anonymous = _FakeCloudAccountView();
      await tester.pumpWidget(
        _page(account: anonymous, removeIdentity: () async => null),
      );
      await _showRemovalControl(tester);
      expect(find.text('YOUR ACCOUNT'), findsOneWidget);

      final linked = _FakeCloudAccountView(
        accountEmail: 'keeper@example.com',
        ready: true,
        optedIn: true,
        canDeleteAnonymousServiceIdentity: false,
      );
      await tester.pumpWidget(
        _page(account: linked, removeIdentity: () async => null),
      );
      await tester.pump();
      expect(
        find.byKey(const ValueKey('remove-private-service-identity')),
        findsNothing,
      );

      final backup = _FakeCloudAccountView(
        ready: true,
        optedIn: true,
        canDeleteAnonymousServiceIdentity: false,
      );
      await tester.pumpWidget(
        _page(account: backup, removeIdentity: () async => null),
      );
      await tester.pump();
      expect(
        find.byKey(const ValueKey('remove-private-service-identity')),
        findsNothing,
      );
    },
  );

  testWidgets('removal requires confirmation and cancel does nothing', (
    tester,
  ) async {
    final account = _FakeCloudAccountView();
    var calls = 0;
    await tester.pumpWidget(
      _page(
        account: account,
        removeIdentity: () async {
          calls++;
          return null;
        },
      ),
    );
    await _showRemovalControl(tester);

    await tester.tap(
      find.byKey(const ValueKey('remove-private-service-identity')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Remove private service identity?'), findsOneWidget);
    expect(
      find.textContaining('Daybook, progress, and saved locations stay'),
      findsOneWidget,
    );

    await tester.tap(find.text('KEEP IDENTITY'));
    await tester.pumpAndSettle();
    expect(calls, 0);
    expect(find.text('Remove private service identity?'), findsNothing);
  });

  testWidgets('failure stays retryable and success reports device data kept', (
    tester,
  ) async {
    final account = _FakeCloudAccountView();
    var calls = 0;
    await tester.pumpWidget(
      _page(
        account: account,
        removeIdentity: () async {
          calls++;
          if (calls == 1) return 'Couldn’t reach the private service.';
          account.markDeleted();
          return null;
        },
      ),
    );
    await _showRemovalControl(tester);
    await tester.tap(
      find.byKey(const ValueKey('remove-private-service-identity')),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('REMOVE IDENTITY'));
    await tester.pumpAndSettle();
    expect(calls, 1);
    expect(find.text('Couldn’t reach the private service.'), findsOneWidget);
    expect(find.text('Remove private service identity?'), findsOneWidget);

    await tester.tap(find.text('REMOVE IDENTITY'));
    await tester.pumpAndSettle();
    expect(calls, 2);
    expect(find.text('Remove private service identity?'), findsNothing);
    expect(
      find.textContaining('On-device Daybook and progress were kept'),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('remove-private-service-identity')),
      findsNothing,
    );
  });

  testWidgets('removal remains reachable at 320x568 and 200% text', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    await tester.binding.setSurfaceSize(const Size(320, 568));
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.binding.setSurfaceSize(null);
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: PrivateServiceIdentityControl(action: () async => null),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    final control = find.byKey(
      const ValueKey('remove-private-service-identity'),
    );
    expect(tester.getSize(control).height, greaterThanOrEqualTo(44));
    expect(tester.takeException(), isNull);

    await tester.tap(control);
    await tester.pumpAndSettle();
    expect(find.text('Remove private service identity?'), findsOneWidget);
    final confirm = find.byKey(
      const ValueKey('confirm-remove-private-service-identity'),
    );
    await tester.scrollUntilVisible(
      confirm,
      120,
      scrollable: find.descendant(
        of: find.byType(Dialog),
        matching: find.byType(Scrollable),
      ),
    );
    expect(tester.getSize(confirm).height, greaterThanOrEqualTo(44));
    expect(tester.takeException(), isNull);
  });
}
