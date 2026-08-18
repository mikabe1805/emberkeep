enum DaybookPlaceProvider { google }

final class DaybookPlace {
  DaybookPlace({
    required String savedName,
    String? routingText,
    String? building,
    String? room,
    this.provider,
    String? providerPlaceId,
  }) : savedName = _requiredText(savedName, 'savedName'),
       routingText = _optionalText(routingText),
       building = _optionalText(building),
       room = _optionalText(room),
       providerPlaceId = _optionalText(providerPlaceId) {
    if (provider == null && this.providerPlaceId != null) {
      throw ArgumentError(
        'A provider place ID requires a destination provider',
      );
    }
  }

  factory DaybookPlace.fromJson(Map<String, dynamic> json) => DaybookPlace(
    savedName: json['savedName'] as String,
    routingText: json['routingText'] as String?,
    building: json['building'] as String?,
    room: json['room'] as String?,
    provider: _providerFromJson(json['provider']),
    providerPlaceId: json['providerPlaceId'] as String?,
  );

  final String savedName;
  final String? routingText;
  final String? building;
  final String? room;
  final String? providerPlaceId;
  final DaybookPlaceProvider? provider;

  bool get hasGoogleDestination =>
      routingText != null ||
      (provider == DaybookPlaceProvider.google && providerPlaceId != null);
  bool get hasAppleDestination => routingText != null;

  DaybookPlace copyWith({
    String? savedName,
    Object? routingText = _unset,
    Object? building = _unset,
    Object? room = _unset,
    Object? provider = _unset,
    Object? providerPlaceId = _unset,
  }) => DaybookPlace(
    savedName: savedName ?? this.savedName,
    routingText: identical(routingText, _unset)
        ? this.routingText
        : routingText as String?,
    building: identical(building, _unset) ? this.building : building as String?,
    room: identical(room, _unset) ? this.room : room as String?,
    provider: identical(provider, _unset)
        ? this.provider
        : provider as DaybookPlaceProvider?,
    providerPlaceId: identical(providerPlaceId, _unset)
        ? this.providerPlaceId
        : providerPlaceId as String?,
  );

  Map<String, dynamic> toJson() => {
    'savedName': savedName,
    if (routingText != null) 'routingText': routingText,
    if (building != null) 'building': building,
    if (room != null) 'room': room,
    if (provider != null) 'provider': provider!.name,
    if (providerPlaceId != null) 'providerPlaceId': providerPlaceId,
  };
}

const _Unset _unset = _Unset();

final class _Unset {
  const _Unset();
}

DaybookPlaceProvider? _providerFromJson(Object? value) {
  if (value == null) return null;
  return DaybookPlaceProvider.values.byName(value as String);
}

String _requiredText(String value, String name) {
  final clean = value.trim();
  if (clean.isEmpty) {
    throw ArgumentError.value(value, name, 'Must not be blank');
  }
  return clean;
}

String? _optionalText(String? value) {
  final clean = value?.trim();
  return clean == null || clean.isEmpty ? null : clean;
}
