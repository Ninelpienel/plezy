import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../focus/key_event_utils.dart';
import '../i18n/strings.g.dart';
import '../services/htpc_mode.dart';
import '../utils/dialogs.dart';
import 'app_icon.dart';
import 'focusable_list_tile.dart';

/// Shows the HTPC exit menu and carries out the choice. Cancel, Back and a
/// click outside the dialog all leave everything as it was.
Future<void> showHtpcExitMenu(BuildContext context) async {
  final action = await showScopedDialog<HtpcPowerAction>(context: context, builder: (_) => const HtpcExitMenu());
  if (action != null) await HtpcPower.perform(action);
}

/// "Do you really want to leave?" with Quit, Shut down, Restart, Sleep and
/// Cancel, drawn like Plezy's other option dialogs (see
/// `showOptionPickerDialog`): a themed dialog with one icon row per choice.
/// The first row always takes focus, since the menu is opened from a remote.
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

  IconData _icon(HtpcPowerAction? action) => switch (action) {
    HtpcPowerAction.quit => Symbols.logout_rounded,
    HtpcPowerAction.shutdown => Symbols.power_settings_new_rounded,
    HtpcPowerAction.restart => Symbols.restart_alt_rounded,
    HtpcPowerAction.sleep => Symbols.bedtime_rounded,
    null => Symbols.close_rounded,
  };

  void _choose(HtpcPowerAction? action) => Navigator.of(context).pop(action);

  @override
  Widget build(BuildContext context) {
    final textStyle = Theme.of(context).textTheme.bodyLarge;
    return Focus(
      // Remote Back keys that the dialog route does not map to dismiss.
      onKeyEvent: (_, event) => handleBackKeyAction(event, () => _choose(null)),
      child: SimpleDialog(
        title: Text(t.htpc.exitQuestion),
        insetPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 24),
        constraints: const BoxConstraints(minWidth: 304),
        contentPadding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          for (var i = 0; i < _actions.length; i++)
            FocusableListTile(
              focusNode: _nodes[i],
              autofocus: i == 0,
              leading: AppIcon(_icon(_actions[i]), fill: 1, size: 24),
              title: Text(_label(_actions[i]), style: textStyle),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              horizontalTitleGap: 8,
              minLeadingWidth: 24,
              onTap: () => _choose(_actions[i]),
            ),
        ],
      ),
    );
  }
}
