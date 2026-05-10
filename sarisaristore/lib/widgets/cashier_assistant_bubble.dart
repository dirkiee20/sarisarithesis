import 'package:flutter/material.dart';

import '../core/app_export.dart';

class CashierAssistantBubble extends StatelessWidget {
  const CashierAssistantBubble({
    super.key,
    this.small = false,
  });

  final bool small;

  @override
  Widget build(BuildContext context) {
    final onPressed = () => Navigator.of(context).pushNamed(
          AppRoutes.cashierAssistant,
        );

    if (small) {
      return FloatingActionButton.small(
        heroTag: 'cashier-assistant-bubble-small',
        tooltip: 'Open cashier assistant',
        backgroundColor: AppTheme.secondaryLight,
        foregroundColor: Colors.white,
        onPressed: onPressed,
        child: const Icon(Icons.chat_bubble_rounded, size: 20),
      );
    }

    return FloatingActionButton(
      heroTag: 'cashier-assistant-bubble',
      tooltip: 'Open cashier assistant',
      backgroundColor: AppTheme.secondaryLight,
      foregroundColor: Colors.white,
      onPressed: onPressed,
      child: const Icon(Icons.chat_bubble_rounded, size: 26),
    );
  }
}
