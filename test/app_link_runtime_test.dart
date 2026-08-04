import 'package:emberkeep/main.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('root app consumes a warm native room link before Navigator', (
    tester,
  ) async {
    await tester.pumpWidget(const LifeRpgApp());
    await tester.pump();

    final ByteData message = const JSONMethodCodec().encodeMethodCall(
      const MethodCall('pushRouteInformation', <String, dynamic>{
        'location': 'https://roomofdays.com/space/ABC234',
        'state': null,
      }),
    );
    final result = (await tester.binding.defaultBinaryMessenger
        .handlePlatformMessage('flutter/navigation', message, (_) {}))!;

    expect(const JSONMethodCodec().decodeEnvelope(result), isTrue);

    // The room is queued until storage/cloud startup settles; dispose now so
    // this routing test stays independent of any live Firebase response.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
