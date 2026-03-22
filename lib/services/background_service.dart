import 'dart:async';
import 'dart:ui';

import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sound_mode/sound_mode.dart';
import 'package:sound_mode/utils/ringer_mode_statuses.dart';

import 'location_manager.dart';

Future<void> initializeBackgroundService() async {
  final service = FlutterBackgroundService();

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: true,
      isForegroundMode: true,
      initialNotificationTitle: 'Location Ringer',
      initialNotificationContent: 'Running in background',
      foregroundServiceNotificationId: 888,
      foregroundServiceTypes: [AndroidForegroundType.location],
    ),
    iosConfiguration: IosConfiguration(
      autoStart: true,
      onForeground: onStart,
    ),
  );

  await service.startService();
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  Timer.periodic(const Duration(seconds: 30), (timer) async {
    // Check if service is still running
    if (service is AndroidServiceInstance) {
      if (!(await service.isForegroundService())) {
        return;
      }
    }

    try {
      // 1. Fetch target zones
      final zones = await LocationManager.getZones();
      bool isInsideZone = false;

      // 2. Determine location only if required
      if (zones.isNotEmpty) {
        Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );

        for (var zone in zones) {
          double distanceInMeters = Geolocator.distanceBetween(
            position.latitude,
            position.longitude,
            zone.latitude,
            zone.longitude,
          );

          if (distanceInMeters <= zone.radiusInMeters) {
            isInsideZone = true;
            break;
          }
        }
      }

      // 3. Change ringer mode if needed
      RingerModeStatus currentMode = await SoundMode.ringerModeStatus;

      if (isInsideZone) {
        if (currentMode != RingerModeStatus.silent) {
          await SoundMode.setSoundMode(RingerModeStatus.silent);
        }
      } else {
        if (currentMode == RingerModeStatus.silent) {
          await SoundMode.setSoundMode(RingerModeStatus.normal);
        }
      }
    } catch (e) {
      // Print errors or logs (in a real app, maybe log to a file)
      print("Background location check error: $e");
    }
  });
}
