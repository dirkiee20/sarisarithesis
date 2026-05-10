import '../data/models/product_model.dart';

enum CashierAssistantIntent {
  greeting,
  help,
  createSale,
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

class CashierAssistantReply {
  const CashierAssistantReply({
    required this.intent,
    required this.message,
    this.saleLines = const [],
  });

  final CashierAssistantIntent intent;
  final String message;
  final List<CashierSaleLine> saleLines;

  bool get canOpenCheckout => saleLines.isNotEmpty;

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
          message: 'Hi. I can help prepare sales, check prices, check stock, '
              'and show low-stock items.',
        );
      case CashierAssistantIntent.help:
        return const CashierAssistantReply(
          intent: CashierAssistantIntent.help,
          message: 'Try: "sell 2 coke and 1 skyflakes", "price lucky me", '
              '"stock coffee", "low stock", or "sales today".',
        );
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
          message: 'I can help with sale drafts, prices, stock, low-stock '
              'items, and today sales.',
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
    final summary = lines
        .map((line) =>
            '${line.quantity} x ${line.product.name} (${_money(line.subtotal)})')
        .join(', ');
    final warningText = warnings.isEmpty ? '' : ' ${warnings.join('. ')}.';

    return CashierAssistantReply(
      intent: CashierAssistantIntent.createSale,
      saleLines: lines,
      message: 'I prepared a sale draft: $summary. Total is '
          '${_money(total)}.$warningText Tap Open Checkout to continue.',
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

  int _positiveQuantity(String? value) {
    final quantity = int.tryParse(value ?? '') ?? 1;
    return quantity < 1 ? 1 : quantity;
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
