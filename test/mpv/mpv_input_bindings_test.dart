import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plezy/mpv/mpv_input_bindings.dart';

KeyDownEvent _down(LogicalKeyboardKey logical, {String? character, PhysicalKeyboardKey? physical}) => KeyDownEvent(
  physicalKey: physical ?? PhysicalKeyboardKey.keyA,
  logicalKey: logical,
  character: character,
  timeStamp: Duration.zero,
);

String? _name(KeyEvent event, {bool shift = false, bool control = false, bool alt = false, bool meta = false}) =>
    mpvKeyNameFor(event, shift: shift, control: control, alt: alt, meta: meta);

/// input.conf wins every key it binds (#2409), so the two sides of the match -
/// what the user wrote and what the keyboard produced - have to land on the
/// same spelling, or a binding silently goes back to Plezy.
void main() {
  group('parse', () {
    test('the bindings from the issue are all claimed', () {
      final bindings = MpvInputBindings.parse('''
i script-binding stats/display-stats
k set deband "yes" ; cycle-values deband-iterations "2" "4" "6"
m cycle-values tone-mapping "spline" "st2094-40" ; show-text "Tone-Map \${tone-mapping}"
''');

      expect(bindings.binds('i'), isTrue);
      expect(bindings.binds('k'), isTrue);
      expect(bindings.binds('m'), isTrue);
      expect(bindings.binds('j'), isFalse);
    });

    test('comments, blank lines and bare keys bind nothing', () {
      final bindings = MpvInputBindings.parse('# i cycle pause\n\nq\n');

      expect(bindings.isEmpty, isTrue);
    });

    test('mouse, wheel, sequence and named-section bindings stay with Plezy', () {
      final bindings = MpvInputBindings.parse('''
MBTN_LEFT cycle pause
WHEEL_UP add volume 2
a-b show-text sequence
x {encode} show-text section
y {default} show-text default
''');

      expect(bindings.binds('a'), isFalse);
      expect(bindings.binds('x'), isFalse);
      expect(bindings.binds('y'), isTrue);
      expect(bindings.binds('WHEEL_UP'), isFalse);
    });

    test('the key "-" is a key, not a sequence', () {
      expect(MpvInputBindings.parse('- add volume -2').binds('-'), isTrue);
    });
  });

  group('canonicalMpvKey', () {
    test('modifier order and case do not matter', () {
      expect(canonicalMpvKey('alt+ctrl+x'), canonicalMpvKey('Ctrl+Alt+x'));
    });

    test('Shift folds into a letter', () {
      expect(canonicalMpvKey('Shift+i'), 'I');
      expect(canonicalMpvKey('Ctrl+Shift+a'), 'Ctrl+A');
    });

    test('named keys are case-insensitive', () {
      expect(canonicalMpvKey('space'), 'SPACE');
      expect(canonicalMpvKey('Shift+right'), 'Shift+RIGHT');
    });

    test('the plus key survives its own separator', () {
      expect(canonicalMpvKey('Ctrl++'), 'Ctrl+PLUS');
      expect(canonicalMpvKey('+'), 'PLUS');
    });

    test('a single character stays case-sensitive', () {
      expect(canonicalMpvKey('i'), isNot(canonicalMpvKey('I')));
    });
  });

  group('mpvKeyNameFor', () {
    test('a printable key is named by its character', () {
      expect(_name(_down(LogicalKeyboardKey.keyI, character: 'i')), 'i');
      expect(_name(_down(LogicalKeyboardKey.keyI, character: 'I'), shift: true), 'I');
      expect(_name(_down(LogicalKeyboardKey.digit1, character: '!'), shift: true), '!');
    });

    test('named keys carry Shift', () {
      expect(_name(_down(LogicalKeyboardKey.space, character: ' ')), 'SPACE');
      expect(_name(_down(LogicalKeyboardKey.arrowRight), shift: true), 'Shift+RIGHT');
      expect(_name(_down(LogicalKeyboardKey.f5)), 'F5');
      expect(_name(_down(LogicalKeyboardKey.f12)), 'F12');
    });

    test('Ctrl+letter is named by the key, not the control character', () {
      expect(_name(_down(LogicalKeyboardKey.keyA, character: '\x01'), control: true), 'Ctrl+a');
      expect(_name(_down(LogicalKeyboardKey.keyA), control: true, shift: true), 'Ctrl+A');
    });

    test('AltGr (Ctrl+Alt) typing a character is that character alone', () {
      expect(_name(_down(LogicalKeyboardKey.keyQ, character: '@'), control: true, alt: true), '@');
    });

    test('names match what the user wrote', () {
      final bindings = MpvInputBindings.parse('Ctrl+a show-text a\nI show-text I\nshift+RIGHT seek 60\n');

      expect(bindings.binds(_name(_down(LogicalKeyboardKey.keyA, character: '\x01'), control: true)!), isTrue);
      expect(bindings.binds(_name(_down(LogicalKeyboardKey.keyI, character: 'I'), shift: true)!), isTrue);
      expect(bindings.binds(_name(_down(LogicalKeyboardKey.arrowRight), shift: true)!), isTrue);
      expect(bindings.binds(_name(_down(LogicalKeyboardKey.arrowRight))!), isFalse);
    });

    test('a bare modifier has no mpv name', () {
      expect(_name(_down(LogicalKeyboardKey.shiftLeft), shift: true), isNull);
    });
  });
}
