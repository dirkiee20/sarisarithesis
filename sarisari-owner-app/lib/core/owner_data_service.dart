import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_client.dart';
import 'owner_assistant.dart';

class OwnerDashboardData {
  const OwnerDashboardData({
    required this.ownerName,
    required this.storeName,
    required this.tier,
    required this.todayRevenue,
    required this.todayProfit,
    required this.todayExpenses,
    required this.todayTransactions,
    required this.kpis,
    required this.weeklyTrend,
    required this.topProducts,
  });

  final String ownerName;
  final String storeName;
  final String tier;
  final double todayRevenue;
  final double todayProfit;
  final double todayExpenses;
  final int todayTransactions;
  final List<Map<String, dynamic>> kpis;
  final List<Map<String, dynamic>> weeklyTrend;
  final List<Map<String, dynamic>> topProducts;
}

class OwnerAnalyticsData {
  const OwnerAnalyticsData({
    required this.revenue,
    required this.profit,
    required this.expenses,
    required this.transactions,
    required this.trend,
    required this.topProducts,
    required this.expenseCategories,
  });

  final double revenue;
  final double profit;
  final double expenses;
  final int transactions;
  final List<Map<String, dynamic>> trend;
  final List<Map<String, dynamic>> topProducts;
  final List<Map<String, dynamic>> expenseCategories;
}

class OwnerExpensesData {
  const OwnerExpensesData({
    required this.todayTotal,
    required this.weekTotal,
    required this.monthTotal,
    required this.expenses,
  });

  final double todayTotal;
  final double weekTotal;
  final double monthTotal;
  final List<Map<String, String>> expenses;
}

class OwnerStaffData {
  const OwnerStaffData({
    required this.totalStaff,
    required this.activeStaff,
    required this.inactiveStaff,
    required this.staff,
  });

  final int totalStaff;
  final int activeStaff;
  final int inactiveStaff;
  final List<Map<String, dynamic>> staff;
}

class OwnerDataService {
  const OwnerDataService();

  Future<OwnerDashboardData> loadDashboard() async {
    final prefs = await SharedPreferences.getInstance();
    final results = await Future.wait<Response<dynamic>>([
      apiClient.get('/summaries/store', queryParameters: {'period': 'today'}),
      apiClient.get('/summaries/store', queryParameters: {'period': 'week'}),
      apiClient.get('/summaries/products',
          queryParameters: {'period': 'today', 'limit': 4}),
    ]);

    final today = _asMap(results[0].data);
    final week = _asMap(results[1].data);
    final topProductsPayload = _asMap(results[2].data);
    final todaySummary = _asMap(today['summary']);

    final revenue = _num(todaySummary['total_revenue']);
    final grossProfit = _num(todaySummary['gross_profit']);
    final expenses = _num(todaySummary['total_expenses']);
    final transactions = _int(todaySummary['transaction_count']);

    return OwnerDashboardData(
      ownerName: prefs.getString('owner_name') ?? 'Owner',
      storeName: prefs.getString('owner_store') ?? 'My Store',
      tier: prefs.getString('owner_tier') ?? 'free',
      todayRevenue: revenue,
      todayProfit: grossProfit,
      todayExpenses: expenses,
      todayTransactions: transactions,
      kpis: [
        {
          'label': 'Today\'s Revenue',
          'value': _money(revenue),
          'change': 'Live',
          'up': true,
        },
        {
          'label': 'Total Profit',
          'value': _money(grossProfit),
          'change': 'Live',
          'up': grossProfit >= 0,
        },
        {
          'label': 'Expenses',
          'value': _money(expenses),
          'change': 'Today',
          'up': false,
        },
        {
          'label': 'Transactions',
          'value': _whole(transactions),
          'change': 'Today',
          'up': true,
        },
      ],
      weeklyTrend: _mapList(week['daily']),
      topProducts: _list(topProductsPayload['products'])
          .map(_productSummaryToTopProduct)
          .toList(),
    );
  }

  Future<OwnerAnalyticsData> loadAnalytics(String period) async {
    final periodKey = period.toLowerCase();
    final results = await Future.wait<Response<dynamic>>([
      apiClient
          .get('/analytics/overview', queryParameters: {'period': periodKey}),
      apiClient.get('/analytics/sales-trend',
          queryParameters: {'period': periodKey}),
      apiClient.get('/analytics/top-products',
          queryParameters: {'period': periodKey, 'limit': 5}),
      apiClient.get('/analytics/expenses-by-category',
          queryParameters: {'period': periodKey}),
    ]);

    final overview = _asMap(results[0].data);
    final trendPayload = _asMap(results[1].data);
    final topProductsPayload = _asMap(results[2].data);
    final expensesPayload = _asMap(results[3].data);
    final kpis = _asMap(overview['kpis']);

    final topProducts = _list(topProductsPayload['topProducts'])
        .map((item) => {
              'name': _string(item['product_name'], fallback: 'Product'),
              'value': _num(item['total_revenue']),
            })
        .toList();

    final expenseCategories = _list(expensesPayload['expensesByCategory'])
        .map((item) => {
              'name': _string(item['category'], fallback: 'General'),
              'value': _num(item['total']),
            })
        .toList();

    return OwnerAnalyticsData(
      revenue: _num(kpis['revenue']),
      profit: _num(kpis['grossProfit']),
      expenses: _num(kpis['businessExpenses']),
      transactions: _int(kpis['transactionCount']),
      trend: _mapList(trendPayload['trend']),
      topProducts: topProducts,
      expenseCategories: expenseCategories,
    );
  }

  Future<List<Map<String, dynamic>>> loadProducts() async {
    final response = await apiClient.get(
      '/summaries/products',
      queryParameters: {'period': 'all', 'limit': 500},
    );
    final payload = _asMap(response.data);
    return _list(payload['products']).map(_productSummaryToProduct).toList();
  }

  Future<OwnerExpensesData> loadExpenses() async {
    final response = await apiClient.get(
      '/summaries/expenses',
      queryParameters: {'period': 'month', 'limit': 50},
    );

    final payload = _asMap(response.data);
    final totals = _asMap(payload['totals']);
    final expenses = _list(payload['expenses']).map((item) {
      final category = _string(item['category'], fallback: 'General');
      final date = _formatDate(item['date']);
      final title = _string(item['title']);
      return {
        'desc': title.isNotEmpty ? title : '$category summary',
        'cat': category,
        'amount': _money(_num(item['amount'])),
        'date': date,
      };
    }).toList();

    return OwnerExpensesData(
      todayTotal: _num(totals['today_total']),
      weekTotal: _num(totals['week_total']),
      monthTotal: _num(totals['month_total']),
      expenses: expenses,
    );
  }

  Future<OwnerStaffData> loadStaff() async {
    final results = await Future.wait<Response<dynamic>>([
      apiClient.get('/users'),
      apiClient.get('/summaries/cashiers', queryParameters: {'period': 'week'}),
    ]);

    final usersPayload = _asMap(results[0].data);
    final cashiersPayload = _asMap(results[1].data);
    final cashierSales = <String, double>{};

    for (final cashier in _list(cashiersPayload['cashiers'])) {
      final userId = _string(cashier['cashier_user_id']);
      if (userId.isNotEmpty) {
        cashierSales[userId] = _num(cashier['total_revenue']);
      }
    }

    final staffUsers = _list(usersPayload['users']).where((user) {
      final role = _string(_asMap(user)['role'], fallback: 'staff');
      return role != 'owner';
    });

    final staff = staffUsers.map((user) {
      final id = _string(user['id']);
      final isActive = user['is_active'] == true;
      final role = _string(user['role'], fallback: 'staff');
      return {
        'name': _string(user['full_name'], fallback: 'Staff member'),
        'email': _string(user['email']),
        'role': _roleLabel(role),
        'status': isActive ? 'Active' : 'Inactive',
        'shift': _lastSeenLabel(user['last_login_at']),
        'sales': _money(cashierSales[id] ?? 0),
      };
    }).toList();

    final active = staff.where((item) => item['status'] == 'Active').length;

    return OwnerStaffData(
      totalStaff: staff.length,
      activeStaff: active,
      inactiveStaff: staff.length - active,
      staff: staff,
    );
  }

  Future<BusinessSnapshot> loadAssistantSnapshot() async {
    final prefs = await SharedPreferences.getInstance();
    final results = await Future.wait<Response<dynamic>>([
      apiClient.get('/summaries/store', queryParameters: {'period': 'today'}),
      apiClient.get('/summaries/store', queryParameters: {'period': 'week'}),
      apiClient.get('/summaries/products',
          queryParameters: {'period': 'all', 'limit': 50}),
    ]);

    final todaySummary = _asMap(_asMap(results[0].data)['summary']);
    final weekSummary = _asMap(_asMap(results[1].data)['summary']);
    final productsPayload = _asMap(results[2].data);
    final products = _list(productsPayload['products']);

    return BusinessSnapshot(
      ownerName: prefs.getString('owner_name') ?? 'Owner',
      storeName: prefs.getString('owner_store') ?? 'My Store',
      todayRevenue: _num(todaySummary['total_revenue']).round(),
      todayProfit: _num(todaySummary['gross_profit']).round(),
      todayExpenses: _num(todaySummary['total_expenses']).round(),
      todayTransactions: _int(todaySummary['transaction_count']),
      weeklyRevenue: _num(weekSummary['total_revenue']).round(),
      weeklyProfit: _num(weekSummary['gross_profit']).round(),
      weeklyExpenses: _num(weekSummary['total_expenses']).round(),
      pendingOrders: 0,
      products: products.map((item) {
        final stock = _int(item['stock_on_hand']);
        final threshold = _int(item['low_stock_threshold']);
        return ProductStock(
          name: _string(item['product_name'], fallback: 'Product'),
          category: _string(item['category'], fallback: 'Uncategorized'),
          price: _num(item['selling_price']).round(),
          stock: stock,
          status: _stockStatus(stock, threshold),
        );
      }).toList(),
      topProducts: products.take(5).map((item) {
        return TopProduct(
          name: _string(item['product_name'], fallback: 'Product'),
          revenue: _num(item['sales_revenue']).round(),
          quantitySold: _int(item['units_sold']),
        );
      }).toList(),
    );
  }

  Map<String, dynamic> _productSummaryToTopProduct(dynamic item) {
    return {
      'name': _string(item['product_name'], fallback: 'Product'),
      'revenue': _money(_num(item['sales_revenue'])),
      'qty': _int(item['units_sold']),
    };
  }

  Map<String, dynamic> _productSummaryToProduct(dynamic item) {
    final stock = _int(item['stock_on_hand']);
    final threshold = _int(item['low_stock_threshold']);
    return {
      'id': _string(item['product_key']),
      'name': _string(item['product_name'], fallback: 'Product'),
      'category': _string(item['category'], fallback: 'Uncategorized'),
      'price': _money(_num(item['selling_price']), decimals: true),
      'stock': stock,
      'status': _stockStatus(stock, threshold),
      'unitsSold': _int(item['units_sold']),
      'revenue': _money(_num(item['sales_revenue'])),
      'profit': _money(_num(item['gross_profit'])),
      'latestSummaryDate': _formatDate(item['latest_summary_date']),
    };
  }

  static Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  static List<dynamic> _list(dynamic value) {
    if (value is List) return value;
    return const [];
  }

  static List<Map<String, dynamic>> _mapList(dynamic value) {
    return _list(value).map(_asMap).toList();
  }

  static String _string(dynamic value, {String fallback = ''}) {
    if (value == null) return fallback;
    final text = value.toString();
    return text.isEmpty ? fallback : text;
  }

  static double _num(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  static int _int(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.round();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static String _money(num value, {bool decimals = false}) {
    final pattern = decimals ? '#,##0.00' : '#,##0';
    return '₱${NumberFormat(pattern).format(value)}';
  }

  static String _whole(num value) => NumberFormat('#,##0').format(value);

  static String _stockStatus(int stock, int threshold) {
    final lowThreshold = threshold > 0 ? threshold : 10;
    if (stock <= 0) return 'Out of Stock';
    if (stock <= lowThreshold) return 'Low Stock';
    return 'In Stock';
  }

  static String _roleLabel(String role) {
    switch (role) {
      case 'owner':
        return 'Owner';
      case 'manager':
        return 'Manager';
      case 'cashier':
        return 'Cashier';
      default:
        return 'Staff';
    }
  }

  static String _lastSeenLabel(dynamic value) {
    if (value == null) return 'No recent login';
    final parsed = DateTime.tryParse(value.toString());
    if (parsed == null) return 'No recent login';
    return 'Last login ${DateFormat('MMM d').format(parsed.toLocal())}';
  }

  static String _formatDate(dynamic value) {
    final parsed = DateTime.tryParse(value?.toString() ?? '');
    if (parsed == null) return '';
    return DateFormat('MMM d').format(parsed.toLocal());
  }

}
