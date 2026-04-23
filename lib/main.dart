import 'package:flutter/material.dart';

import 'app/app.dart';
import 'controllers/device_session.dart';
import 'controllers/display_mirror_controller.dart';
import 'controllers/interaction_controller.dart';
import 'controllers/recording_controller.dart';
import 'services/adb_service.dart';

void main() {
  final adbService = AdbService();
  final deviceSession = DeviceSession(adbService);
  final mirrorController = DisplayMirrorController(adbService);
  final interactionController = InteractionController(adbService);
  final recordingController = RecordingController();

  // Validate ADB and refresh devices on startup
  deviceSession.validateAdb().then((_) {
    if (deviceSession.adbValid.value) {
      deviceSession.refreshDevices();
    }
  });

  runApp(App(
    adbService: adbService,
    deviceSession: deviceSession,
    mirrorController: mirrorController,
    interactionController: interactionController,
    recordingController: recordingController,
  ));
}
