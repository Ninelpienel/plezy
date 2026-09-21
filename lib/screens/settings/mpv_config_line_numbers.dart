import 'package:flutter/material.dart';

/// Line numbers beside the desktop config editor (#2399).
///
/// The editor soft-wraps, so a number cannot simply sit on every text row: it
/// belongs to the first row of its line, and a wrapped line pushes the next
/// number down by as many rows as it took. Each line is laid out here the way
/// the field lays it out - same style, same text scaling, same width - to find
/// how tall it is.
class MpvConfigLineNumbers extends StatelessWidget {
  const MpvConfigLineNumbers({
    super.key,
    required this.controller,
    required this.style,
    required this.contentPadding,
    required this.child,
  });

  final TextEditingController controller;

  /// The style handed to the text field; the theme's input style is merged
  /// underneath it here exactly as [TextField] does.
  final TextStyle style;

  /// The field's `contentPadding`, which places its first row.
  final EdgeInsets contentPadding;

  final Widget child;

  static const _gutterGap = 8.0;

  /// [RenderEditable] keeps this much width free for the caret at a line end.
  static const _caretMargin = 1.0 + 2.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fieldStyle = (theme.useMaterial3 ? theme.textTheme.bodyLarge : theme.textTheme.titleMedium)!.merge(style);
    final numberStyle = fieldStyle.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final textScaler = MediaQuery.textScalerOf(context);
    final textDirection = Directionality.of(context);

    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        final lines = value.text.split('\n');
        final gutterWidth = _measure('${lines.length}', numberStyle, textScaler, textDirection).width;

        return LayoutBuilder(
          builder: (context, constraints) {
            final textWidth =
                constraints.maxWidth - gutterWidth - _gutterGap - contentPadding.horizontal - _caretMargin;
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ExcludeSemantics(
                  child: Padding(
                    padding: EdgeInsets.only(top: contentPadding.top),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        for (var i = 0; i < lines.length; i++)
                          SizedBox(
                            width: gutterWidth,
                            height: _measure(
                              lines[i],
                              fieldStyle,
                              textScaler,
                              textDirection,
                              maxWidth: textWidth,
                            ).height,
                            child: Text(
                              '${i + 1}',
                              style: numberStyle,
                              textAlign: TextAlign.end,
                              textScaler: textScaler,
                              maxLines: 1,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: _gutterGap),
                Expanded(child: child),
              ],
            );
          },
        );
      },
    );
  }

  static Size _measure(
    String text,
    TextStyle style,
    TextScaler textScaler,
    TextDirection textDirection, {
    double maxWidth = double.infinity,
  }) {
    final painter = TextPainter(
      // An empty line still takes a row.
      text: TextSpan(text: text.isEmpty ? ' ' : text, style: style),
      textDirection: textDirection,
      textScaler: textScaler,
    )..layout(maxWidth: maxWidth < 1 ? 1 : maxWidth);
    final size = painter.size;
    painter.dispose();
    return size;
  }
}
