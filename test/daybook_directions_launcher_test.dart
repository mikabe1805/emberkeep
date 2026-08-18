import 'package:emberkeep/daybook/domain/daybook_place.dart';
import 'package:emberkeep/daybook/services/directions_launcher.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('directions URI contracts', () {
    test('directions encode the exact manual destination for both providers', () {
      final place = DaybookPlace(
        savedName: 'George Street stop',
        routingText: '100 George St, New Brunswick, NJ',
      );

      expect(
        DirectionsUris.google(place),
        Uri.parse(
          'https://www.google.com/maps/dir/?api=1&destination=100%20George%20St%2C%20New%20Brunswick%2C%20NJ',
        ),
      );
      expect(
        DirectionsUris.apple(place),
        Uri.parse(
          'https://maps.apple.com/?daddr=100%20George%20St%2C%20New%20Brunswick%2C%20NJ',
        ),
      );
    });

    test('directions include a Google place ID without inventing Apple text', () {
      final place = DaybookPlace(
        savedName: 'Busch Student Center',
        provider: DaybookPlaceProvider.google,
        providerPlaceId: 'ChIJBUSCH CENTER',
      );

      expect(place.hasGoogleDestination, isTrue);
      expect(place.hasAppleDestination, isFalse);
      expect(
        DirectionsUris.google(place),
        Uri.parse(
          'https://www.google.com/maps/dir/?api=1&destination=Busch%20Student%20Center&destination_place_id=ChIJBUSCH%20CENTER',
        ),
      );
    });

    test('directions availability follows person-authored routing text', () {
      final manual = DaybookPlace(
        savedName: 'Alexander Library',
        routingText: '169 College Ave, New Brunswick, NJ',
      );
      final labelOnly = DaybookPlace(savedName: 'Meet by the old oak');

      expect(manual.hasGoogleDestination, isTrue);
      expect(manual.hasAppleDestination, isTrue);
      expect(labelOnly.hasGoogleDestination, isFalse);
      expect(labelOnly.hasAppleDestination, isFalse);
    });
  });
}
