import 'dart:io';

import '../utils/app_logger.dart';
import '../utils/platform_detector.dart';
import 'app_exit_service.dart';
import 'settings_service.dart';

/// Desktop run as a living-room HTPC, the way Plex HTPC runs next to it.
///
/// One switch rather than three because the parts only make sense together:
/// the TV layout is what a remote or gamepad can drive, fullscreen is what a
/// TV shows, and once the window cannot be left through Escape the root Back
/// needs somewhere to go - the exit menu ([HtpcPowerAction]).
abstract final class HtpcMode {
  /// Whether the running app is in HTPC mode. Desktop only.
  static bool get isActive =>
      PlatformDetector.isDesktopOS() && (SettingsService.instanceOrNull?.read(SettingsService.htpcMode) ?? false);

  /// The TV layout override: the user's own "Force TV mode", or HTPC mode.
  static bool forcesTvLayout(SettingsService settings) =>
      settings.read(SettingsService.forceTvMode) ||
      (PlatformDetector.isDesktopOS() && settings.read(SettingsService.htpcMode));

  /// Whether the window opens fullscreen.
  static bool startsFullscreen(SettingsService settings) =>
      PlatformDetector.isDesktopOS() &&
      (settings.read(SettingsService.startInFullscreen) || settings.read(SettingsService.htpcMode));
}

/// The choices of the HTPC exit menu, in the order Plex HTPC lists them.
enum HtpcPowerAction { quit, shutdown, restart, sleep }

/// Carries out an [HtpcPowerAction] on Windows or Linux.
abstract final class HtpcPower {
  /// The system command for [action], or null for [HtpcPowerAction.quit],
  /// which only closes Plezy.
  ///
  /// Windows sleep goes through `SetSuspendState('Suspend')` rather than the
  /// usual `rundll32 powrprof.dll,SetSuspendState` one-liner: that one
  /// hibernates instead whenever hibernation is enabled.
  static List<String>? commandFor(HtpcPowerAction action, {required bool windows}) {
    if (windows) {
      return switch (action) {
        HtpcPowerAction.quit => null,
        HtpcPowerAction.shutdown => const ['shutdown', '/s', '/t', '0'],
        HtpcPowerAction.restart => const ['shutdown', '/r', '/t', '0'],
        HtpcPowerAction.sleep => const [
          'powershell',
          '-NoProfile',
          '-NonInteractive',
          '-Command',
          r"Add-Type -AssemblyName System.Windows.Forms; [void][System.Windows.Forms.Application]::SetSuspendState('Suspend', $false, $false)",
        ],
      };
    }
    return switch (action) {
      HtpcPowerAction.quit => null,
      HtpcPowerAction.shutdown => const ['systemctl', 'poweroff'],
      HtpcPowerAction.restart => const ['systemctl', 'reboot'],
      HtpcPowerAction.sleep => const ['systemctl', 'suspend'],
    };
  }

  /// Runs [action]. Shutdown and restart also close Plezy cleanly instead of
  /// leaving it to be killed when the session ends; sleep keeps it running so
  /// it is where the viewer left it on wake.
  static Future<void> perform(HtpcPowerAction action) async {
    final command = commandFor(action, windows: Platform.isWindows);
    if (command != null) {
      try {
        await Process.start(command.first, command.sublist(1), mode: ProcessStartMode.detached);
      } catch (e, st) {
        appLogger.e('HTPC power action ${action.name} failed', error: e, stackTrace: st);
        return;
      }
    }
    if (action == HtpcPowerAction.quit || action == HtpcPowerAction.shutdown || action == HtpcPowerAction.restart) {
      await AppExitService.requestGracefulExit();
    }
  }
}
