import 'package:emberkeep/academic_calendar/domain/academic_schedule.dart';
import 'package:emberkeep/daybook/domain/daybook_place.dart';

abstract final class CampusPlaceDaybookAdapter {
  static DaybookPlace fromCampusPlace(CampusPlace source) => DaybookPlace(
    savedName: source.label,
    routingText: source.address,
    building: source.building,
    room: source.room,
    provider: source.mapsProvider == DaybookPlaceProvider.google.name
        ? DaybookPlaceProvider.google
        : null,
    providerPlaceId: source.mapsProvider == DaybookPlaceProvider.google.name
        ? source.placeId
        : null,
  );

  static CampusPlace toCampusPlace(
    DaybookPlace source, {
    required CampusPlace original,
  }) => CampusPlace(
    label: source.savedName,
    building: source.building,
    room: source.room,
    address: source.routingText,
    latitude: original.latitude,
    longitude: original.longitude,
    mapsProvider: source.provider?.name,
    placeId: source.providerPlaceId,
    campusCode: original.campusCode,
  );
}
