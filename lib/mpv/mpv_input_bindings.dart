import 'package:flutter/services.dart';

/// A player whose mpv loaded the user's `input.conf`.
abstract interface class MpvInputBindingsSource {
  /// The keys that `input.conf` binds; empty when mpv loaded none.
  MpvInputBindings get inputBindings;
}

/// The keyboard keys a user's `input.conf` binds (#2409).
///
/// libmpv reads `input.conf` from the config directory itself, but the
/// embedded player never receives a key: Plezy's window owns the keyboard.
/// Plezy therefore asks this set whether a key belongs to `input.conf` and,
/// if it does, hands the press to mpv with the `keypress` command instead of
/// running its own shortcut. `input.conf` wins every key it names.
///
/// Keys are compared in a canonical spelling, because mpv accepts several
/// for the same key: modifier order and case do not matter, `Shift+a` is
/// `A`, and named keys such as `space` are case-insensitive.
class MpvInputBindings {
  const MpvInputBindings._(this._keys);

  static const empty = MpvInputBindings._({});

  final Set<String> _keys;

  bool get isEmpty => _keys.isEmpty;

  /// Whether `input.conf` binds [mpvKey], a name from [mpvKeyNameFor].
  bool binds(String mpvKey) {
    final key = canonicalMpvKey(mpvKey);
    return key != null && _keys.contains(key);
  }

  /// The bound keys of an `input.conf` text.
  ///
  /// Only plain keyboard bindings in the default section count. Mouse and
  /// wheel bindings never arrive as key events, a binding in a named
  /// `{section}` is inactive until a script enables it, and key sequences
  /// (`a-b`) would need Plezy to hold the first key back - those stay with
  /// Plezy, which is what they did before `input.conf` existed.
  factory MpvInputBindings.parse(String text) {
    final keys = <String>{};
    for (final rawLine in text.split('\n')) {
      final line = rawLine.trim();
      if (line.isEmpty || line.startsWith('#')) continue;
      final parts = line.split(RegExp(r'\s+'));
      if (parts.length < 2) continue;
      final keyName = parts[0];
      if (parts[1].startsWith('{') && parts[1] != '{default}') continue;
      if (_isSequence(keyName)) continue;
      final key = canonicalMpvKey(keyName);
      if (key == null || _isPointerKey(key)) continue;
      keys.add(key);
    }
    return MpvInputBindings._(keys);
  }

  static bool _isSequence(String name) {
    final dash = name.indexOf('-');
    return dash > 0 && dash < name.length - 1;
  }

  static bool _isPointerKey(String key) {
    final name = key.substring(key.lastIndexOf('+') + 1);
    return name.startsWith('MBTN') || name.startsWith('MOUSE') || name.startsWith('WHEEL') || name.startsWith('AXIS');
  }
}

const _modifierOrder = ['Shift', 'Ctrl', 'Alt', 'Meta'];

/// mpv's own names for single characters that are awkward in `input.conf`.
const _characterAliases = {'#': 'SHARP', '+': 'PLUS', ' ': 'SPACE'};

/// One spelling per key: modifiers in a fixed order, named keys upper case,
/// `Shift` folded into letters. Null for a name that is not a key.
String? canonicalMpvKey(String name) {
  final modifiers = <String>{};
  var rest = name;
  while (true) {
    final plus = rest.indexOf('+');
    // A '+' at index 0 is the key itself ("+" or "++" after a modifier).
    if (plus <= 0) break;
    final modifier = _modifierOrder.where((m) => m.toLowerCase() == rest.substring(0, plus).toLowerCase());
    if (modifier.isEmpty) break;
    modifiers.add(modifier.first);
    rest = rest.substring(plus + 1);
  }
  if (rest.isEmpty) return null;

  String key;
  if (rest.runes.length == 1) {
    key = _characterAliases[rest] ?? rest;
    if (modifiers.contains('Shift') && key.toLowerCase() != key.toUpperCase()) {
      key = key.toUpperCase();
      modifiers.remove('Shift');
    }
  } else {
    key = rest.toUpperCase();
  }
  return [..._modifierOrder.where(modifiers.contains), key].join('+');
}

final Map<LogicalKeyboardKey, String> _namedKeys = {
  LogicalKeyboardKey.space: 'SPACE',
  LogicalKeyboardKey.enter: 'ENTER',
  LogicalKeyboardKey.escape: 'ESC',
  LogicalKeyboardKey.tab: 'TAB',
  LogicalKeyboardKey.backspace: 'BS',
  LogicalKeyboardKey.delete: 'DEL',
  LogicalKeyboardKey.insert: 'INS',
  LogicalKeyboardKey.home: 'HOME',
  LogicalKeyboardKey.end: 'END',
  LogicalKeyboardKey.pageUp: 'PGUP',
  LogicalKeyboardKey.pageDown: 'PGDWN',
  LogicalKeyboardKey.arrowUp: 'UP',
  LogicalKeyboardKey.arrowDown: 'DOWN',
  LogicalKeyboardKey.arrowLeft: 'LEFT',
  LogicalKeyboardKey.arrowRight: 'RIGHT',
  LogicalKeyboardKey.printScreen: 'PRINT',
  LogicalKeyboardKey.contextMenu: 'MENU',
  LogicalKeyboardKey.numpad0: 'KP0',
  LogicalKeyboardKey.numpad1: 'KP1',
  LogicalKeyboardKey.numpad2: 'KP2',
  LogicalKeyboardKey.numpad3: 'KP3',
  LogicalKeyboardKey.numpad4: 'KP4',
  LogicalKeyboardKey.numpad5: 'KP5',
  LogicalKeyboardKey.numpad6: 'KP6',
  LogicalKeyboardKey.numpad7: 'KP7',
  LogicalKeyboardKey.numpad8: 'KP8',
  LogicalKeyboardKey.numpad9: 'KP9',
  LogicalKeyboardKey.numpadDecimal: 'KP_DEC',
  LogicalKeyboardKey.numpadEnter: 'KP_ENTER',
  LogicalKeyboardKey.numpadAdd: 'KP_ADD',
  LogicalKeyboardKey.numpadSubtract: 'KP_SUBTRACT',
  LogicalKeyboardKey.numpadMultiply: 'KP_MULTIPLY',
  LogicalKeyboardKey.numpadDivide: 'KP_DIVIDE',
  LogicalKeyboardKey.mediaPlayPause: 'PLAYPAUSE',
  LogicalKeyboardKey.mediaPlay: 'PLAY',
  LogicalKeyboardKey.mediaPause: 'PAUSE',
  LogicalKeyboardKey.mediaStop: 'STOP',
  LogicalKeyboardKey.mediaTrackNext: 'NEXT',
  LogicalKeyboardKey.mediaTrackPrevious: 'PREV',
  LogicalKeyboardKey.mediaFastForward: 'FORWARD',
  LogicalKeyboardKey.mediaRewind: 'REWIND',
  LogicalKeyboardKey.audioVolumeUp: 'VOLUME_UP',
  LogicalKeyboardKey.audioVolumeDown: 'VOLUME_DOWN',
  LogicalKeyboardKey.audioVolumeMute: 'MUTE',
  for (var i = 1; i <= 24; i++) LogicalKeyboardKey(LogicalKeyboardKey.f1.keyId + i - 1): 'F$i',
};

/// The mpv name of the key [event] pressed, or null for keys mpv has no name
/// for (bare modifiers, dead keys).
///
/// Printable keys are named by the character they produce, as mpv does for
/// its own window: `!` rather than `Shift+1`, and on layouts where AltGr
/// (reported as Ctrl+Alt) types a character, that character without the
/// modifiers. The modifier flags are parameters so the mapping is testable
/// without a keyboard; callers pass [HardwareKeyboard]'s state.
String? mpvKeyNameFor(
  KeyEvent event, {
  required bool shift,
  required bool control,
  required bool alt,
  required bool meta,
}) {
  final named = _namedKeys[event.logicalKey];
  final character = event.character;
  final printable =
      named == null &&
      character != null &&
      character.runes.length == 1 &&
      character.runes.first >= 0x20 &&
      character.runes.first != 0x7f;

  final modifiers = <String>[];
  final altGr = printable && control && alt;
  if (shift && !printable) modifiers.add('Shift');
  if (control && !altGr) modifiers.add('Ctrl');
  if (alt && !altGr) modifiers.add('Alt');
  if (meta) modifiers.add('Meta');

  String? key;
  if (named != null) {
    key = named;
  } else if (printable) {
    key = character;
  } else {
    // Ctrl+letter reports a control character; name the key by its label.
    final label = event.logicalKey.keyLabel;
    if (label.runes.length == 1) key = label.toLowerCase();
  }
  if (key == null) return null;
  return canonicalMpvKey([...modifiers, key].join('+'));
}
