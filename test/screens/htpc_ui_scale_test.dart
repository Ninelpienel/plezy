import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plezy/i18n/strings.g.dart';
import 'package:plezy/main.dart' as app;
import 'package:plezy/services/settings_service.dart';
import 'package:plezy/utils/platform_detector.dart';

import '../test_helpers/prefs.dart';
import '../test_helpers/theme.dart';

/// The HTPC view lays the TV layout out on the same 540-high logical surface
/// an Android TV box uses, so the sidebar, cards and text cover the same share
/// of the screen on a PC as on the Shield, whatever the Windows scaling.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() => LocaleSettings.setLocaleSync(AppLocale.en));

  setUp(() async {
    resetSharedPreferencesForTest();
    SettingsService.resetForTesting();
    TvDetectionService.debugSetAppleTVOverride(false);
    TvDetectionService.debugSetAutomotiveOverride(false);
    PlatformDetector.debugSetIsDesktopOSOverride(true);
    await SettingsService.getInstance();
  });

  tearDown(() {
    TvDetectionService.debugSetAppleTVOverride(null);
    TvDetectionService.debugSetAutomotiveOverride(null);
    PlatformDetector.debugSetIsDesktopOSOverride(null);
    SettingsService.resetForTesting();
  });

  Future<Size> pumpShell(WidgetTester tester, {required Size physical, required double dpr}) async {
    tester.view.physicalSize = physical;
    tester.view.devicePixelRatio = dpr;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    late Size seen;
    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(
          theme: ThemeData(extensions: const [testMonoTokens]),
          home: Builder(
            builder: (context) {
              seen = MediaQuery.sizeOf(context);
              return const SizedBox.expand();
            },
          ),
          builder: (context, child) => app.rootShell(child),
        ),
      ),
    );
    return seen;
  }

  testWidgets('the desktop view keeps the window\'s own logical size', (tester) async {
    final size = await pumpShell(tester, physical: const Size(2560, 1440), dpr: 1.5);

    expect(size.height, closeTo(960, 0.01));
  });

  testWidgets('the HTPC view lays out 540 high on a 1440p monitor at 150 %', (tester) async {
    await SettingsService.instance.write(SettingsService.htpcMode, true);

    final size = await pumpShell(tester, physical: const Size(2560, 1440), dpr: 1.5);

    expect(size.height, closeTo(540, 0.01));
    expect(size.width, closeTo(960, 0.01), reason: '16:9 stays 16:9, as on the Shield');
  });

  testWidgets('the HTPC view does the same at 4K and 100 %', (tester) async {
    await SettingsService.instance.write(SettingsService.htpcMode, true);

    final size = await pumpShell(tester, physical: const Size(3840, 2160), dpr: 1.0);

    expect(size.height, closeTo(540, 0.01));
  });

  testWidgets('switching the view rescales without a restart', (tester) async {
    var size = await pumpShell(tester, physical: const Size(1920, 1080), dpr: 1.0);
    expect(size.height, closeTo(1080, 0.01));

    await SettingsService.instance.write(SettingsService.htpcMode, true);
    await tester.pump();
    size = tester.getSize(find.byType(SizedBox).last);

    expect(size.height, closeTo(540, 0.01));
  });
}
