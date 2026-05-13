import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

import '../../core/app_export.dart';
import '../../core/cashier_assistant.dart';
import '../../data/models/expense_model.dart';
import '../../data/models/product_model.dart';
import '../../services/analytics_service.dart';
import '../../services/expense_service.dart';
import '../../services/file_service.dart';
import '../../services/product_service.dart';
import '../../services/transaction_service.dart';

class CashierAssistantScreen extends StatefulWidget {
  const CashierAssistantScreen({super.key});

  @override
  State<CashierAssistantScreen> createState() => _CashierAssistantScreenState();
}

class _CashierAssistantScreenState extends State<CashierAssistantScreen> {
  final _parser = const CashierAssistantParser();
  final _productService = ProductService();
  final _transactionService = TransactionService();
  final _expenseService = ExpenseService();
  final _analyticsService = AnalyticsService();
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();

  List<ProductModel> _products = [];
  List<_ChatMessage> _messages = const [];
  bool _isLoading = true;
  double _todayRevenue = 0;
  int _todayTransactions = 0;

  static const _quickPrompts = [
    'sell 2 coke cash 100',
    'draft only sell 2 coke',
    'add stock 10 coke',
    'add expense utilities 250',
    'generate sales report today',
    'price lucky me',
  ];

  @override
  void initState() {
    super.initState();
    _loadAssistantContext();
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadAssistantContext({bool resetMessages = true}) async {
    try {
      final products = await _productService.getAllProducts();
      final now = DateTime.now();
      final start = DateTime(now.year, now.month, now.day);
      final end = start.add(const Duration(days: 1));

      double revenue = 0;
      int count = 0;
      try {
        revenue = await _transactionService.getTotalRevenue(start, end);
        count = await _transactionService.getTransactionCount(start, end);
      } catch (_) {
        revenue = 0;
        count = 0;
      }

      if (!mounted) return;
      setState(() {
        _products = products;
        _todayRevenue = revenue;
        _todayTransactions = count;
        _isLoading = false;
        if (resetMessages) {
          _messages = [
            _ChatMessage.assistant(
              'Hi. I can complete sales directly when you include product, '
              'quantity, payment method, and amount received. You can also ask '
              'for draft only, add stock, add expense, generate reports, or '
              'check price and stock.',
            ),
          ];
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        if (resetMessages) {
          _messages = [
            _ChatMessage.assistant(
              'I could not load products yet. Check the local product data, '
              'then try again.',
            ),
          ];
        }
      });
    }
  }

  Future<void> _send([String? prompt]) async {
    final text = (prompt ?? _inputController.text).trim();
    if (text.isEmpty) return;

    final reply = _parser.answer(
      text,
      _products,
      todayRevenue: _todayRevenue,
      todayTransactions: _todayTransactions,
    );

    setState(() {
      _messages = [..._messages, _ChatMessage.user(text)];
      _inputController.clear();
    });

    if (reply.canCompleteSale) {
      await _completeAssistantSale(reply);
    } else if (reply.stockAction?.canExecute == true) {
      await _completeStockAction(reply.stockAction!);
    } else if (reply.expenseAction?.canExecute == true) {
      await _completeExpenseAction(reply.expenseAction!);
    } else if (reply.reportAction != null) {
      await _completeReportAction(reply.reportAction!);
    } else {
      _addAssistantMessage(
        reply.message,
        cartItems: reply.canOpenCheckout ? reply.cartItems : null,
      );
    }
    _scrollToBottom();
  }

  void _addAssistantMessage(
    String message, {
    List<Map<String, dynamic>>? cartItems,
  }) {
    if (!mounted) return;
    setState(() {
      _messages = [
        ..._messages,
        _ChatMessage.assistant(message, cartItems: cartItems),
      ];
    });
  }

  Future<void> _completeAssistantSale(CashierAssistantReply reply) async {
    try {
      await _transactionService.createTransaction(
        reply.cartItems,
        paymentMethod: reply.paymentMethod,
        paymentAmount: reply.paymentAmount,
        notes: 'Created by cashier assistant',
      );
      final total = reply.saleTotal;
      final received = reply.paymentAmount ?? 0;
      await _loadAssistantContext(resetMessages: false);
      _addAssistantMessage(
        'Sale completed. Total: ${_money(total)}. Received: '
        '${_money(received)} via ${reply.paymentMethod}. Change: '
        '${_money(received - total)}. Stock and sales totals were refreshed.',
      );
    } catch (e) {
      _addAssistantMessage('I could not complete the sale: $e');
    }
  }

  Future<void> _completeStockAction(CashierStockAction action) async {
    try {
      final product = action.product;
      final newStock = product.stock + action.quantityToAdd;
      await _productService.adjustStock(
        product.id!,
        newStock,
        'Assistant Stock Add',
        notes: 'Added ${action.quantityToAdd} units through cashier assistant',
      );
      await _loadAssistantContext(resetMessages: false);
      _addAssistantMessage(
        'Stock updated. Added ${action.quantityToAdd} unit'
        '${action.quantityToAdd == 1 ? '' : 's'} to ${product.name}. '
        'New stock: $newStock.',
      );
    } catch (e) {
      _addAssistantMessage('I could not add stock: $e');
    }
  }

  Future<void> _completeExpenseAction(CashierExpenseAction action) async {
    try {
      await _expenseService.createExpense(
        ExpenseModel(
          title: action.title,
          category: action.category,
          amount: action.amount,
          description: 'Created by cashier assistant',
        ),
      );
      await _loadAssistantContext(resetMessages: false);
      _addAssistantMessage(
        'Expense added. ${action.title} under ${action.category}: '
        '${_money(action.amount)}.',
      );
    } catch (e) {
      _addAssistantMessage('I could not add the expense: $e');
    }
  }

  Future<void> _completeReportAction(CashierReportAction action) async {
    try {
      final report = await _buildAssistantReport(action);
      final fileName =
          'assistant_${action.reportType}_${action.period.toLowerCase()}_${DateTime.now().millisecondsSinceEpoch}';
      final path = await FileService.saveReportToFile(report, fileName, 'txt');
      _addAssistantMessage(
        path == null ? report : '$report\n\nSaved report file:\n$path',
      );
    } catch (e) {
      _addAssistantMessage('I could not generate the report: $e');
    }
  }

  Future<String> _buildAssistantReport(CashierReportAction action) async {
    final period = action.period;
    final revenue = await _analyticsService.getRevenueForPeriod(period);
    final profit = await _analyticsService.getProfitForPeriod(period);
    final productCosts =
        await _analyticsService.getProductCostsForPeriod(period);
    final businessExpenses =
        await _analyticsService.getBusinessExpensesForPeriod(period);
    final transactionCount =
        await _analyticsService.getTransactionCountForPeriod(period);
    final margin = revenue == 0 ? 0 : (profit / revenue) * 100;
    final netIncome = profit - businessExpenses;
    final buffer = StringBuffer()
      ..writeln('SariSari Pro Assistant Report')
      ..writeln('Type: ${action.reportType}')
      ..writeln('Period: $period')
      ..writeln('Generated: ${DateTime.now().toLocal()}')
      ..writeln('')
      ..writeln('Sales')
      ..writeln('- Revenue: ${_money(revenue)}')
      ..writeln('- Transactions: $transactionCount')
      ..writeln('- Gross profit: ${_money(profit)}')
      ..writeln('- Gross margin: ${margin.toStringAsFixed(1)}%')
      ..writeln('')
      ..writeln('Expenses')
      ..writeln('- Product cost: ${_money(productCosts)}')
      ..writeln('- Business expenses: ${_money(businessExpenses)}')
      ..writeln('- Net income after business expenses: ${_money(netIncome)}');

    if (action.reportType == 'inventory') {
      final products = await _productService.getAllProducts();
      final lowStock = products.where((product) => product.stock <= 10).toList()
        ..sort((a, b) => a.stock.compareTo(b.stock));
      buffer
        ..writeln('')
        ..writeln('Inventory')
        ..writeln('- Total products: ${products.length}')
        ..writeln('- Low-stock products: ${lowStock.length}');
      for (final product in lowStock.take(8)) {
        buffer.writeln('  - ${product.name}: ${product.stock} left');
      }
    }

    if (action.reportType == 'expense') {
      final categories =
          await _analyticsService.getExpensesByCategoryForPeriod(period);
      buffer
        ..writeln('')
        ..writeln('Expense categories');
      if (categories.isEmpty) {
        buffer.writeln('- No business expenses found.');
      } else {
        for (final entry in categories.entries) {
          buffer.writeln('- ${entry.key}: ${_money(entry.value)}');
        }
      }
    }

    final topProducts = await _analyticsService.getTopProductsForPeriod(period);
    if (topProducts.isNotEmpty) {
      buffer
        ..writeln('')
        ..writeln('Top products');
      for (final product in topProducts.take(5)) {
        buffer.writeln('- ${product['name']}: ${product['quantity']} sold');
      }
    }

    return buffer.toString().trim();
  }

  String _money(num amount) => 'PHP ${amount.toStringAsFixed(2)}';

  Future<void> _openCheckout(List<Map<String, dynamic>> cartItems) async {
    final result = await Navigator.pushNamed(
      context,
      AppRoutes.checkout,
      arguments: {
        'cartOnly': true,
        'cartItems': cartItems,
      },
    );

    if (result == true) {
      await _loadAssistantContext(resetMessages: false);
      if (!mounted) return;
      setState(() {
        _messages = [
          ..._messages,
          _ChatMessage.assistant(
              'Sale completed. Products and totals refreshed.'),
        ];
      });
    }
  }

  void _scrollToBottom() {
    Future<void>.delayed(const Duration(milliseconds: 80), () {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 100,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        title: const Text('Cashier Assistant'),
        backgroundColor: AppTheme.surfaceLight,
        foregroundColor: AppTheme.textPrimaryLight,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _StatusStrip(
                  productCount: _products.length,
                  todayRevenue: _todayRevenue,
                  todayTransactions: _todayTransactions,
                ),
                Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: EdgeInsets.fromLTRB(4.w, 2.h, 4.w, 1.h),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final message = _messages[index];
                      return _MessageBubble(
                        message: message,
                        onOpenCheckout: message.cartItems == null
                            ? null
                            : () => _openCheckout(message.cartItems!),
                      );
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

class _StatusStrip extends StatelessWidget {
  const _StatusStrip({
    required this.productCount,
    required this.todayRevenue,
    required this.todayTransactions,
  });

  final int productCount;
  final double todayRevenue;
  final int todayTransactions;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.fromLTRB(4.w, 1.5.h, 4.w, 0),
      padding: EdgeInsets.all(3.w),
      decoration: BoxDecoration(
        color: AppTheme.surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.dividerLight),
      ),
      child: Row(
        children: [
          _StatusItem(label: 'Products', value: '$productCount'),
          _StatusDivider(),
          _StatusItem(label: 'Today', value: _money(todayRevenue)),
          _StatusDivider(),
          _StatusItem(label: 'Sales', value: '$todayTransactions'),
        ],
      ),
    );
  }

  String _money(num amount) => 'PHP ${amount.toStringAsFixed(0)}';
}

class _StatusItem extends StatelessWidget {
  const _StatusItem({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTheme.lightTheme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimaryLight,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: AppTheme.lightTheme.textTheme.bodySmall?.copyWith(
              color: AppTheme.textSecondaryLight,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 32,
      color: AppTheme.dividerLight,
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    this.onOpenCheckout,
  });

  final _ChatMessage message;
  final VoidCallback? onOpenCheckout;

  @override
  Widget build(BuildContext context) {
    final isAssistant = message.isAssistant;
    return Align(
      alignment: isAssistant ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        constraints: BoxConstraints(maxWidth: 78.w),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isAssistant ? AppTheme.surfaceLight : AppTheme.primaryLight,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(14),
            topRight: const Radius.circular(14),
            bottomLeft: Radius.circular(isAssistant ? 4 : 14),
            bottomRight: Radius.circular(isAssistant ? 14 : 4),
          ),
          border: isAssistant ? Border.all(color: AppTheme.dividerLight) : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message.text,
              style: AppTheme.lightTheme.textTheme.bodyMedium?.copyWith(
                height: 1.35,
                color: isAssistant ? AppTheme.textPrimaryLight : Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (onOpenCheckout != null) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: onOpenCheckout,
                  icon: const Icon(Icons.point_of_sale_rounded, size: 18),
                  label: const Text('Open Checkout'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.successLight,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],
          ],
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

  final List<String> prompts;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 46,
      child: ListView.separated(
        padding: EdgeInsets.symmetric(horizontal: 4.w),
        scrollDirection: Axis.horizontal,
        itemCount: prompts.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final prompt = prompts[index];
          return ActionChip(
            label: Text(prompt),
            labelStyle: AppTheme.lightTheme.textTheme.labelMedium?.copyWith(
              color: AppTheme.primaryLight,
              fontWeight: FontWeight.w700,
            ),
            backgroundColor: AppTheme.primaryLight.withValues(alpha: 0.08),
            side: BorderSide(
                color: AppTheme.primaryLight.withValues(alpha: 0.16)),
            onPressed: () => onSelected(prompt),
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
          color: AppTheme.surfaceLight,
          border: Border(top: BorderSide(color: AppTheme.dividerLight)),
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
                decoration: const InputDecoration(
                  hintText: 'Ask or create a sale',
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
                  backgroundColor: AppTheme.primaryLight,
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
    this.cartItems,
  });

  factory _ChatMessage.assistant(
    String text, {
    List<Map<String, dynamic>>? cartItems,
  }) {
    return _ChatMessage(
      text: text,
      isAssistant: true,
      cartItems: cartItems,
    );
  }

  factory _ChatMessage.user(String text) {
    return _ChatMessage(text: text, isAssistant: false);
  }

  final String text;
  final bool isAssistant;
  final List<Map<String, dynamic>>? cartItems;
}
