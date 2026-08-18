import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

import '../domain/daybook_place.dart';

enum MapProvider { apple, google }

abstract interface class DirectionsLauncher {
  Future<bool> open(DaybookPlace place, MapProvider provider);
}

abstract final class DirectionsUris {
  static Uri google(DaybookPlace place) {
    if (!place.hasGoogleDestination) {
      throw ArgumentError.value(place, 'place', 'No Google destination');
    }
    return _percentEncodedSpaces(
      Uri.https('www.google.com', '/maps/dir/', {
        'api': '1',
        'destination': place.routingText ?? place.savedName,
        if (place.provider == DaybookPlaceProvider.google &&
            place.providerPlaceId != null)
          'destination_place_id': place.providerPlaceId!,
      }),
    );
  }

  static Uri apple(DaybookPlace place) {
    if (!place.hasAppleDestination) {
      throw ArgumentError.value(place, 'place', 'No Apple destination');
    }
    return _percentEncodedSpaces(
      Uri.https('maps.apple.com', '/', {'daddr': place.routingText!}),
    );
  }

  static Uri _percentEncodedSpaces(Uri uri) =>
      Uri.parse(uri.toString().replaceAll('+', '%20'));
}

final class ExternalDirectionsLauncher implements DirectionsLauncher {
  const ExternalDirectionsLauncher();

  @override
  Future<bool> open(DaybookPlace place, MapProvider provider) async {
    final uri = switch (provider) {
      MapProvider.apple => DirectionsUris.apple(place),
      MapProvider.google => DirectionsUris.google(place),
    };
    try {
      return await launchUrl(
        uri,
        mode: kIsWeb
            ? LaunchMode.platformDefault
            : LaunchMode.externalApplication,
      );
    } catch (_) {
      return false;
    }
  }
}
