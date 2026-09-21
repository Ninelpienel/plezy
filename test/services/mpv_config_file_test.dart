import 'package:flutter_test/flutter_test.dart';
import 'package:plezy/mpv/mpv_owned_options.dart';
import 'package:plezy/services/mpv_config_file.dart';

/// mpv's config parser owns profiles, their conditions and the option aliases
/// the property API never had. Everything Plezy does to the text before mpv
/// reads it therefore has to leave that structure alone — the only lines it
/// may touch are the ones setting state the app itself writes.
void main() {
  group('sanitize', () {
    test('comments out an owned option and says so on the line', () {
      final out = MpvConfigFile.sanitize('deband=yes\nvo=gpu-next\n', appOwnedMpvProperties);

      expect(out, contains('deband=yes'));
      expect(out, isNot(contains('\nvo=gpu-next')));
      expect(out, contains('# vo is set by Plezy itself and was ignored here: vo=gpu-next'));
    });

    test('a profile and its condition survive untouched', () {
      const text = '''
deband=no
deband-threshold=48

[Deband]
profile-cond=p["video-params/pixelformat"] == "yuv420p"
profile-restore=copy
deband=yes
''';

      expect(MpvConfigFile.sanitize(text, appOwnedMpvProperties), text);
    });

    test('comments, blank lines and flag options are left alone', () {
      const text = '# a note\n\nfullscreen\n--glsl-shader="C:\\\\mpv\\\\shaders\\\\nnedi3.hook"\n';

      expect(MpvConfigFile.sanitize(text, appOwnedMpvProperties), text);
    });

    test('the command-line spelling of an owned option is caught too', () {
      final out = MpvConfigFile.sanitize('--tone-mapping=bt.2446a\n', appOwnedMpvProperties);

      expect(out, startsWith('# tone-mapping is set by Plezy itself'));
    });

    test('an owned option inside a profile is withheld as well', () {
      final out = MpvConfigFile.sanitize('[HDR]\nprofile-cond=p["video-params/sig-peak"]>1\nvo=gpu-next\n', {'vo'});

      expect(out, contains('[HDR]'));
      expect(out, contains('profile-cond='));
      expect(out, contains('# vo is set by Plezy itself'));
    });

    test('nothing is withheld when the caller withholds nothing', () {
      const text = 'vo=gpu-next\ntone-mapping=bt.2446a\n';

      expect(MpvConfigFile.sanitize(text, const {}), text);
    });
  });

  group('setsOption', () {
    // Decides whether Plezy's bundled subtitle font may overwrite sub-font.
    test('finds an option in any spelling and inside a profile', () {
      expect(MpvConfigFile.setsOption('sub-font = Amazon Ember\n', 'sub-font'), isTrue);
      expect(MpvConfigFile.setsOption('--sub-font="Amazon Ember"', 'sub-font'), isTrue);
      expect(MpvConfigFile.setsOption('[Anime]\nprofile-cond=true\nsub-font=Amazon Ember', 'sub-font'), isTrue);
    });

    test('a commented line or a longer option name does not count', () {
      expect(MpvConfigFile.setsOption('# sub-font=Amazon Ember', 'sub-font'), isFalse);
      expect(MpvConfigFile.setsOption('sub-font-size=40', 'sub-font'), isFalse);
      expect(MpvConfigFile.setsOption('', 'sub-font'), isFalse);
    });
  });

  test('the two intercepted names are withheld on every platform', () {
    // Neither is an mpv option; the Linux plane moves its own HDR state when
    // it sees them, so a config file writing them desynchronises the UI.
    expect(appInterceptedMpvProperties, containsAll(<String>['hdr-enabled', 'hdr-tone-mapping']));
    expect(appOwnedMpvProperties, containsAll(appInterceptedMpvProperties));
    expect(appOwnedMpvProperties, containsAll(appEmbeddedOwnedMpvProperties));
  });
}
