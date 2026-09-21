import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../focus/dpad_navigator.dart';
import '../focus/key_event_utils.dart';
import '../i18n/strings.g.dart';
import '../services/htpc_mode.dart';

/// Shows the HTPC exit menu and carries out the choice. Cancel, Back and a
/// click outside the buttons all leave everything as it was.
Future<void> showHtpcExitMenu(BuildContext context) async {
  final action = await Navigator.of(context).push<HtpcPowerAction>(
    PageRouteBuilder<HtpcPowerAction>(
      opaque: false,
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 150),
      reverseTransitionDuration: const Duration(milliseconds: 120),
      pageBuilder: (_, _, _) => const HtpcExitMenu(),
      transitionsBuilder: (_, animation, _, child) => FadeTransition(opacity: animation, child: child),
    ),
  );
  if (action != null) await HtpcPower.perform(action);
}

/// "Do you really want to leave?" with Quit, Shut down, Restart, Sleep and
/// Cancel, laid out like Plex HTPC's so the two apps feel the same from the
/// couch: a full-screen dim sheet, a big question, one wide button per row,
/// the focused one inverted to white.
class HtpcExitMenu extends StatefulWidget {
  const HtpcExitMenu({super.key});

  @override
  State<HtpcExitMenu> createState() => _HtpcExitMenuState();
}

class _HtpcExitMenuState extends State<HtpcExitMenu> {
  static const _actions = [
    HtpcPowerAction.quit,
    HtpcPowerAction.shutdown,
    HtpcPowerAction.restart,
    HtpcPowerAction.sleep,
    null, // Cancel
  ];

  late final List<FocusNode> _nodes = [
    for (var i = 0; i < _actions.length; i++) FocusNode(debugLabel: 'HtpcExitMenu$i'),
  ];

  @override
  void dispose() {
    for (final node in _nodes) {
      node.dispose();
    }
    super.dispose();
  }

  String _label(HtpcPowerAction? action) => switch (action) {
    HtpcPowerAction.quit => t.htpc.quit,
    HtpcPowerAction.shutdown => t.htpc.shutdown,
    HtpcPowerAction.restart => t.htpc.restart,
    HtpcPowerAction.sleep => t.htpc.sleep,
    null => t.common.cancel,
  };

  void _choose(HtpcPowerAction? action) => Navigator.of(context).pop(action);

  KeyEventResult _handleKey(FocusNode _, KeyEvent event) {
    final backResult = handleBackKeyAction(event, () => _choose(null));
    if (backResult != KeyEventResult.ignored) return backResult;
    if (!event.isActionable) return KeyEventResult.ignored;

    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowUp || key == LogicalKeyboardKey.arrowDown) {
      final current = _nodes.indexWhere((node) => node.hasFocus);
      final step = key == LogicalKeyboardKey.arrowDown ? 1 : -1;
      final next = current < 0 ? 0 : (current + step).clamp(0, _nodes.length - 1);
      _nodes[next].requestFocus();
      return KeyEventResult.handled;
    }
    // Left/Right have nowhere to go; keep them from leaking to the screen below.
    if (key.isDpadDirection) return KeyEventResult.handled;
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    // Proportions taken from Plex HTPC at 1440p: the menu is sized by the
    // screen, not by text scale, so it reads the same on any TV.
    final unit = size.height / 1440;
    final buttonWidth = (size.width * 0.47).clamp(280.0, 1400.0);

    return Focus(
      onKeyEvent: _handleKey,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _choose(null),
        child: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xF2363636), Color(0xF2242424)],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                SizedBox(height: 110 * unit),
                Text(
                  t.htpc.exitQuestion,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: const Color(0xFFE6E6E6), fontSize: 80 * unit, fontWeight: FontWeight.w400),
                  textScaler: TextScaler.noScaling,
                ),
                SizedBox(height: 110 * unit),
                for (var i = 0; i < _actions.length; i++) ...[
                  if (i > 0) SizedBox(height: 42 * unit),
                  _HtpcMenuButton(
                    focusNode: _nodes[i],
                    autofocus: i == 0,
                    width: buttonWidth,
                    height: 106 * unit,
                    fontSize: 38 * unit,
                    label: _label(_actions[i]),
                    onPressed: () => _choose(_actions[i]),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HtpcMenuButton extends StatefulWidget {
  const _HtpcMenuButton({
    required this.focusNode,
    required this.autofocus,
    required this.width,
    required this.height,
    required this.fontSize,
    required this.label,
    required this.onPressed,
  });

  final FocusNode focusNode;
  final bool autofocus;
  final double width;
  final double height;
  final double fontSize;
  final String label;
  final VoidCallback onPressed;

  @override
  State<_HtpcMenuButton> createState() => _HtpcMenuButtonState();
}

class _HtpcMenuButtonState extends State<_HtpcMenuButton> {
  bool _focused = false;

  KeyEventResult _handleKey(FocusNode _, KeyEvent event) {
    if (!event.logicalKey.isSelectKey && event.logicalKey != LogicalKeyboardKey.space) {
      return KeyEventResult.ignored;
    }
    if (event is KeyDownEvent) widget.onPressed();
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: widget.focusNode,
      autofocus: widget.autofocus,
      onFocusChange: (focused) => setState(() => _focused = focused),
      onKeyEvent: _handleKey,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        // A pointer picks the row it is over, the way Plex highlights it.
        onEnter: (_) => widget.focusNode.requestFocus(),
        child: GestureDetector(
          onTap: widget.onPressed,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 100),
            width: widget.width,
            height: widget.height,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _focused ? Colors.white : const Color(0xFF3A3A3A),
              borderRadius: BorderRadius.circular(widget.height * 0.05),
            ),
            child: Text(
              widget.label,
              textScaler: TextScaler.noScaling,
              style: TextStyle(
                color: _focused ? const Color(0xFF1F1F1F) : const Color(0xFFE0E0E0),
                fontSize: widget.fontSize,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
