import 'dart:async';
import 'dart:ui' show Tristate;

import 'package:emberkeep/cloud.dart';
import 'package:emberkeep/engine.dart';
import 'package:emberkeep/screens/me.dart';
import 'package:emberkeep/daybook/services/place_search_identity_removal.dart';
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
  Future<String?> Function()? withdrawPlaceSearch,
  bool placeSearchEnabled = false,
  bool supportsPrivateServiceIdentityRemoval = true,
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
        onWithdrawPlaceSearchConsent: withdrawPlaceSearch,
        placeSearchEnabled: placeSearchEnabled,
        supportsPrivateServiceIdentityRemoval:
            supportsPrivateServiceIdentityRemoval,
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
    'enabled consent withdrawal is available to linked and backup identities',
    (tester) async {
      for (final account in <CloudAccountView>[
        _FakeCloudAccountView(
          accountEmail: 'keeper@example.com',
          ready: true,
          optedIn: true,
          canDeleteAnonymousServiceIdentity: false,
        ),
        _FakeCloudAccountView(
          ready: true,
          optedIn: true,
          canDeleteAnonymousServiceIdentity: false,
        ),
      ]) {
        var withdrawals = 0;
        await tester.pumpWidget(
          _page(
            account: account,
            removeIdentity: () async => null,
            withdrawPlaceSearch: () async {
              withdrawals += 1;
              return null;
            },
            placeSearchEnabled: true,
          ),
        );
        final control = find.byKey(
          const ValueKey('withdraw-place-search-consent'),
        );
        await tester.scrollUntilVisible(
          control,
          360,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.drag(find.byType(Scrollable).first, const Offset(0, -220));
        await tester.pumpAndSettle();
        expect(control, findsOneWidget);
        expect(tester.getSize(control).height, greaterThanOrEqualTo(44));
        await tester.tap(control);
        await tester.pumpAndSettle();
        expect(withdrawals, 1);
        expect(
          find.textContaining('Future place searches are off'),
          findsOneWidget,
        );
      }
    },
  );

  testWidgets('default-off build hides consent withdrawal', (tester) async {
    await tester.pumpWidget(
      _page(
        account: _FakeCloudAccountView(),
        removeIdentity: () async => null,
        withdrawPlaceSearch: () async => null,
      ),
    );
    expect(
      find.byKey(const ValueKey('withdraw-place-search-consent')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('remove-private-service-identity')),
      findsNothing,
    );
  });

  testWidgets(
    'private identity control is visible only for anonymous backup-off service state',
    (tester) async {
      final anonymous = _FakeCloudAccountView();
      await tester.pumpWidget(
        _page(
          account: anonymous,
          removeIdentity: () async => null,
          placeSearchEnabled: true,
        ),
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
        _page(
          account: linked,
          removeIdentity: () async => null,
          placeSearchEnabled: true,
        ),
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
        _page(
          account: backup,
          removeIdentity: () async => null,
          placeSearchEnabled: true,
        ),
      );
      await tester.pump();
      expect(
        find.byKey(const ValueKey('remove-private-service-identity')),
        findsNothing,
      );
    },
  );

  testWidgets(
    'web capability hides identity removal but keeps consent withdrawal',
    (tester) async {
      await tester.pumpWidget(
        _page(
          account: _FakeCloudAccountView(),
          removeIdentity: () async => null,
          withdrawPlaceSearch: () async => null,
          placeSearchEnabled: true,
          supportsPrivateServiceIdentityRemoval: false,
        ),
      );

      expect(
        find.byKey(const ValueKey('remove-private-service-identity')),
        findsNothing,
      );
      final withdrawal = find.byKey(
        const ValueKey('withdraw-place-search-consent'),
      );
      await tester.scrollUntilVisible(
        withdrawal,
        360,
        scrollable: find.byType(Scrollable).first,
      );
      expect(withdrawal, findsOneWidget);
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
        placeSearchEnabled: true,
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
    expect(find.textContaining('owner-only server lookup'), findsOneWidget);
    expect(
      find.textContaining('identity stays so you can retry'),
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
        placeSearchEnabled: true,
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

  testWidgets(
    'destructive work cannot be dismissed and errors use a live region',
    (tester) async {
      final gate = Completer<String?>();
      await tester.pumpWidget(
        _page(
          account: _FakeCloudAccountView(),
          removeIdentity: () => gate.future,
          placeSearchEnabled: true,
        ),
      );
      await _showRemovalControl(tester);
      await tester.tap(
        find.byKey(const ValueKey('remove-private-service-identity')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('REMOVE IDENTITY'));
      await tester.pump();

      await tester.tapAt(const Offset(2, 2));
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(find.text('Remove private service identity?'), findsOneWidget);

      gate.complete('Remote deletion failed.');
      await tester.pumpAndSettle();
      final error = find.byKey(
        const ValueKey('remove-private-service-identity-error'),
      );
      expect(error, findsOneWidget);
      expect(tester.getSemantics(error).flagsCollection.isLiveRegion, isTrue);
    },
  );

  testWidgets('unsettled Auth deletion disables same-session retry', (
    tester,
  ) async {
    var calls = 0;
    await tester.pumpWidget(
      _page(
        account: _FakeCloudAccountView(),
        removeIdentity: () async {
          calls++;
          return identityRemovalStillFinishingMessage;
        },
        placeSearchEnabled: true,
      ),
    );
    await _showRemovalControl(tester);
    await tester.tap(
      find.byKey(const ValueKey('remove-private-service-identity')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('REMOVE IDENTITY'));
    await tester.pumpAndSettle();

    expect(find.text(identityRemovalStillFinishingMessage), findsOneWidget);
    final confirm = tester.widget<FilledButton>(
      find.byKey(const ValueKey('confirm-remove-private-service-identity')),
    );
    expect(confirm.onPressed, isNull);
    expect(find.text('REOPEN APP TO CHECK'), findsOneWidget);
    final close = find.byKey(
      const ValueKey('close-private-service-identity-timeout'),
    );
    expect(close, findsOneWidget);
    expect(tester.getSize(close).height, greaterThanOrEqualTo(44));
    final closeSemantics = tester.getSemantics(close).flagsCollection;
    expect(closeSemantics.isButton, isTrue);
    expect(closeSemantics.isEnabled, Tristate.isTrue);

    await tester.tap(close);
    await tester.pumpAndSettle();
    expect(find.text('Remove private service identity?'), findsNothing);
    expect(calls, 1);

    await _showRemovalControl(tester);
    await tester.tap(
      find.byKey(const ValueKey('remove-private-service-identity')),
    );
    await tester.pumpAndSettle();
    expect(calls, 1);
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
