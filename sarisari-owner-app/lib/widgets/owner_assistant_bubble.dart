import 'package:flutter/material.dart';

import '../routes/app_routes.dart';
import '../theme/owner_theme.dart';

class OwnerAssistantBubble extends StatelessWidget {
  const OwnerAssistantBubble({super.key});

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      heroTag: 'owner-assistant-bubble',
      tooltip: 'Open store assistant',
      backgroundColor: OwnerTheme.primary,
      foregroundColor: Colors.white,
      elevation: 6,
      shape: const CircleBorder(),
      onPressed: () => Navigator.of(context).pushNamed(AppRoutes.assistant),
      child: const Icon(Icons.chat_bubble_rounded, size: 26),
    );
  }
}
