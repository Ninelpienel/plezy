import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plezy/screens/settings/mpv_config_line_numbers.dart';

const _style = TextStyle(fontFamily: 'monospace', fontSize: 13);
const _padding = EdgeInsets.all(12);

Future<TextEditingController> _pump(WidgetTester tester, String text, {double width = 400}) async {
  final controller = TextEditingController(text: text);
  addTearDown(controller.dispose);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: width,
            child: MpvConfigLineNumbers(
              controller: controller,
              style: _style,
              contentPadding: _padding,
              child: TextField(
                controller: controller,
                maxLines: null,
                minLines: 4,
                style: _style,
                decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: _padding),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  return controller;
}

/// The top of the text row where line [line] (0-based) of the field starts.
double _lineTop(WidgetTester tester, String text, int line) {
  final editable = tester.allRenderObjects.whereType<RenderEditable>().single;
  var offset = 0;
  for (var i = 0; i < line; i++) {
    offset = text.indexOf('\n', offset) + 1;
  }
  final caret = editable.getLocalRectForCaret(TextPosition(offset: offset));
  return editable.localToGlobal(caret.topLeft).dy;
}

/// Each number sits on the row its line starts on (#2399), wrapped lines
/// included, so a number read off the gutter is the line mpv reports.
void main() {
  testWidgets('each number sits on the first row of its line', (tester) async {
    const text = 'deband=yes\n\n[Deband]\nprofile-cond=p["video-params/pixelformat"] == "yuv420p"';
    await _pump(tester, text);

    for (var i = 0; i < 4; i++) {
      final numberTop = tester.getTopLeft(find.text('${i + 1}')).dy;
      expect(numberTop, moreOrLessEquals(_lineTop(tester, text, i), epsilon: 1.0), reason: 'line ${i + 1}');
    }
  });

  testWidgets('a soft-wrapped line pushes the next number down', (tester) async {
    final long = 'glsl-shaders=${'C:/mpv/shaders/nnedi3-nns32-win8x4.hook;' * 4}';
    final text = '$long\nhwdec=auto';
    await _pump(tester, text, width: 300);

    final secondTop = tester.getTopLeft(find.text('2')).dy;
    final firstTop = tester.getTopLeft(find.text('1')).dy;
    expect(secondTop - firstTop, greaterThan(40), reason: 'the first line wraps over several rows');
    expect(secondTop, moreOrLessEquals(_lineTop(tester, text, 1), epsilon: 1.0));
  });

  testWidgets('numbers follow edits', (tester) async {
    final controller = await _pump(tester, 'a=1');
    expect(find.text('2'), findsNothing);

    controller.text = 'a=1\nb=2';
    await tester.pump();
    expect(find.text('2'), findsOneWidget);
  });
}
