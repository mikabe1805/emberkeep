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
    required DaybookPlaceDestinationIntent destinationIntent,
  }) => CampusPlace(
    label: source.savedName,
    building: source.building,
    room: source.room,
    address: source.routingText,
    latitude: destinationIntent == DaybookPlaceDestinationIntent.preserve
        ? original.latitude
        : null,
    longitude: destinationIntent == DaybookPlaceDestinationIntent.preserve
        ? original.longitude
        : null,
    mapsProvider: switch (destinationIntent) {
      DaybookPlaceDestinationIntent.preserve =>
        source.provider?.name ?? original.mapsProvider,
      DaybookPlaceDestinationIntent.googleSelection =>
        DaybookPlaceProvider.google.name,
      DaybookPlaceDestinationIntent.manualReplacement => null,
    },
    placeId: switch (destinationIntent) {
      DaybookPlaceDestinationIntent.preserve =>
        source.provider == null ? original.placeId : source.providerPlaceId,
      DaybookPlaceDestinationIntent.googleSelection => source.providerPlaceId,
      DaybookPlaceDestinationIntent.manualReplacement => null,
    },
    campusCode: destinationIntent == DaybookPlaceDestinationIntent.preserve
        ? original.campusCode
        : null,
  );
}
