import 'package:flutter_test/flutter_test.dart';
import 'package:plezy/services/htpc_mode.dart';
import 'package:plezy/services/settings_service.dart';
import 'package:plezy/utils/platform_detector.dart';

import '../test_helpers/prefs.dart';

void main() {
  group('power commands', () {
    test('quit is Plezy alone on both systems', () {
      expect(HtpcPower.commandFor(HtpcPowerAction.quit, windows: true), isNull);
      expect(HtpcPower.commandFor(HtpcPowerAction.quit, windows: false), isNull);
    });

    test('Windows shuts down and restarts immediately', () {
      expect(HtpcPower.commandFor(HtpcPowerAction.shutdown, windows: true), ['shutdown', '/s', '/t', '0']);
      expect(HtpcPower.commandFor(HtpcPowerAction.restart, windows: true), ['shutdown', '/r', '/t', '0']);
    });

    test('Windows sleep suspends rather than hibernating', () {
      final command = HtpcPower.commandFor(HtpcPowerAction.sleep, windows: true)!;
      expect(command.last, contains("SetSuspendState('Suspend'"));
      expect(command.join(' '), isNot(contains('rundll32')));
    });

    test('Linux goes through systemd', () {
      expect(HtpcPower.commandFor(HtpcPowerAction.shutdown, windows: false), ['systemctl', 'poweroff']);
      expect(HtpcPower.commandFor(HtpcPowerAction.restart, windows: false), ['systemctl', 'reboot']);
      expect(HtpcPower.commandFor(HtpcPowerAction.sleep, windows: false), ['systemctl', 'suspend']);
    });
  });

  group('HTPC view', () {
    late SettingsService settings;

    setUp(() async {
      resetSharedPreferencesForTest();
      SettingsService.resetForTesting();
      settings = await SettingsService.getInstance();
    });

    tearDown(() => PlatformDetector.debugSetIsDesktopOSOverride(null));

    test('the desktop view is the default', () {
      PlatformDetector.debugSetIsDesktopOSOverride(true);

      expect(HtpcMode.isActive, isFalse);
      expect(HtpcMode.forcesTvLayout(settings), isFalse);
      expect(HtpcMode.startsFullscreen(settings), isFalse);
    });

    test('the HTPC view brings the TV layout and fullscreen', () async {
      PlatformDetector.debugSetIsDesktopOSOverride(true);
      await settings.write(SettingsService.htpcMode, true);

      expect(HtpcMode.isActive, isTrue);
      expect(HtpcMode.forcesTvLayout(settings), isTrue);
      expect(HtpcMode.startsFullscreen(settings), isTrue);
    });

    test('a stored HTPC view does nothing off the desktop', () async {
      PlatformDetector.debugSetIsDesktopOSOverride(false);
      await settings.write(SettingsService.htpcMode, true);

      expect(HtpcMode.isActive, isFalse);
      expect(HtpcMode.forcesTvLayout(settings), isFalse);
    });

    test('Force TV mode still works on its own', () async {
      PlatformDetector.debugSetIsDesktopOSOverride(false);
      await settings.write(SettingsService.forceTvMode, true);

      expect(HtpcMode.forcesTvLayout(settings), isTrue);
    });
  });
}
