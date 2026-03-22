import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/location_zone.dart';

class LocationManager {
  static const String _key = 'location_zones';

  static Future<List<LocationZone>> getZones() async {
    final prefs = await SharedPreferences.getInstance();
    final String? data = prefs.getString(_key);
    if (data == null || data.isEmpty) return [];

    final List<dynamic> decoded = json.decode(data);
    return decoded.map((e) => LocationZone.fromMap(e)).toList();
  }

  static Future<void> addZone(LocationZone zone) async {
    final zones = await getZones();
    zones.add(zone);
    await _saveZones(zones);
  }

  static Future<void> updateZone(LocationZone updatedZone) async {
    final zones = await getZones();
    final index = zones.indexWhere((zone) => zone.id == updatedZone.id);
    if (index != -1) {
      zones[index] = updatedZone;
      await _saveZones(zones);
    }
  }

  static Future<void> removeZone(String id) async {
    final zones = await getZones();
    zones.removeWhere((zone) => zone.id == id);
    await _saveZones(zones);
  }

  static Future<void> _saveZones(List<LocationZone> zones) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = json.encode(zones.map((e) => e.toMap()).toList());
    await prefs.setString(_key, encoded);
  }
}
