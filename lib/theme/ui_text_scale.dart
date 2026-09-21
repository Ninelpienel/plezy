import 'package:flutter/material.dart';

import '../services/settings_service.dart';
import '../widgets/settings_builder.dart';

/// Applies the user's text-size preference to every [Text] below it.
///
/// Sits at the root shell, so it reaches routes, dialogs and snackbars alike,
/// and it reaches text the app sizes itself: `FittingTitleText` measures
/// through the ambient scaler, so the title that stands in for a missing clear
/// logo shrinks with everything else while its slot keeps its height.
///
/// Subtitles are untouched: both backends burn them in themselves (libass),
/// and the player has its own size control.
class UiTextScaleScope extends StatelessWidget {
  const UiTextScaleScope({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SettingValueBuilder<double>(
      pref: SettingsService.uiTextScale,
      child: child,
      builder: (context, factor, child) {
        final data = MediaQuery.of(context);
        if (factor == 1.0) return child!;
        return MediaQuery(
          data: data.copyWith(textScaler: ScaledTextScaler(data.textScaler, factor)),
          child: child!,
        );
      },
    );
  }
}

/// The ambient scaler with a constant factor on top.
///
/// Composing instead of replacing keeps the platform's own accessibility text
/// size in play: the preference reads as a relative adjustment, not as an
/// override that quietly undoes a system setting.
@immutable
class ScaledTextScaler extends TextScaler {
  const ScaledTextScaler(this.base, this.factor);

  final TextScaler base;
  final double factor;

  @override
  double scale(double fontSize) => base.scale(fontSize) * factor;

  @override
  // ignore: deprecated_member_use - the base class still declares it
  double get textScaleFactor => base.textScaleFactor * factor;

  // Text measurements are cached by scaler identity (text_measure_cache), so
  // value equality is what keeps a rebuild from re-shaping every title.
  @override
  bool operator ==(Object other) => other is ScaledTextScaler && other.base == base && other.factor == factor;

  @override
  int get hashCode => Object.hash(base, factor);

  @override
  String toString() => 'ScaledTextScaler($base, ${factor}x)';
}
