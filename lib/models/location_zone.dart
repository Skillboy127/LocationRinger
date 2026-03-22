import 'dart:convert';

class LocationZone {
  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final double radiusInMeters;
  final String targetMode;

  LocationZone({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    this.radiusInMeters = 100.0,
    this.targetMode = 'vibrate',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'latitude': latitude,
      'longitude': longitude,
      'radiusInMeters': radiusInMeters,
      'targetMode': targetMode,
    };
  }

  factory LocationZone.fromMap(Map<String, dynamic> map) {
    return LocationZone(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      latitude: map['latitude']?.toDouble() ?? 0.0,
      longitude: map['longitude']?.toDouble() ?? 0.0,
      radiusInMeters: map['radiusInMeters']?.toDouble() ?? 100.0,
      targetMode: map['targetMode'] ?? 'vibrate',
    );
  }

  String toJson() => json.encode(toMap());

  factory LocationZone.fromJson(String source) => LocationZone.fromMap(json.decode(source));
}
