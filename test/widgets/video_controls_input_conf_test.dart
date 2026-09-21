import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'package:plezy/database/app_database.dart';
import 'package:plezy/focus/input_mode_tracker.dart';
import 'package:plezy/i18n/strings.g.dart';
import 'package:plezy/mpv/mpv.dart';
import 'package:plezy/mpv/mpv_input_bindings.dart';
import 'package:plezy/providers/playback_state_provider.dart';
import 'package:plezy/services/settings_service.dart';
import 'package:plezy/services/video_volume_controller.dart';
import 'package:plezy/utils/platform_detector.dart';
import 'package:plezy/watch_together/providers/watch_together_provider.dart';
import 'package:plezy/widgets/video_controls/player_chrome_controller.dart';
import 'package:plezy/widgets/video_controls/video_controls.dart';
import 'package:plezy/widgets/video_controls/widgets/player_toast_indicator.dart';

import '../test_helpers/media_items.dart';
import '../test_helpers/prefs.dart';
import '../test_helpers/theme.dart';

/// #2409: a key the user's input.conf binds goes to mpv, ahead of Plezy's own
/// shortcut for it. Plezy keeps the keys that would strand the viewer - the
/// way out of the player, and focus movement inside the visible controls.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _InputConfPlayer player;
  late PlayerChromeController chrome;
  late PlayerToastController toast;
  late VideoVolumeController volume;
  late PlaybackStateProvider playbackState;
  late WatchTogetherProvider watchTogether;
  late AppDatabase database;
  late ValueNotifier<bool> hasFirstFrame;
  late SettingsService settings;
  var toggles = 0;

  setUp(() async {
    LocaleSettings.setLocaleSync(AppLocale.en);
    await initializeDateFormatting('en');
    resetSharedPreferencesForTest();
    SettingsService.resetForTesting();
    settings = await SettingsService.getInstance();
    await settings.write(SettingsService.videoPlayerNavigationEnabled, false);

    TvDetectionService.debugSetAppleTVOverride(false);
    PlatformDetector.debugSetIsDesktopOSOverride(true);

    database = AppDatabase.forTesting(NativeDatabase.memory());
    player = _InputConfPlayer();
    chrome = PlayerChromeController(initiallyVisible: false);
    toast = PlayerToastController();
    volume = VideoVolumeController(player: player, settings: settings, initialVolume: 100);
    playbackState = PlaybackStateProvider();
    watchTogether = WatchTogetherProvider();
    hasFirstFrame = ValueNotifier<bool>(true);
    toggles = 0;
  });

  tearDown(() async {
    TvDetectionService.debugSetAppleTVOverride(null);
    PlatformDetector.debugSetIsDesktopOSOverride(null);
    hasFirstFrame.dispose();
    volume.dispose();
    playbackState.dispose();
    watchTogether.dispose();
    chrome.dispose();
    toast.dispose();
    await database.close();
  });

  void playerTest(String description, String inputConf, Future<void> Function(WidgetTester tester) body) {
    testWidgets(description, (tester) async {
      player.bindings = MpvInputBindings.parse(inputConf);
      await tester.pumpWidget(
        InputModeTracker(
          child: MultiProvider(
            providers: [
              Provider<AppDatabase>.value(value: database),
              ChangeNotifierProvider<PlaybackStateProvider>.value(value: playbackState),
              ChangeNotifierProvider<WatchTogetherProvider>.value(value: watchTogether),
            ],
            child: MaterialApp(
              theme: ThemeData(platform: TargetPlatform.windows, extensions: const [testMonoTokens]),
              home: Scaffold(
                body: SizedBox(
                  width: 1280,
                  height: 720,
                  child: PlexVideoControls(
                    player: player,
                    volumeController: volume,
                    metadata: testMediaItem(id: 'input-conf'),
                    toastController: toast,
                    chromeController: chrome,
                    hasFirstFrame: hasFirstFrame,
                    canNavigateMediaItems: false,
                    onPlayPauseRequested: (_) async => toggles++,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await body(tester);
      chrome.cancelAutoHide();
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  Future<void> press(WidgetTester tester, LogicalKeyboardKey key, {String? character}) async {
    await tester.sendKeyDownEvent(key, character: character);
    await tester.pump();
    await tester.sendKeyUpEvent(key);
    await tester.pumpAndSettle();
  }

  playerTest('a bound key is handed to mpv', 'i script-binding stats/display-stats\n', (tester) async {
    await press(tester, LogicalKeyboardKey.keyI, character: 'i');

    expect(player.keypresses, ['i']);
  });

  playerTest('input.conf wins over Plezy play/pause', 'SPACE cycle pause\n', (tester) async {
    await press(tester, LogicalKeyboardKey.space, character: ' ');

    expect(player.keypresses, ['SPACE']);
    expect(toggles, 0, reason: 'Plezy must not also toggle the key mpv just handled');
  });

  playerTest('an unbound key is still Plezy\'s', 'i script-binding stats/display-stats\n', (tester) async {
    await press(tester, LogicalKeyboardKey.space, character: ' ');

    expect(player.keypresses, isEmpty);
    expect(toggles, 1);
  });

  playerTest('Escape stays the way out even when bound', 'ESC set fullscreen no\n', (tester) async {
    await press(tester, LogicalKeyboardKey.escape);

    expect(player.keypresses, isEmpty);
  });

  playerTest('a held key repeats into mpv, its release does not', 'RIGHT seek 5\n', (tester) async {
    await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyRepeatEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();

    expect(player.keypresses, ['RIGHT', 'RIGHT']);
    expect(player.seeks, isEmpty, reason: 'Plezy must not seek as well');
  });

  playerTest('arrows move focus inside the visible controls', 'RIGHT seek 5\n', (tester) async {
    chrome.show();
    await tester.pumpAndSettle();
    await press(tester, LogicalKeyboardKey.tab);
    final focused = FocusManager.instance.primaryFocus?.debugLabel;
    expect(focused, isNot(anyOf(isNull, 'PlayerSurface')), reason: 'precondition: a control has focus');

    await press(tester, LogicalKeyboardKey.arrowRight);

    expect(player.keypresses, isEmpty, reason: 'the arrow is focus navigation here');
  });

  playerTest('nothing is forwarded without an input.conf', '', (tester) async {
    await press(tester, LogicalKeyboardKey.keyI, character: 'i');
    await press(tester, LogicalKeyboardKey.space, character: ' ');

    expect(player.keypresses, isEmpty);
    expect(toggles, 1);
  });
}

class _InputConfPlayer implements Player, MpvInputBindingsSource {
  MpvInputBindings bindings = MpvInputBindings.empty;
  final keypresses = <String>[];

  @override
  MpvInputBindings get inputBindings => bindings;

  @override
  Future<void> command(List<String> args) async {
    if (args.first == 'keypress') keypresses.add(args[1]);
  }

  @override
  String get playerType => 'mpv';

  @override
  PlayerState get state => PlayerState(
    playing: true,
    position: const Duration(minutes: 5),
    duration: const Duration(minutes: 45),
    seekable: true,
  );

  @override
  Future<void> seek(Duration position) async => seeks.add(position);

  final seeks = <Duration>[];

  @override
  PlayerStreams get streams => PlayerStreams(
    playing: const Stream<bool>.empty(),
    completed: const Stream<bool>.empty(),
    buffering: const Stream<bool>.empty(),
    position: const Stream<Duration>.empty(),
    duration: const Stream<Duration>.empty(),
    seekable: const Stream<bool>.empty(),
    buffer: const Stream<Duration>.empty(),
    volume: const Stream<double>.empty(),
    rate: const Stream<double>.empty(),
    tracks: const Stream<Tracks>.empty(),
    track: const Stream<TrackSelection>.empty(),
    log: const Stream<PlayerLog>.empty(),
    error: const Stream<PlayerError>.empty(),
    audioDevice: const Stream<AudioDevice>.empty(),
    audioDevices: const Stream<List<AudioDevice>>.empty(),
    bufferRanges: const Stream<List<BufferRange>>.empty(),
    playbackRestart: const Stream<void>.empty(),
    backendSwitched: const Stream<void>.empty(),
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
