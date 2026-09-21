import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plezy/services/settings_service.dart';
import 'package:plezy/theme/ui_text_scale.dart';

import '../test_helpers/prefs.dart';

/// The text-size preference multiplies the platform's own scaling rather than
/// replacing it, and it has to reach text the app sizes itself - a fitted
/// title measures through the ambient scaler, which is what makes the stand-in
/// for a missing clear logo shrink with everything else.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    resetSharedPreferencesForTest();
    SettingsService.resetForTesting();
    await SettingsService.getInstance();
  });

  Future<TextScaler> scalerUnder(WidgetTester tester, {required TextScaler ambient}) async {
    late TextScaler seen;
    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(textScaler: ambient),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: UiTextScaleScope(
            child: Builder(
              builder: (context) {
                seen = MediaQuery.textScalerOf(context);
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      ),
    );
    return seen;
  }

  testWidgets('the default leaves the platform scaler exactly as it was', (tester) async {
    const ambient = TextScaler.linear(1.3);
    expect(await scalerUnder(tester, ambient: ambient), same(ambient));
  });

  testWidgets('a stored value multiplies the platform scaler instead of overriding it', (tester) async {
    await SettingsService.instance.write(SettingsService.uiTextScale, 0.8);

    final scaler = await scalerUnder(tester, ambient: const TextScaler.linear(1.5));

    // 20 logical pixels, scaled 1.5x by the platform and 0.8x by the user.
    expect(scaler.scale(20), closeTo(24, 0.001));
  });

  testWidgets('equal factors compare equal so cached text measurements survive a rebuild', (tester) async {
    const base = TextScaler.linear(1.0);
    expect(const ScaledTextScaler(base, 0.8), const ScaledTextScaler(base, 0.8));
    expect(const ScaledTextScaler(base, 0.8).hashCode, const ScaledTextScaler(base, 0.8).hashCode);
    expect(const ScaledTextScaler(base, 0.8), isNot(const ScaledTextScaler(base, 0.9)));
  });

  test('a value outside the range is clamped on the way in and on the way out', () async {
    await SettingsService.instance.write(SettingsService.uiTextScale, 5.0);
    expect(SettingsService.instance.read(SettingsService.uiTextScale), UiTextScale.max);

    await SettingsService.instance.write(SettingsService.uiTextScale, 0.1);
    expect(SettingsService.instance.read(SettingsService.uiTextScale), UiTextScale.min);
  });
}
