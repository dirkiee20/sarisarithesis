class ProductStock {
  const ProductStock({
    required this.name,
    required this.category,
    required this.price,
    required this.stock,
    required this.status,
  });

  final String name;
  final String category;
  final int price;
  final int stock;
  final String status;

  bool get isLowStock => status == 'Low Stock' || (stock > 0 && stock <= 10);
  bool get isOutOfStock => status == 'Out of Stock' || stock == 0;
}

class TopProduct {
  const TopProduct({
    required this.name,
    required this.revenue,
    required this.quantitySold,
  });

  final String name;
  final int revenue;
  final int quantitySold;
}

class BusinessSnapshot {
  const BusinessSnapshot({
    required this.ownerName,
    required this.storeName,
    required this.todayRevenue,
    required this.todayProfit,
    required this.todayExpenses,
    required this.todayTransactions,
    required this.weeklyRevenue,
    required this.weeklyProfit,
    required this.weeklyExpenses,
    required this.pendingOrders,
    required this.products,
    required this.topProducts,
  });

  final String ownerName;
  final String storeName;
  final int todayRevenue;
  final int todayProfit;
  final int todayExpenses;
  final int todayTransactions;
  final int weeklyRevenue;
  final int weeklyProfit;
  final int weeklyExpenses;
  final int pendingOrders;
  final List<ProductStock> products;
  final List<TopProduct> topProducts;

  factory BusinessSnapshot.sample({
    String ownerName = 'Owner',
    String storeName = 'My Store',
  }) {
    return BusinessSnapshot(
      ownerName: ownerName,
      storeName: storeName,
      todayRevenue: 4250,
      todayProfit: 1820,
      todayExpenses: 640,
      todayTransactions: 38,
      weeklyRevenue: 23580,
      weeklyProfit: 9440,
      weeklyExpenses: 3820,
      pendingOrders: 6,
      products: const [
        ProductStock(
          name: 'Lucky Me Spicy',
          category: 'Noodles',
          price: 13,
          stock: 84,
          status: 'In Stock',
        ),
        ProductStock(
          name: 'C2 Green Tea',
          category: 'Beverages',
          price: 20,
          stock: 48,
          status: 'In Stock',
        ),
        ProductStock(
          name: 'Chippy BBQ',
          category: 'Snacks',
          price: 20,
          stock: 9,
          status: 'Low Stock',
        ),
        ProductStock(
          name: 'Bear Brand Milk',
          category: 'Dairy',
          price: 20,
          stock: 32,
          status: 'In Stock',
        ),
        ProductStock(
          name: 'Skyflakes Crackers',
          category: 'Snacks',
          price: 8,
          stock: 0,
          status: 'Out of Stock',
        ),
        ProductStock(
          name: 'Milo 3-in-1',
          category: 'Beverages',
          price: 12,
          stock: 75,
          status: 'In Stock',
        ),
        ProductStock(
          name: 'Marlboro Red',
          category: 'Tobacco',
          price: 7,
          stock: 6,
          status: 'Low Stock',
        ),
        ProductStock(
          name: 'Piattos Original',
          category: 'Snacks',
          price: 25,
          stock: 20,
          status: 'In Stock',
        ),
      ],
      topProducts: const [
        TopProduct(name: 'Lucky Me Spicy', revenue: 640, quantitySold: 32),
        TopProduct(name: 'C2 Green Tea', revenue: 480, quantitySold: 24),
        TopProduct(name: 'Chippy BBQ', revenue: 360, quantitySold: 18),
        TopProduct(name: 'Bear Brand Milk', revenue: 320, quantitySold: 16),
      ],
    );
  }

  double get profitMargin => todayRevenue == 0 ? 0 : todayProfit / todayRevenue;

  List<ProductStock> get lowStockProducts =>
      products.where((product) => product.isLowStock).toList();

  List<ProductStock> get outOfStockProducts =>
      products.where((product) => product.isOutOfStock).toList();

  List<ProductStock> get restockProducts => [
        ...outOfStockProducts,
        ...lowStockProducts,
      ];

  String get healthLabel {
    if (todayRevenue <= 0 || profitMargin < 0.2) {
      return 'needs attention';
    }
    if (restockProducts.length >= 4) {
      return 'steady, with inventory warnings';
    }
    return 'pretty healthy';
  }
}

class AssistantReply {
  const AssistantReply({
    required this.intent,
    required this.message,
  });

  final AssistantIntent intent;
  final String message;
}

enum AssistantIntent {
  greeting,
  businessHealth,
  salesToday,
  profit,
  expenses,
  lowStock,
  restockAdvice,
  topProducts,
  pendingOrders,
  help,
  unknown,
}

class OwnerAssistant {
  const OwnerAssistant();

  AssistantReply buildIntro(BusinessSnapshot snapshot) {
    return AssistantReply(
      intent: AssistantIntent.greeting,
      message: '${_timeGreeting()}, ${snapshot.ownerName}. '
          '${snapshot.storeName} is ${snapshot.healthLabel} today. '
          'You have ${_money(snapshot.todayRevenue)} in revenue, '
          '${_money(snapshot.todayProfit)} profit, and '
          '${snapshot.todayTransactions} transactions. '
          '${_inventoryWatch(snapshot)}',
    );
  }

  AssistantReply answer(String input, BusinessSnapshot snapshot) {
    final intent = _detectIntent(input);
    switch (intent) {
      case AssistantIntent.greeting:
        return buildIntro(snapshot);
      case AssistantIntent.businessHealth:
        return AssistantReply(
          intent: intent,
          message: '${snapshot.storeName} is ${snapshot.healthLabel}. '
              'Today revenue is ${_money(snapshot.todayRevenue)}, '
              'profit is ${_money(snapshot.todayProfit)}, and expenses are '
              '${_money(snapshot.todayExpenses)}. ${_inventoryWatch(snapshot)}',
        );
      case AssistantIntent.salesToday:
        return AssistantReply(
          intent: intent,
          message: 'Today sales are ${_money(snapshot.todayRevenue)} from '
              '${snapshot.todayTransactions} transactions based on the latest '
              'cashier summaries synced to the backend.',
        );
      case AssistantIntent.profit:
        return AssistantReply(
          intent: intent,
          message: 'Today profit is ${_money(snapshot.todayProfit)}. '
              'That is about ${(snapshot.profitMargin * 100).round()}% of '
              'today revenue, which is a healthy margin for the store.',
        );
      case AssistantIntent.expenses:
        return AssistantReply(
          intent: intent,
          message: 'Today expenses are ${_money(snapshot.todayExpenses)}. '
              'This week expenses are ${_money(snapshot.weeklyExpenses)}, '
              'mostly from restocking and utilities.',
        );
      case AssistantIntent.lowStock:
        return AssistantReply(
          intent: intent,
          message: _stockStatus(snapshot),
        );
      case AssistantIntent.restockAdvice:
        return AssistantReply(
          intent: intent,
          message: _restockAdvice(snapshot),
        );
      case AssistantIntent.topProducts:
        return AssistantReply(
          intent: intent,
          message: _topProducts(snapshot),
        );
      case AssistantIntent.pendingOrders:
        return AssistantReply(
          intent: intent,
          message: 'You have ${snapshot.pendingOrders} pending orders. '
              'Handle those before peak hours so the dashboard stays healthy.',
        );
      case AssistantIntent.help:
        return const AssistantReply(
          intent: AssistantIntent.help,
          message: 'You can ask about business health, sales today, profit, '
              'expenses, low stock, restocking, top products, or pending orders.',
        );
      case AssistantIntent.unknown:
        return const AssistantReply(
          intent: AssistantIntent.unknown,
          message: 'I can help with sales, profit, expenses, low stock, '
              'restocking, top products, and pending orders.',
        );
    }
  }

  AssistantIntent detectIntentForTesting(String input) => _detectIntent(input);

  AssistantIntent _detectIntent(String input) {
    final text = _normalize(input);
    if (text.isEmpty) return AssistantIntent.help;

    if (_hasAny(text, const ['help', 'commands', 'what can', 'assist'])) {
      return AssistantIntent.help;
    }
    if (_hasAny(
        text, const ['restock', 'reorder', 'buy more', 'need to buy'])) {
      return AssistantIntent.restockAdvice;
    }
    if (_hasAny(text, const [
      'low stock',
      'out of stock',
      'stock',
      'inventory',
      'running low',
      'ubos',
      'kulang',
    ])) {
      return AssistantIntent.lowStock;
    }
    if (_hasAny(text, const [
      'top',
      'best seller',
      'best selling',
      'sold most',
      'mabenta',
      'popular',
    ])) {
      return AssistantIntent.topProducts;
    }
    if (_hasAny(text, const ['pending', 'order', 'orders', 'delivery'])) {
      return AssistantIntent.pendingOrders;
    }
    if (_hasAny(
        text, const ['expense', 'expenses', 'cost', 'costs', 'gastos'])) {
      return AssistantIntent.expenses;
    }
    if (_hasAny(text, const ['profit', 'margin', 'income', 'tubo', 'kita'])) {
      return AssistantIntent.profit;
    }
    if (_hasAny(
        text, const ['sales', 'revenue', 'benta', 'sold', 'how much'])) {
      return AssistantIntent.salesToday;
    }
    if (_hasAny(text, const [
      'business',
      'healthy',
      'health',
      'status',
      'summary',
      'report',
      'how is',
      'kamusta',
      'kumusta',
    ])) {
      return AssistantIntent.businessHealth;
    }
    if (_hasAny(text, const [
      'good morning',
      'good afternoon',
      'good evening',
      'hello',
      'hi',
      'hey',
    ])) {
      return AssistantIntent.greeting;
    }
    return AssistantIntent.unknown;
  }

  String _stockStatus(BusinessSnapshot snapshot) {
    final lowStock = snapshot.lowStockProducts;
    final outOfStock = snapshot.outOfStockProducts;
    if (lowStock.isEmpty && outOfStock.isEmpty) {
      return 'Inventory looks stable. No products are currently low or out of stock.';
    }

    final parts = <String>[];
    if (outOfStock.isNotEmpty) {
      parts.add('Out of stock: ${_productList(outOfStock)}.');
    }
    if (lowStock.isNotEmpty) {
      parts.add('Low stock: ${_productList(lowStock)}.');
    }
    parts.add('Restock these first to avoid missed sales.');
    return parts.join(' ');
  }

  String _restockAdvice(BusinessSnapshot snapshot) {
    final restock = snapshot.restockProducts;
    if (restock.isEmpty) {
      if (snapshot.topProducts.isEmpty) {
        return 'No urgent restock needed from the latest synced summaries. Sync cashier product summaries to unlock best-seller guidance.';
      }
      return 'No urgent restock needed. Keep monitoring fast-moving products like ${snapshot.topProducts.first.name}.';
    }

    final urgent = restock.take(3).map((product) {
      if (product.isOutOfStock) {
        return '${product.name} is out';
      }
      return '${product.name} has ${product.stock} left';
    }).join(', ');

    return 'Restock priority: $urgent. Start with items that are out of stock, then refill low-stock best sellers.';
  }

  String _topProducts(BusinessSnapshot snapshot) {
    if (snapshot.topProducts.isEmpty) {
      return 'No top product summaries have been synced yet. Ask again after the cashier app uploads sales summaries.';
    }

    final products = snapshot.topProducts.take(3).map((product) {
      return '${product.name} (${product.quantitySold} sold, ${_money(product.revenue)})';
    }).join('; ');
    return 'Top products today: $products.';
  }

  String _inventoryWatch(BusinessSnapshot snapshot) {
    final count = snapshot.restockProducts.length;
    if (count == 0) {
      return 'Inventory looks stable.';
    }
    return 'Watch $count item${count == 1 ? '' : 's'} that may need restocking.';
  }

  String _productList(List<ProductStock> products) {
    return products
        .map((product) => '${product.name} (${product.stock})')
        .join(', ');
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

  String _timeGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 18) return 'Good afternoon';
    return 'Good evening';
  }

  String _money(int amount) => 'PHP ${_withCommas(amount)}';

  String _withCommas(int value) {
    final chars = value.toString().split('').reversed.toList();
    final groups = <String>[];
    for (var i = 0; i < chars.length; i += 3) {
      groups.add(chars.skip(i).take(3).toList().reversed.join());
    }
    return groups.reversed.join(',');
  }
}
