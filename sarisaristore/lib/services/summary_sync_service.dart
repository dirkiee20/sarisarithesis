import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/api_client.dart';
import '../data/database/database_helper.dart';

class SummarySyncService {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  Future<bool> syncToday({bool throwOnError = false}) async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = start.add(const Duration(days: 1));
    return syncDateRange(start, end, throwOnError: throwOnError);
  }

  Future<bool> syncDateRange(
    DateTime start,
    DateTime end, {
    bool throwOnError = false,
  }) async {
    try {
      if (!await _hasAuthToken()) {
        return false;
      }

      final payload = await buildSummaryPayload(start, end);
      await apiClient.post('/summaries/cashier', data: payload);
      return true;
    } on DioException catch (e) {
      debugPrint('Summary sync failed: ${e.response?.data ?? e.message}');
      if (throwOnError) rethrow;
      return false;
    } catch (e) {
      debugPrint('Summary sync failed: $e');
      if (throwOnError) rethrow;
      return false;
    }
  }

  Future<Map<String, dynamic>> buildSummaryPayload(
    DateTime start,
    DateTime end,
  ) async {
    final sales = await _getSalesSummary(start, end);
    final expenses = await _getExpenseSummary(start, end);
    final payments = await _getPaymentBreakdown(start, end);
    final inventory = await _getInventorySummary();
    final productSummaries = await _getProductSummaries(start, end);

    return {
      'summaryDate': _dateOnly(start),
      'periodStart': start.toIso8601String(),
      'periodEnd': end.toIso8601String(),
      'currency': 'PHP',
      'sales': sales,
      'expenses': expenses,
      'paymentBreakdown': payments,
      'inventorySummary': inventory,
      'productSummaries': productSummaries,
      'metadata': {
        'source': 'sarisari_store_app',
        'schemaVersion': 1,
      },
    };
  }

  Future<Map<String, dynamic>> _getSalesSummary(
    DateTime start,
    DateTime end,
  ) async {
    final db = await _dbHelper.database;
    final transactionRows = await db.rawQuery(
      '''
      SELECT
        COUNT(*) AS transaction_count,
        COALESCE(SUM(total_amount), 0) AS net_revenue,
        COALESCE(SUM(total_profit), 0) AS gross_profit,
        COALESCE(SUM(total_amount - total_profit), 0) AS total_cost
      FROM transactions t
      WHERE t.transaction_date >= ? AND t.transaction_date < ?
      ''',
      [start.toIso8601String(), end.toIso8601String()],
    );
    final itemRows = await db.rawQuery(
      '''
      SELECT COALESCE(SUM(ti.quantity), 0) AS items_sold_count
      FROM transaction_items ti
      JOIN transactions t ON t.id = ti.transaction_id
      WHERE t.transaction_date >= ? AND t.transaction_date < ?
      ''',
      [start.toIso8601String(), end.toIso8601String()],
    );

    final row = transactionRows.first;
    final netRevenue = _toDouble(row['net_revenue']);
    return {
      'transactionCount': _toInt(row['transaction_count']),
      'itemsSoldCount': _toInt(itemRows.first['items_sold_count']),
      'grossRevenue': netRevenue,
      'netRevenue': netRevenue,
      'totalCost': _toDouble(row['total_cost']),
      'grossProfit': _toDouble(row['gross_profit']),
    };
  }

  Future<Map<String, dynamic>> _getExpenseSummary(
    DateTime start,
    DateTime end,
  ) async {
    final db = await _dbHelper.database;
    final totalRows = await db.rawQuery(
      '''
      SELECT
        COUNT(*) AS expense_count,
        COALESCE(SUM(amount), 0) AS total
      FROM expenses
      WHERE expense_date >= ? AND expense_date < ?
      ''',
      [start.toIso8601String(), end.toIso8601String()],
    );
    final categoryRows = await db.rawQuery(
      '''
      SELECT category, COALESCE(SUM(amount), 0) AS total
      FROM expenses
      WHERE expense_date >= ? AND expense_date < ?
      GROUP BY category
      ''',
      [start.toIso8601String(), end.toIso8601String()],
    );

    final byCategory = <String, double>{};
    for (final row in categoryRows) {
      final category = (row['category'] as String?)?.trim();
      if (category == null || category.isEmpty) continue;
      byCategory[category] = _toDouble(row['total']);
    }

    final total = totalRows.first;
    return {
      'total': _toDouble(total['total']),
      'count': _toInt(total['expense_count']),
      'byCategory': byCategory,
    };
  }

  Future<Map<String, dynamic>> _getPaymentBreakdown(
    DateTime start,
    DateTime end,
  ) async {
    final db = await _dbHelper.database;
    final rows = await db.rawQuery(
      '''
      SELECT
        COALESCE(payment_method, 'cash') AS payment_method,
        COUNT(*) AS transaction_count,
        COALESCE(SUM(total_amount), 0) AS amount
      FROM transactions
      WHERE transaction_date >= ? AND transaction_date < ?
      GROUP BY COALESCE(payment_method, 'cash')
      ''',
      [start.toIso8601String(), end.toIso8601String()],
    );

    final breakdown = <String, Map<String, dynamic>>{};
    for (final row in rows) {
      final method = (row['payment_method'] as String?)?.trim().toLowerCase();
      if (method == null || method.isEmpty) continue;
      breakdown[method] = {
        'amount': _toDouble(row['amount']),
        'transactionCount': _toInt(row['transaction_count']),
      };
    }
    return breakdown;
  }

  Future<Map<String, dynamic>> _getInventorySummary() async {
    final db = await _dbHelper.database;
    final rows = await db.rawQuery('''
      SELECT
        COUNT(*) AS product_count,
        COALESCE(SUM(stock), 0) AS total_units,
        COALESCE(SUM(stock * cost_price), 0) AS inventory_cost_value,
        COALESCE(SUM(stock * selling_price), 0) AS inventory_retail_value,
        SUM(CASE WHEN stock <= 10 THEN 1 ELSE 0 END) AS low_stock_count,
        SUM(CASE WHEN stock = 0 THEN 1 ELSE 0 END) AS out_of_stock_count
      FROM products
    ''');

    final row = rows.first;
    return {
      'productCount': _toInt(row['product_count']),
      'totalUnits': _toInt(row['total_units']),
      'inventoryCostValue': _toDouble(row['inventory_cost_value']),
      'inventoryRetailValue': _toDouble(row['inventory_retail_value']),
      'lowStockCount': _toInt(row['low_stock_count']),
      'outOfStockCount': _toInt(row['out_of_stock_count']),
    };
  }

  Future<List<Map<String, dynamic>>> _getProductSummaries(
    DateTime start,
    DateTime end,
  ) async {
    final db = await _dbHelper.database;
    final rows = await db.rawQuery(
      '''
      SELECT
        p.name AS product_name,
        p.category AS category,
        p.stock AS stock_on_hand,
        p.selling_price AS selling_price,
        COALESCE(SUM(CASE WHEN t.id IS NOT NULL THEN ti.quantity ELSE 0 END), 0) AS units_sold,
        COALESCE(SUM(CASE WHEN t.id IS NOT NULL THEN ti.subtotal ELSE 0 END), 0) AS sales_revenue,
        COALESCE(SUM(CASE WHEN t.id IS NOT NULL THEN ti.profit ELSE 0 END), 0) AS gross_profit,
        MAX(t.transaction_date) AS last_sold_at
      FROM products p
      LEFT JOIN transaction_items ti ON ti.product_id = p.id
      LEFT JOIN transactions t
        ON t.id = ti.transaction_id
       AND t.transaction_date >= ?
       AND t.transaction_date < ?
      GROUP BY p.name, p.category, p.stock, p.selling_price
      ORDER BY sales_revenue DESC, units_sold DESC, p.name ASC
      ''',
      [start.toIso8601String(), end.toIso8601String()],
    );

    return rows.map((row) {
      final productName = (row['product_name'] as String?)?.trim() ?? '';
      final category = (row['category'] as String?)?.trim() ?? '';
      return {
        'productKey': _productKey(productName, category),
        'productName': productName,
        'category': category,
        'stockOnHand': _toInt(row['stock_on_hand']),
        'lowStockThreshold': 10,
        'unitsSold': _toInt(row['units_sold']),
        'salesRevenue': _toDouble(row['sales_revenue']),
        'grossProfit': _toDouble(row['gross_profit']),
        'sellingPrice': _toDouble(row['selling_price']),
        if (row['last_sold_at'] != null) 'lastSoldAt': row['last_sold_at'],
      };
    }).toList();
  }

  Future<bool> _hasAuthToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    return token != null && token.isNotEmpty;
  }

  String _dateOnly(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  String _productKey(String name, String category) {
    return '$name|$category'.toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  }

  int _toInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.round();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  double _toDouble(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }
}
