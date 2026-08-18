import 'package:flutter_timezone/flutter_timezone.dart';

Future<String> discoverDeviceTimeZoneId() => FlutterTimezone.getLocalTimezone();
