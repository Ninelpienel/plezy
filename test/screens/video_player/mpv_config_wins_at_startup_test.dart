import 'package:flutter_test/flutter_test.dart';

import '../../test_helpers/hdr_startup.dart';

/// Plezy's startup defaults - subtitle style, hwdec, volume-max, the
/// screenshot folder - used to be written over whatever the user's mpv.conf
/// set once mpv read the file itself from the config directory. The file has
/// the last word again: an option it sets, even inside a profile, is left
/// alone at startup.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(installHdrStartupHarness);

  testWidgets('startup leaves every option mpv.conf sets to mpv.conf', (tester) async {
    await expectMpvConfigOptionsAreNotOverwritten(tester);
  });
}
