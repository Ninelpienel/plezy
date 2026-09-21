import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plezy/i18n/strings.g.dart';
import 'package:plezy/media/media_item.dart';
import 'package:plezy/media/media_kind.dart';
import 'package:plezy/services/settings_service.dart';
import 'package:plezy/utils/platform_detector.dart';
import 'package:plezy/widgets/tv_spotlight_background.dart';

import '../test_helpers/prefs.dart';

/// The spotlight's info column is anchored to the bottom of its box, so its
/// height decides where the title sits. The summary therefore occupies a fixed
/// band of three lines whatever it holds — otherwise every item whose
/// description is a different length puts the title at a different height, and
/// moving between hub items makes the whole block jump.
Future<Rect> _titleRect(WidgetTester tester, MediaItem item) async {
  await SettingsService.getInstance();
  tester.view.physicalSize = const Size(1920, 1080);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    TranslationProvider(
      child: MaterialApp(
        home: Scaffold(
          body: SizedBox.expand(
            child: TvSpotlightBackground(
              item: item,
              client: null,
              allowNetwork: false,
              compact: true,
              contentTop: 80,
              contentBottom: 200,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));

  return tester.getRect(find.text(item.grandparentTitle ?? item.displayTitle));
}

MediaItem _episode({required String summary}) => MediaItem.plex(
  id: 'episode_1',
  kind: MediaKind.episode,
  title: 'The Episode',
  grandparentTitle: 'A Show',
  parentIndex: 4,
  index: 32,
  summary: summary,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    resetSharedPreferencesForTest();
    SettingsService.resetForTesting();
    TvDetectionService.debugSetAppleTVOverride(true);
    LocaleSettings.setLocaleSync(AppLocale.en);
  });

  tearDown(() => TvDetectionService.debugSetAppleTVOverride(null));

  testWidgets('the title keeps its height however long the summary is', (tester) async {
    final long = await _titleRect(
      tester,
      _episode(
        summary:
            'The first test launch of the rocket is due, and almost nothing about it goes to plan: the fuel '
            'runs hot, the telemetry drops out twice, and the village is left arguing about whether to try '
            'again before the season turns or wait out the winter with what little they have left.',
      ),
    );
    final short = await _titleRect(tester, _episode(summary: 'Short.'));
    final none = await _titleRect(tester, _episode(summary: ''));

    expect(short.top, moreOrLessEquals(long.top, epsilon: 0.5));
    expect(none.top, moreOrLessEquals(long.top, epsilon: 0.5));
  });

  testWidgets('a long title is cut rather than wrapped onto a second line', (tester) async {
    // The stand-in for a missing clear logo is one line: FittingTitleText used
    // to shrink the type until it fit, so a long name rendered at a size no
    // other spotlight used.
    final rect = await _titleRect(
      tester,
      MediaItem.plex(
        id: 'movie_1',
        kind: MediaKind.movie,
        title: 'A Title So Long That It Cannot Possibly Fit Across Two Thirds Of Any Television Screen At All',
        summary: 'Something happens.',
      ),
    );
    final size = tester.widget<Text>(find.textContaining('A Title So Long')).style!.fontSize!;

    // One line box, not two.
    expect(rect.height, lessThan(size * 2));
    // And it stops at two thirds of the 1920-wide surface.
    expect(rect.right, lessThanOrEqualTo(1920 * (2 / 3) + 1));
  });
}
