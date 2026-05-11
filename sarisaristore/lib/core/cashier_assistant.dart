import '../data/models/product_model.dart';

enum CashierAssistantIntent {
  greeting,
  help,
  createSale,
  addStock,
  addExpense,
  generateReport,
  priceCheck,
  stockCheck,
  lowStock,
  todaySales,
  unknown,
}

class CashierSaleLine {
  const CashierSaleLine({
    required this.product,
    required this.quantity,
  });

  final ProductModel product;
  final int quantity;

  double get subtotal => product.sellingPrice * quantity;

  Map<String, dynamic> toCartItem() {
    return {
      'productId': product.id,
      'productModel': product,
      'quantity': quantity,
    };
  }
}

class CashierStockAction {
  const CashierStockAction({
    required this.product,
    required this.quantityToAdd,
  });

  final ProductModel product;
  final int quantityToAdd;

  bool get canExecute => product.id != null && quantityToAdd > 0;
}

class CashierExpenseAction {
  const CashierExpenseAction({
    required this.title,
    required this.category,
    required this.amount,
  });

  final String title;
  final String category;
  final double amount;

  bool get canExecute => title.isNotEmpty && category.isNotEmpty && amount > 0;
}

class CashierReportAction {
  const CashierReportAction({
    required this.reportType,
    required this.period,
  });

  final String reportType;
  final String period;
}

class CashierAssistantReply {
  const CashierAssistantReply({
    required this.intent,
    required this.message,
    this.saleLines = const [],
    this.paymentMethod,
    this.paymentAmount,
    this.draftOnly = false,
    this.stockAction,
    this.expenseAction,
    this.reportAction,
  });

  final CashierAssistantIntent intent;
  final String message;
  final List<CashierSaleLine> saleLines;
  final String? paymentMethod;
  final double? paymentAmount;
  final bool draftOnly;
  final CashierStockAction? stockAction;
  final CashierExpenseAction? expenseAction;
  final CashierReportAction? reportAction;

  double get saleTotal {
    return saleLines.fold<double>(0, (sum, line) => sum + line.subtotal);
  }

  bool get canCompleteSale {
    return saleLines.isNotEmpty &&
        !draftOnly &&
        paymentMethod != null &&
        paymentAmount != null &&
        paymentAmount! >= saleTotal;
  }

  bool get canOpenCheckout => saleLines.isNotEmpty && !canCompleteSale;

  List<Map<String, dynamic>> get cartItems {
    return saleLines.map((line) => line.toCartItem()).toList();
  }
}

class CashierAssistantParser {
  const CashierAssistantParser();

  CashierAssistantReply answer(
    String input,
    List<ProductModel> products, {
    double? todayRevenue,
    int? todayTransactions,
  }) {
    final text = _normalize(input);
    final intent = _detectIntent(text, products);

    switch (intent) {
      case CashierAssistantIntent.greeting:
        return const CashierAssistantReply(
          intent: CashierAssistantIntent.greeting,
          message: 'Hi. I can create sales, prepare draft checkouts, add '
              'stock, add expenses, generate reports, check prices, and check '
              'low-stock items.',
        );
      case CashierAssistantIntent.help:
        return const CashierAssistantReply(
          intent: CashierAssistantIntent.help,
          message: 'Try: "sell 2 coke cash 100" to complete a sale, '
              '"draft only sell 2 coke" to open checkout later, '
              '"add stock 10 coke", "add expense utilities 250", '
              '"generate sales report today", "price lucky me", '
              '"stock coffee", "low stock", or "sales today". '
              'Direct sale rules: include product, quantity, payment method, '
              'and amount received.',
        );
      case CashierAssistantIntent.addStock:
        return _addStock(text, products);
      case CashierAssistantIntent.addExpense:
        return _addExpense(text);
      case CashierAssistantIntent.generateReport:
        return _generateReport(text);
      case CashierAssistantIntent.createSale:
        return _createSale(text, products);
      case CashierAssistantIntent.priceCheck:
        return _priceCheck(text, products);
      case CashierAssistantIntent.stockCheck:
        return _stockCheck(text, products);
      case CashierAssistantIntent.lowStock:
        return _lowStock(products);
      case CashierAssistantIntent.todaySales:
        return CashierAssistantReply(
          intent: CashierAssistantIntent.todaySales,
          message: 'Today sales are ${_money(todayRevenue ?? 0)} from '
              '${todayTransactions ?? 0} transaction'
              '${(todayTransactions ?? 0) == 1 ? '' : 's'}.',
        );
      case CashierAssistantIntent.unknown:
        return const CashierAssistantReply(
          intent: CashierAssistantIntent.unknown,
          message: 'I can complete sales, create sale drafts, add stock, add '
              'expenses, generate reports, check prices, check stock, '
              'show low-stock items, and summarize today sales.',
        );
    }
  }

  CashierAssistantIntent detectIntentForTesting(
    String input,
    List<ProductModel> products,
  ) {
    return _detectIntent(_normalize(input), products);
  }

  CashierAssistantReply _createSale(String text, List<ProductModel> products) {
    if (products.isEmpty) {
      return const CashierAssistantReply(
        intent: CashierAssistantIntent.createSale,
        message: 'I cannot prepare a sale yet because products are not loaded.',
      );
    }

    final lines = <CashierSaleLine>[];
    final warnings = <String>[];

    for (final product in products) {
      if (product.id == null) continue;
      final alias = _matchedAlias(text, product);
      if (alias == null) continue;

      final requestedQuantity = _quantityNearAlias(text, alias);
      if (product.stock <= 0) {
        warnings.add('${product.name} is out of stock');
        continue;
      }

      final quantity =
          requestedQuantity > product.stock ? product.stock : requestedQuantity;
      if (requestedQuantity > product.stock) {
        warnings.add(
          '${product.name} only has ${product.stock} in stock, so I used $quantity',
        );
      }

      lines.add(CashierSaleLine(product: product, quantity: quantity));
    }

    if (lines.isEmpty) {
      return CashierAssistantReply(
        intent: CashierAssistantIntent.createSale,
        message: warnings.isEmpty
            ? 'I could not find those products. Try using the product name, '
                'brand, or barcode.'
            : '${warnings.join('. ')}.',
      );
    }

    final total = lines.fold<double>(0, (sum, line) => sum + line.subtotal);
    final draftOnly = _wantsDraftOnly(text);
    final paymentMethod = _paymentMethod(text);
    final paymentAmount = _paymentAmount(text);
    final summary = lines
        .map((line) =>
            '${line.quantity} x ${line.product.name} (${_money(line.subtotal)})')
        .join(', ');
    final warningText = warnings.isEmpty ? '' : ' ${warnings.join('. ')}.';

    if (!draftOnly && paymentMethod != null && paymentAmount != null) {
      if (paymentAmount < total) {
        return CashierAssistantReply(
          intent: CashierAssistantIntent.createSale,
          saleLines: lines,
          paymentMethod: paymentMethod,
          paymentAmount: paymentAmount,
          message: 'I found the sale: $summary. Total payment amount is '
              '${_money(total)}, but amount received is only '
              '${_money(paymentAmount)}. Please enter at least '
              '${_money(total)}, or say "draft only" to prepare checkout '
              'without completing the sale.$warningText',
        );
      }

      return CashierAssistantReply(
        intent: CashierAssistantIntent.createSale,
        saleLines: lines,
        paymentMethod: paymentMethod,
        paymentAmount: paymentAmount,
        message: 'Ready to complete sale: $summary. Total is ${_money(total)}, '
            '$paymentMethod received ${_money(paymentAmount)}, change is '
            '${_money(paymentAmount - total)}.$warningText',
      );
    }

    final ruleHint = draftOnly
        ? 'Tap Open Checkout when you are ready.'
        : 'To complete directly, include payment method and amount received, '
            'for example "sell 2 coke cash 100". You can also say '
            '"draft only" to keep this as checkout draft.';

    return CashierAssistantReply(
      intent: CashierAssistantIntent.createSale,
      saleLines: lines,
      draftOnly: draftOnly,
      message: 'I prepared a sale draft: $summary. Total is '
          '${_money(total)}.$warningText $ruleHint',
    );
  }

  CashierAssistantReply _addStock(String text, List<ProductModel> products) {
    final product = _bestProductMatch(text, products);
    if (product == null) {
      return const CashierAssistantReply(
        intent: CashierAssistantIntent.addStock,
        message: 'Which product should I add stock to? Example: '
            '"add stock 10 coke".',
      );
    }
    if (product.id == null) {
      return CashierAssistantReply(
        intent: CashierAssistantIntent.addStock,
        message:
            '${product.name} cannot be updated because it has no product ID.',
      );
    }

    final alias = _matchedAlias(text, product);
    final quantity = alias == null
        ? _firstPositiveNumber(text)
        : _explicitQuantityNearAlias(text, alias);
    if (quantity == null || quantity <= 0) {
      return CashierAssistantReply(
        intent: CashierAssistantIntent.addStock,
        message: 'How many ${product.name} units should I add? Example: '
            '"add stock 10 ${product.name}".',
      );
    }

    final newStock = product.stock + quantity;
    return CashierAssistantReply(
      intent: CashierAssistantIntent.addStock,
      stockAction: CashierStockAction(
        product: product,
        quantityToAdd: quantity,
      ),
      message: 'Ready to add $quantity unit${quantity == 1 ? '' : 's'} to '
          '${product.name}. Stock will become $newStock.',
    );
  }

  CashierAssistantReply _addExpense(String text) {
    final amount = _paymentAmount(text) ?? _firstMoneyAmount(text);
    final category = _expenseCategory(text);
    final title = _expenseTitle(text, category);

    if (amount == null || amount <= 0) {
      return const CashierAssistantReply(
        intent: CashierAssistantIntent.addExpense,
        message: 'Please include the expense amount. Example: '
            '"add expense utilities 250 electricity bill".',
      );
    }
    if (category == null && title.isEmpty) {
      return const CashierAssistantReply(
        intent: CashierAssistantIntent.addExpense,
        message: 'Please include what the expense is for. Examples: '
            '"add expense rent 3000" or "add expense packaging 120".',
      );
    }

    final resolvedCategory = category ?? 'General';
    final resolvedTitle = title.isEmpty ? resolvedCategory : title;
    return CashierAssistantReply(
      intent: CashierAssistantIntent.addExpense,
      expenseAction: CashierExpenseAction(
        title: resolvedTitle,
        category: resolvedCategory,
        amount: amount,
      ),
      message: 'Ready to add expense: $resolvedTitle, category '
          '$resolvedCategory, amount ${_money(amount)}.',
    );
  }

  CashierAssistantReply _generateReport(String text) {
    final period = _reportPeriod(text);
    final type = _reportType(text);
    return CashierAssistantReply(
      intent: CashierAssistantIntent.generateReport,
      reportAction: CashierReportAction(reportType: type, period: period),
      message: 'Generating $type report for $period.',
    );
  }

  CashierAssistantReply _priceCheck(
    String text,
    List<ProductModel> products,
  ) {
    final product = _bestProductMatch(text, products);
    if (product == null) {
      return const CashierAssistantReply(
        intent: CashierAssistantIntent.priceCheck,
        message: 'Which product price should I check?',
      );
    }

    return CashierAssistantReply(
      intent: CashierAssistantIntent.priceCheck,
      message: '${product.name} sells for ${_money(product.sellingPrice)}. '
          'Current stock: ${product.stock}.',
    );
  }

  CashierAssistantReply _stockCheck(
    String text,
    List<ProductModel> products,
  ) {
    final product = _bestProductMatch(text, products);
    if (product == null) {
      return const CashierAssistantReply(
        intent: CashierAssistantIntent.stockCheck,
        message: 'Which product stock should I check?',
      );
    }

    final status = product.stock == 0
        ? 'out of stock'
        : product.stock <= 10
            ? 'low stock'
            : 'in stock';
    return CashierAssistantReply(
      intent: CashierAssistantIntent.stockCheck,
      message: '${product.name} has ${product.stock} left and is $status.',
    );
  }

  CashierAssistantReply _lowStock(List<ProductModel> products) {
    final lowStock = products.where((product) => product.stock <= 10).toList()
      ..sort((a, b) => a.stock.compareTo(b.stock));

    if (lowStock.isEmpty) {
      return const CashierAssistantReply(
        intent: CashierAssistantIntent.lowStock,
        message: 'No products are low stock right now.',
      );
    }

    final names = lowStock
        .take(5)
        .map((product) => '${product.name} (${product.stock})')
        .join(', ');
    final extra = lowStock.length > 5 ? ' and ${lowStock.length - 5} more' : '';

    return CashierAssistantReply(
      intent: CashierAssistantIntent.lowStock,
      message: 'Low-stock items: $names$extra.',
    );
  }

  CashierAssistantIntent _detectIntent(
    String text,
    List<ProductModel> products,
  ) {
    if (text.isEmpty) return CashierAssistantIntent.help;
    if (_hasAny(text, const ['help', 'commands', 'what can'])) {
      return CashierAssistantIntent.help;
    }
    if (_hasAny(text, const [
      'report',
      'generate report',
      'create report',
      'sales report',
      'profit report',
      'inventory report',
    ])) {
      return CashierAssistantIntent.generateReport;
    }
    if (_hasAny(text, const [
      'add expense',
      'record expense',
      'expense',
      'gastos',
    ])) {
      return CashierAssistantIntent.addExpense;
    }
    if (_hasAny(text, const [
      'add stock',
      'add stocks',
      'restock',
      'increase stock',
      'stock in',
      'refill',
    ])) {
      return CashierAssistantIntent.addStock;
    }
    if (_hasAny(text, const ['hello', 'hi', 'hey', 'good morning'])) {
      return CashierAssistantIntent.greeting;
    }
    if (_hasAny(text, const [
      'sales today',
      'today sales',
      'revenue today',
      'benta today',
      'magkano benta',
    ])) {
      return CashierAssistantIntent.todaySales;
    }
    if (_hasAny(text, const ['low stock', 'running low', 'out of stock'])) {
      return CashierAssistantIntent.lowStock;
    }
    if (_hasAny(text, const ['price', 'presyo', 'magkano'])) {
      return CashierAssistantIntent.priceCheck;
    }
    if (_hasAny(text, const ['stock', 'inventory', 'available', 'ilan'])) {
      return CashierAssistantIntent.stockCheck;
    }
    if (_hasAny(text, const [
          'sell',
          'sale',
          'checkout',
          'add to cart',
          'add ',
          'benta',
          'bili',
        ]) ||
        _looksLikeSale(text, products)) {
      return CashierAssistantIntent.createSale;
    }
    return CashierAssistantIntent.unknown;
  }

  bool _looksLikeSale(String text, List<ProductModel> products) {
    if (!RegExp(r'\d').hasMatch(text)) return false;
    return products.any((product) => _matchedAlias(text, product) != null);
  }

  ProductModel? _bestProductMatch(String text, List<ProductModel> products) {
    ProductModel? bestProduct;
    var bestScore = 0.0;

    for (final product in products) {
      final alias = _matchedAlias(text, product);
      if (alias != null) return product;

      final productTokens = _significantTokens(product.name);
      if (productTokens.isEmpty) continue;
      final matching = productTokens.where((token) => text.contains(token));
      final score = matching.length / productTokens.length;
      if (score > bestScore) {
        bestScore = score;
        bestProduct = product;
      }
    }

    return bestScore >= 0.45 ? bestProduct : null;
  }

  String? _matchedAlias(String text, ProductModel product) {
    final aliases = _aliasesFor(product);
    aliases.sort((a, b) => b.length.compareTo(a.length));
    for (final alias in aliases) {
      if (alias.isEmpty) continue;
      if (RegExp('(^| )${_aliasPattern(alias)}( |\$)').hasMatch(text)) {
        return alias;
      }
    }
    return null;
  }

  List<String> _aliasesFor(ProductModel product) {
    final name = _normalize(product.name);
    final tokens = _significantTokens(product.name);
    final aliases = <String>{name};

    if (product.barcode != null && product.barcode!.trim().isNotEmpty) {
      aliases.add(product.barcode!.trim().toLowerCase());
    }

    if (tokens.isNotEmpty) aliases.add(tokens.first);
    if (tokens.length >= 2) aliases.add('${tokens[0]} ${tokens[1]}');

    if (name.contains('coca') || name.contains('cola')) {
      aliases.addAll(['coke', 'coca cola']);
    }
    if (name.contains('lucky')) {
      aliases.addAll(['lucky me', 'pancit canton', 'canton']);
    }
    if (name.contains('skyflakes') || name.contains('sky flakes')) {
      aliases.addAll(['skyflakes', 'sky flakes']);
    }
    if (name.contains('nescafe') || name.contains('coffee')) {
      aliases.addAll(['coffee', 'kape']);
    }
    if (name.contains('marlboro')) {
      aliases.addAll(['marlboro', 'cigarette', 'sigarilyo']);
    }
    if (name.contains('bear brand')) {
      aliases.addAll(['bear brand', 'milk']);
    }

    aliases.removeWhere((alias) => alias.length < 3);
    return aliases.toList();
  }

  int _quantityNearAlias(String text, String alias) {
    final pattern = _aliasPattern(alias);
    final before = RegExp('(?:^| )(\\d+)\\s*(?:x|pcs?|pieces?)?\\s*$pattern');
    final beforeMatch = before.firstMatch(text);
    if (beforeMatch != null) {
      return _positiveQuantity(beforeMatch.group(1));
    }

    final after = RegExp('$pattern\\s*(?:x\\s*)?(\\d+)');
    final afterMatch = after.firstMatch(text);
    if (afterMatch != null) {
      return _positiveQuantity(afterMatch.group(1));
    }

    return 1;
  }

  int? _explicitQuantityNearAlias(String text, String alias) {
    final pattern = _aliasPattern(alias);
    final before =
        RegExp('(?:^| )(\\d+)\\s*(?:x|pcs?|pieces?|units?)?\\s*$pattern');
    final beforeMatch = before.firstMatch(text);
    if (beforeMatch != null) {
      return _positiveQuantity(beforeMatch.group(1));
    }

    final after = RegExp('$pattern\\s*(?:x\\s*)?(\\d+)');
    final afterMatch = after.firstMatch(text);
    if (afterMatch != null) {
      return _positiveQuantity(afterMatch.group(1));
    }

    return null;
  }

  int _positiveQuantity(String? value) {
    final quantity = int.tryParse(value ?? '') ?? 1;
    return quantity < 1 ? 1 : quantity;
  }

  int? _firstPositiveNumber(String text) {
    final match = RegExp(r'(^| )(\d+)( |$)').firstMatch(text);
    if (match == null) return null;
    return _positiveQuantity(match.group(2));
  }

  bool _wantsDraftOnly(String text) {
    return _hasAny(text, const [
      'draft only',
      'only draft',
      'make draft',
      'prepare draft',
      'open checkout',
      'cart only',
    ]);
  }

  String? _paymentMethod(String text) {
    if (_hasAny(text, const ['gcash', 'g cash'])) return 'gcash';
    if (_hasAny(text, const ['credit', 'utang'])) return 'credit';
    if (_hasAny(text, const ['cash', 'paid', 'received', 'tendered'])) {
      return 'cash';
    }
    return null;
  }

  double? _paymentAmount(String text) {
    final patterns = [
      RegExp(
          r'(?:paid|payment|received|tendered|cash|gcash|credit|amount)\s*(?:php|p)?\s*(\d+(?:\.\d{1,2})?)'),
      RegExp(
          r'(?:php|p)\s*(\d+(?:\.\d{1,2})?)\s*(?:paid|payment|received|tendered|cash|gcash|credit)'),
    ];
    for (final pattern in patterns) {
      final match = pattern.firstMatch(text);
      if (match == null) continue;
      final amount = double.tryParse(match.group(1) ?? '');
      if (amount != null && amount > 0) return amount;
    }
    return null;
  }

  double? _firstMoneyAmount(String text) {
    final match = RegExp(r'(?:php|p)?\s*(\d+(?:\.\d{1,2})?)').firstMatch(text);
    if (match == null) return null;
    final amount = double.tryParse(match.group(1) ?? '');
    return amount != null && amount > 0 ? amount : null;
  }

  String? _expenseCategory(String text) {
    const categories = {
      'restocking': ['restock', 'restocking', 'inventory'],
      'utilities': ['utility', 'utilities', 'electric', 'water', 'bill'],
      'rent': ['rent', 'rental'],
      'staff wages': ['wage', 'salary', 'allowance', 'staff'],
      'transportation': ['transport', 'delivery', 'fare', 'fuel'],
      'packaging': ['packaging', 'plastic', 'bag'],
      'maintenance': ['repair', 'maintenance'],
      'internet/load': ['internet', 'load', 'wifi'],
      'supplies': ['supplies', 'supply'],
      'marketing': ['marketing', 'promo', 'ads'],
    };
    for (final entry in categories.entries) {
      if (entry.value.any((word) => text.contains(word))) return entry.key;
    }
    return null;
  }

  String _expenseTitle(String text, String? category) {
    var cleaned = text
        .replaceAll(
            RegExp(
                r'\b(add|record|expense|expenses|gastos|php|paid|payment|received|cash|gcash|credit)\b'),
            ' ')
        .replaceAll(RegExp(r'\d+(?:\.\d{1,2})?'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (category != null) {
      for (final token in category.split('/')) {
        cleaned = cleaned.replaceAll(token, '').trim();
      }
    }
    return cleaned.isEmpty ? (category ?? '') : _titleCase(cleaned);
  }

  String _reportPeriod(String text) {
    if (text.contains('year')) return 'Year';
    if (text.contains('month')) return 'Month';
    if (text.contains('week')) return 'Week';
    return 'Today';
  }

  String _reportType(String text) {
    if (text.contains('inventory') || text.contains('stock')) {
      return 'inventory';
    }
    if (text.contains('profit') ||
        text.contains('loss') ||
        text.contains('income')) {
      return 'profit';
    }
    if (text.contains('expense') || text.contains('gastos')) {
      return 'expense';
    }
    return 'sales';
  }

  String _titleCase(String value) {
    return value
        .split(' ')
        .where((word) => word.isNotEmpty)
        .map((word) => '${word[0].toUpperCase()}${word.substring(1)}')
        .join(' ');
  }

  List<String> _significantTokens(String value) {
    const ignored = {
      'the',
      'and',
      'with',
      'original',
      'classic',
      'pack',
      'sachet',
      'stick',
      'mismo',
      'white',
    };

    return _normalize(value)
        .split(' ')
        .where((token) => token.length >= 3 && !ignored.contains(token))
        .toList();
  }

  bool _hasAny(String text, List<String> keywords) {
    return keywords.any((keyword) => text.contains(keyword));
  }

  String _normalize(String input) {
    return input
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  String _aliasPattern(String alias) {
    return RegExp.escape(alias).replaceAll(r'\ ', r'\s+');
  }

  String _money(num amount) => 'PHP ${amount.toStringAsFixed(2)}';
}
