import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sizer/sizer.dart';

import '../../core/owner_data_service.dart';
import '../../core/owner_assistant.dart';
import '../../theme/owner_theme.dart';

class AssistantScreen extends StatefulWidget {
  const AssistantScreen({super.key});

  @override
  State<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends State<AssistantScreen> {
  final _assistant = const OwnerAssistant();
  final _dataService = const OwnerDataService();
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();

  BusinessSnapshot? _snapshot;
  List<_ChatMessage> _messages = const [];

  static const _quickPrompts = [
    _QuickPrompt(
      label: 'Health',
      query: 'How is my business today?',
      icon: Icons.monitor_heart_outlined,
    ),
    _QuickPrompt(
      label: 'Sales',
      query: 'How much sales today?',
      icon: Icons.payments_outlined,
    ),
    _QuickPrompt(
      label: 'Low stock',
      query: 'What products are low stock?',
      icon: Icons.inventory_2_outlined,
    ),
    _QuickPrompt(
      label: 'Restock',
      query: 'What should I restock?',
      icon: Icons.add_shopping_cart_rounded,
    ),
    _QuickPrompt(
      label: 'Top items',
      query: 'What sold the most today?',
      icon: Icons.leaderboard_outlined,
    ),
    _QuickPrompt(
      label: 'Orders',
      query: 'Show pending orders',
      icon: Icons.receipt_long_outlined,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadSnapshot();
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadSnapshot() async {
    try {
      final snapshot = await _dataService.loadAssistantSnapshot();
      final intro = _assistant.buildIntro(snapshot);

      if (!mounted) return;
      setState(() {
        _snapshot = snapshot;
        _messages = [
          _ChatMessage(
            text: intro.message,
            isAssistant: true,
            sentAt: DateTime.now(),
          ),
        ];
      });
    } catch (_) {
      if (!mounted) return;
      const snapshot = BusinessSnapshot(
        ownerName: 'Owner',
        storeName: 'My Store',
        todayRevenue: 0,
        todayProfit: 0,
        todayExpenses: 0,
        todayTransactions: 0,
        weeklyRevenue: 0,
        weeklyProfit: 0,
        weeklyExpenses: 0,
        pendingOrders: 0,
        products: [],
        topProducts: [],
      );
      setState(() {
        _snapshot = snapshot;
        _messages = [
          _ChatMessage(
            text:
                'I could not load the latest store data yet. Please check your connection and try again.',
            isAssistant: true,
            sentAt: DateTime.now(),
          ),
        ];
      });
    }
  }

  void _send([String? prompt]) {
    final text = (prompt ?? _inputController.text).trim();
    final snapshot = _snapshot;
    if (text.isEmpty || snapshot == null) return;

    final reply = _assistant.answer(text, snapshot);
    setState(() {
      _messages = [
        ..._messages,
        _ChatMessage(text: text, isAssistant: false, sentAt: DateTime.now()),
        _ChatMessage(
          text: reply.message,
          isAssistant: true,
          sentAt: DateTime.now(),
        ),
      ];
      _inputController.clear();
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    Future<void>.delayed(const Duration(milliseconds: 80), () {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 120,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = _snapshot;

    return Scaffold(
      backgroundColor: OwnerTheme.background,
      appBar: AppBar(
        title: const Text('Store Assistant'),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: OwnerTheme.border),
        ),
      ),
      body: snapshot == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _AssistantSummary(snapshot: snapshot),
                Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: EdgeInsets.fromLTRB(4.w, 1.5.h, 4.w, 1.h),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      return _MessageBubble(message: _messages[index]);
                    },
                  ),
                ),
                _QuickPromptBar(
                  prompts: _quickPrompts,
                  onSelected: _send,
                ),
                _Composer(
                  controller: _inputController,
                  onSend: () => _send(),
                ),
              ],
            ),
    );
  }
}

class _AssistantSummary extends StatelessWidget {
  const _AssistantSummary({required this.snapshot});

  final BusinessSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.fromLTRB(4.w, 1.5.h, 4.w, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: OwnerTheme.border),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: OwnerTheme.accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              color: OwnerTheme.accent,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  snapshot.healthLabel.toUpperCase(),
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: OwnerTheme.accent,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${snapshot.todayTransactions} transactions today',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: OwnerTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'PHP ${_formatAmount(snapshot.todayRevenue)}',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: OwnerTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                'Profit PHP ${_formatAmount(snapshot.todayProfit)}',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: OwnerTheme.textMuted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatAmount(int value) {
    final chars = value.toString().split('').reversed.toList();
    final groups = <String>[];
    for (var i = 0; i < chars.length; i += 3) {
      groups.add(chars.skip(i).take(3).toList().reversed.join());
    }
    return groups.reversed.join(',');
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final _ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final isAssistant = message.isAssistant;
    return Align(
      alignment: isAssistant ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        constraints: BoxConstraints(maxWidth: 78.w),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isAssistant ? Colors.white : OwnerTheme.primary,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(14),
            topRight: const Radius.circular(14),
            bottomLeft: Radius.circular(isAssistant ? 4 : 14),
            bottomRight: Radius.circular(isAssistant ? 14 : 4),
          ),
          border: isAssistant ? Border.all(color: OwnerTheme.border) : null,
        ),
        child: Text(
          message.text,
          style: GoogleFonts.inter(
            fontSize: 13,
            height: 1.35,
            color: isAssistant ? OwnerTheme.textPrimary : Colors.white,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _QuickPromptBar extends StatelessWidget {
  const _QuickPromptBar({
    required this.prompts,
    required this.onSelected,
  });

  final List<_QuickPrompt> prompts;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      alignment: Alignment.centerLeft,
      child: ListView.separated(
        padding: EdgeInsets.symmetric(horizontal: 4.w),
        scrollDirection: Axis.horizontal,
        itemCount: prompts.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final prompt = prompts[index];
          return ActionChip(
            avatar: Icon(prompt.icon, size: 16, color: OwnerTheme.primary),
            label: Text(prompt.label),
            labelStyle: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: OwnerTheme.primary,
            ),
            backgroundColor: OwnerTheme.primary.withValues(alpha: 0.08),
            side: BorderSide(color: OwnerTheme.primary.withValues(alpha: 0.18)),
            onPressed: () => onSelected(prompt.query),
          );
        },
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.onSend,
  });

  final TextEditingController controller;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: EdgeInsets.fromLTRB(4.w, 8, 4.w, 10),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: OwnerTheme.border)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                minLines: 1,
                maxLines: 3,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(),
                style: GoogleFonts.inter(fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Message the assistant',
                  hintStyle: GoogleFonts.inter(
                    fontSize: 14,
                    color: OwnerTheme.textMuted,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 46,
              height: 46,
              child: IconButton.filled(
                onPressed: onSend,
                icon: const Icon(Icons.send_rounded, size: 20),
                style: IconButton.styleFrom(
                  backgroundColor: OwnerTheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatMessage {
  const _ChatMessage({
    required this.text,
    required this.isAssistant,
    required this.sentAt,
  });

  final String text;
  final bool isAssistant;
  final DateTime sentAt;
}

class _QuickPrompt {
  const _QuickPrompt({
    required this.label,
    required this.query,
    required this.icon,
  });

  final String label;
  final String query;
  final IconData icon;
}
