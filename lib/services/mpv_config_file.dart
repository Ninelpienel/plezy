import 'dart:io';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../utils/app_logger.dart';
import 'settings_service.dart';

/// The user's `mpv.conf` and `input.conf`, written where libmpv reads them.
///
/// Plezy used to parse the config text itself and push every `option=value`
/// through the property API after `mpv_initialize`. That works for plain
/// options and for nothing else, because a config file is not a list of
/// properties:
///
///  * `[profile]` sections, `profile-cond` and `profile-restore` are read by
///    mpv's config parser. As properties they do not exist, so every profile
///    was flattened into its enclosing config and applied unconditionally -
///    the condition never ran and the fallback value it was supposed to guard
///    was overwritten (#2407).
///  * Deprecated option aliases such as `glsl-shader` (for the `glsl-shaders`
///    list) are options, not properties, so setting them failed outright
///    (#2408).
///  * Options mpv only reads while initializing had already been read by the
///    time the properties were written.
///
/// Handing mpv a real config directory instead makes its own parser do the
/// work, at the point in startup it expects to. `config-dir` plus `config=yes`
/// are set before `mpv_initialize`, so the file is read exactly as an mpv or
/// Plex HTPC install would read it. Platforms not yet listed in [isSupported]
/// keep the property path.
abstract final class MpvConfigFile {
  static const _directoryName = 'mpv';
  static const mpvConfName = 'mpv.conf';
  static const inputConfName = 'input.conf';

  /// Platforms whose native player passes `configDir` on to libmpv.
  ///
  /// macOS and iOS still apply the config through the property API: their
  /// Swift cores need the same two options before `mpv_initialize`. Listing a
  /// platform here before its core reads `configDir` would switch the user's
  /// config off there entirely, because the property fallback is skipped as
  /// soon as a directory has been handed over.
  static bool get isSupported =>
      debugSupportedOverride ?? (Platform.isWindows || Platform.isLinux || Platform.isAndroid);

  /// Forces [isSupported] so a test on any host can drive either path: the
  /// config file, or the property fallback the Apple platforms still take.
  @visibleForTesting
  static bool? debugSupportedOverride;

  static String? _directoryPath;

  /// Resolves and creates the config directory, once, at startup.
  ///
  /// Split from [materializeSync] so the player's initialization never waits
  /// on a platform channel: an await between "initialization started" and the
  /// native `initialize` call is a window in which a dispose can slip through
  /// and concurrent callers stop sharing one native init.
  static Future<void> prepare({Directory? directoryOverride}) async {
    if (!isSupported) return;
    try {
      final directory =
          directoryOverride ?? Directory(p.join((await getApplicationSupportDirectory()).path, _directoryName));
      await directory.create(recursive: true);
      _directoryPath = directory.path;
    } catch (e, st) {
      appLogger.w('Could not prepare the mpv config directory', error: e, stackTrace: st);
    }
  }

  @visibleForTesting
  static void resetForTesting() => _directoryPath = null;

  /// Writes both files and returns the directory for `config-dir`, or null
  /// when the directory is not ready or a write failed - the caller then
  /// starts mpv without a config directory and applies the config the old
  /// way, which is what every build before this did.
  ///
  /// Synchronous on purpose (see [prepare]); the files are a few kilobytes.
  static String? materializeSync({required Set<String> withheldOptions}) {
    final directoryPath = _directoryPath;
    if (!isSupported || directoryPath == null) return null;
    try {
      final settings = SettingsService.instanceOrNull;
      if (settings == null) return null;

      final config = sanitize(settings.read(SettingsService.mpvConfigText), withheldOptions);
      File(p.join(directoryPath, mpvConfName)).writeAsStringSync(config, flush: true);
      File(p.join(directoryPath, inputConfName)).writeAsStringSync(
        settings.read(SettingsService.mpvInputConfText),
        flush: true,
      );
      return directoryPath;
    } catch (e, st) {
      appLogger.w('Could not write the mpv config directory', error: e, stackTrace: st);
      return null;
    }
  }

  /// Comments out every line that sets an option the app owns, keeping the
  /// rest - profiles, conditions, comments, blank lines - byte for byte.
  ///
  /// Commenting rather than deleting: the file is the user's own text, and a
  /// line that silently vanished from a config they can open would read as
  /// data loss. The reason rides along on the line itself, which is also the
  /// only place the user will look for it.
  @visibleForTesting
  static String sanitize(String text, Set<String> withheldOptions) {
    if (withheldOptions.isEmpty) return text;
    final out = <String>[];
    for (final line in text.split('\n')) {
      final key = _optionName(line);
      if (key != null && withheldOptions.contains(key)) {
        out.add('# $key is set by Plezy itself and was ignored here: ${line.trim()}');
      } else {
        out.add(line);
      }
    }
    return out.join('\n');
  }

  /// The option a config line sets, or null for comments, blank lines,
  /// `[profile]` headers and anything else that is not an assignment.
  static String? _optionName(String line) {
    var trimmed = line.trim();
    if (trimmed.isEmpty || trimmed.startsWith('#') || trimmed.startsWith('[')) return null;
    // mpv accepts the command-line spelling in a config file too.
    if (trimmed.startsWith('--')) trimmed = trimmed.substring(2);
    final equals = trimmed.indexOf('=');
    final name = (equals < 0 ? trimmed : trimmed.substring(0, equals)).trim();
    return RegExp(r'^[A-Za-z0-9-]+$').hasMatch(name) ? name : null;
  }
}
