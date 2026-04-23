import 'package:flutter/material.dart';
import 'package:signals/signals_flutter.dart';

import '../controllers/device_session.dart';
import '../controllers/display_mirror_controller.dart';
import '../controllers/interaction_controller.dart';
import '../controllers/recording_controller.dart';
import '../services/adb_service.dart';
import '../widgets/device_panel.dart';
import '../widgets/interaction_overlay.dart';
import '../widgets/mirror_view.dart';
import '../widgets/status_bar.dart';
import 'theme.dart';

/// The root application widget.
///
/// Sets up the Material app with the dark theme and provides all controllers
/// to the widget tree via [AppScope].
class App extends StatelessWidget {
  final AdbService adbService;
  final DeviceSession deviceSession;
  final DisplayMirrorController mirrorController;
  final InteractionController interactionController;
  final RecordingController recordingController;

  const App({
    super.key,
    required this.adbService,
    required this.deviceSession,
    required this.mirrorController,
    required this.interactionController,
    required this.recordingController,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ADB Display Tester',
      theme: AppTheme.darkTheme,
      debugShowCheckedModeBanner: false,
      home: AppScope(
        adbService: adbService,
        deviceSession: deviceSession,
        mirrorController: mirrorController,
        interactionController: interactionController,
        recordingController: recordingController,
        child: const HomePage(),
      ),
    );
  }
}

/// InheritedWidget that provides all controllers down the widget tree.
class AppScope extends InheritedWidget {
  final AdbService adbService;
  final DeviceSession deviceSession;
  final DisplayMirrorController mirrorController;
  final InteractionController interactionController;
  final RecordingController recordingController;

  const AppScope({
    super.key,
    required this.adbService,
    required this.deviceSession,
    required this.mirrorController,
    required this.interactionController,
    required this.recordingController,
    required super.child,
  });

  static AppScope of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<AppScope>()!;
  }

  @override
  bool updateShouldNotify(AppScope oldWidget) => false;
}

/// The main home page layout with sidebar, mirror view, and status bar.
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);

    return Scaffold(
      body: Column(
        children: [
          // ── Top bar ──
          _buildTopBar(context, scope),
          const Divider(height: 1),

          // ── Main content ──
          Expanded(
            child: Row(
              children: [
                // Left sidebar
                SizedBox(
                  width: 280,
                  child: DevicePanel(
                    deviceSession: scope.deviceSession,
                    mirrorController: scope.mirrorController,
                    recordingController: scope.recordingController,
                    adbService: scope.adbService,
                  ),
                ),
                VerticalDivider(
                  width: 1,
                  color: Colors.white.withValues(alpha: 0.06),
                ),

                // Mirror view with interaction overlay
                Expanded(
                  child: Watch((context) {
                    final hasDisplay =
                        scope.deviceSession.hasDisplay.value;

                    if (!hasDisplay) {
                      return _buildPlaceholder(context);
                    }

                    return Stack(
                      fit: StackFit.expand,
                      children: [
                        MirrorView(
                          mirrorController: scope.mirrorController,
                        ),
                        InteractionOverlay(
                          deviceSession: scope.deviceSession,
                          mirrorController: scope.mirrorController,
                          interactionController:
                              scope.interactionController,
                          recordingController: scope.recordingController,
                        ),
                      ],
                    );
                  }),
                ),
              ],
            ),
          ),

          // ── Status bar ──
          const Divider(height: 1),
          StatusBar(
            deviceSession: scope.deviceSession,
            mirrorController: scope.mirrorController,
            recordingController: scope.recordingController,
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar(BuildContext context, AppScope scope) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      color: const Color(0xFF0D1117),
      child: Row(
        children: [
          Icon(
            Icons.phonelink,
            color: Theme.of(context).colorScheme.primary,
            size: 20,
          ),
          const SizedBox(width: 10),
          const Text(
            'ADB Display Tester',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.2,
            ),
          ),
          const Spacer(),
          Watch((context) {
            final valid = scope.deviceSession.adbValid.value;
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: valid
                        ? const Color(0xFF3FB950)
                        : const Color(0xFFF85149),
                    boxShadow: [
                      BoxShadow(
                        color: (valid
                                ? const Color(0xFF3FB950)
                                : const Color(0xFFF85149))
                            .withValues(alpha: 0.4),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  valid ? 'ADB Connected' : 'ADB Not Found',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.5),
                  ),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildPlaceholder(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.screenshot_monitor_outlined,
            size: 64,
            color: Colors.white.withValues(alpha: 0.1),
          ),
          const SizedBox(height: 16),
          Text(
            'Select a device and display to start mirroring',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withValues(alpha: 0.3),
            ),
          ),
        ],
      ),
    );
  }
}
