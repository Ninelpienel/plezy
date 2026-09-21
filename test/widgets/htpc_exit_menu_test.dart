import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plezy/i18n/strings.g.dart';
import 'package:plezy/services/htpc_mode.dart';
import 'package:plezy/widgets/htpc_exit_menu.dart';

/// The exit menu is the only way out of an HTPC session from the couch, so
/// every key a remote or keyboard sends has to land on a choice - or on
/// Cancel, never on the screen underneath.
void main() {
  setUp(() => LocaleSettings.setLocaleSync(AppLocale.en));

  Future<List<HtpcPowerAction?>> pumpMenu(WidgetTester tester) async {
    final results = <HtpcPowerAction?>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Center(
            child: TextButton(
              onPressed: () async => results.add(
                await Navigator.of(
                  context,
                ).push<HtpcPowerAction>(MaterialPageRoute(builder: (_) => const HtpcExitMenu())),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return results;
  }

  Future<void> press(WidgetTester tester, LogicalKeyboardKey key) async {
    await tester.sendKeyEvent(key);
    await tester.pumpAndSettle();
  }

  testWidgets('offers the five Plex HTPC choices, Quit first and focused', (tester) async {
    await pumpMenu(tester);

    expect(find.text('Do you really want to leave Plezy?'), findsOneWidget);
    for (final label in ['Quit', 'Shut down', 'Restart', 'Sleep', 'Cancel']) {
      expect(find.text(label), findsOneWidget);
    }
    expect(FocusManager.instance.primaryFocus?.debugLabel, 'HtpcExitMenu0');
  });

  testWidgets('Enter on the focused row picks it', (tester) async {
    final results = await pumpMenu(tester);

    await press(tester, LogicalKeyboardKey.enter);

    expect(results, [HtpcPowerAction.quit]);
  });

  testWidgets('arrows walk the rows and stop at the ends', (tester) async {
    final results = await pumpMenu(tester);

    await press(tester, LogicalKeyboardKey.arrowUp);
    expect(FocusManager.instance.primaryFocus?.debugLabel, 'HtpcExitMenu0', reason: 'no wrap above Quit');
    await press(tester, LogicalKeyboardKey.arrowDown);
    await press(tester, LogicalKeyboardKey.arrowDown);
    await press(tester, LogicalKeyboardKey.enter);

    expect(results, [HtpcPowerAction.restart]);
  });

  testWidgets('Back cancels', (tester) async {
    final results = await pumpMenu(tester);

    await press(tester, LogicalKeyboardKey.escape);

    expect(results, [null]);
    expect(find.byType(HtpcExitMenu), findsNothing);
  });

  testWidgets('Cancel cancels', (tester) async {
    final results = await pumpMenu(tester);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(results, [null]);
  });
}
