import 'package:uuid/uuid.dart';
import 'package:sqflite/sqflite.dart';
import '../data/database/database_helper.dart';

class SeederService {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  Future<void> seedCashierData() async {
    final db = await _dbHelper.database;
    
    // Check if we already seeded to avoid thousands of transactions
    final count = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM transactions'));
    if (count != null && count > 0) return;

    // Get products to use for seeding
    final products = await db.query('products');
    if (products.isEmpty) return; // Need products synced from backend first

    final now = DateTime.now();
    
    for (int i = 0; i < 30; i++) {
      final date = now.subtract(Duration(days: i));
      
      // 5 transactions per day
      for (int j = 0; j < 5; j++) {
        final txDate = date.add(Duration(hours: 8 + j));
        final txNumber = const Uuid().v4();
        
        final product = products[j % products.length];
        final qty = 2;
        final sellingPrice = (product['selling_price'] as num).toDouble();
        final costPrice = (product['cost_price'] as num).toDouble();
        
        final subtotal = sellingPrice * qty;
        final profit = (sellingPrice - costPrice) * qty;

        final txId = await db.insert('transactions', {
          'transaction_number': txNumber,
          'total_amount': subtotal,
          'total_profit': profit,
          'transaction_date': txDate.toIso8601String(),
          'payment_method': 'cash',
          'payment_amount': subtotal,
          'change_amount': 0.0,
          'created_at': txDate.toIso8601String(),
        });

        await db.insert('transaction_items', {
          'transaction_id': txId,
          'product_id': product['id'],
          'product_name': product['name'],
          'unit_price': sellingPrice,
          'cost_price': costPrice,
          'quantity': qty,
          'subtotal': subtotal,
          'profit': profit,
        });
      }
    }
  }
}
