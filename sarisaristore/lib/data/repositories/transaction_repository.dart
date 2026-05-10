import '../database/database_helper.dart';
import '../dao/transaction_dao.dart';
import '../models/transaction_model.dart';
import '../models/transaction_item_model.dart';

/// Repository for Transaction operations
class TransactionRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  final TransactionDao _transactionDao = TransactionDao();

  /// Create a new transaction with items
  Future<int> createTransaction(
    TransactionModel transaction,
    List<TransactionItemModel> items,
  ) async {
    final db = await _dbHelper.database;

    return await db.transaction((txn) async {
      double totalAmount = 0;
      double totalProfit = 0;
      final resolvedItems = <TransactionItemModel>[];

      for (final item in items) {
        if (item.quantity <= 0) {
          throw Exception('Item quantity must be greater than 0');
        }

        final productRows = await txn.query(
          'products',
          where: 'id = ?',
          whereArgs: [item.productId],
          limit: 1,
        );

        if (productRows.isEmpty) {
          throw Exception('Product not found');
        }

        final product = productRows.first;
        final currentStock = product['stock'] as int;
        if (currentStock < item.quantity) {
          throw Exception(
            'Insufficient stock for ${product['name']}. Available: $currentStock',
          );
        }

        final sellingPrice = (product['selling_price'] as num).toDouble();
        final costPrice = (product['cost_price'] as num).toDouble();
        final subtotal = sellingPrice * item.quantity;
        final profit = (sellingPrice - costPrice) * item.quantity;

        totalAmount += subtotal;
        totalProfit += profit;

        resolvedItems.add(
          TransactionItemModel(
            transactionId: 0,
            productId: item.productId,
            productName: product['name'] as String,
            unitPrice: sellingPrice,
            costPrice: costPrice,
            quantity: item.quantity,
            subtotal: subtotal,
            profit: profit,
          ),
        );

        await txn.update(
          'products',
          {
            'stock': currentStock - item.quantity,
            'updated_at': DateTime.now().toIso8601String(),
          },
          where: 'id = ?',
          whereArgs: [item.productId],
        );
      }

      final paymentAmount = transaction.paymentAmount ?? totalAmount;
      final savedTransaction = TransactionModel(
        transactionNumber: transaction.transactionNumber,
        totalAmount: totalAmount,
        totalProfit: totalProfit,
        transactionDate: transaction.transactionDate,
        notes: transaction.notes,
        paymentMethod: transaction.paymentMethod ?? 'cash',
        paymentAmount: paymentAmount,
        changeAmount: paymentAmount - totalAmount,
        customerName: transaction.customerName,
        customerContact: transaction.customerContact,
        createdAt: transaction.createdAt,
      );

      final transactionId = await txn.insert(
        'transactions',
        savedTransaction.toMap(),
      );

      for (final item in resolvedItems) {
        await txn.insert(
          'transaction_items',
          item.copyWith(transactionId: transactionId).toMap(),
        );
      }

      return transactionId;
    });
  }

  /// Get all transactions
  Future<List<TransactionModel>> getAllTransactions() async {
    return await _transactionDao.getAllTransactions();
  }

  /// Get transaction by ID
  Future<TransactionModel?> getTransactionById(int id) async {
    return await _transactionDao.getTransactionById(id);
  }

  /// Get transactions by date range
  Future<List<TransactionModel>> getTransactionsByDateRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    return await _transactionDao.getTransactionsByDateRange(startDate, endDate);
  }

  /// Get transaction items by transaction ID
  Future<List<TransactionItemModel>> getTransactionItems(
      int transactionId) async {
    return await _transactionDao.getTransactionItems(transactionId);
  }

  /// Get total revenue for a date range
  Future<double> getTotalRevenue(DateTime startDate, DateTime endDate) async {
    return await _transactionDao.getTotalRevenue(startDate, endDate);
  }

  /// Get total profit for a date range
  Future<double> getTotalProfit(DateTime startDate, DateTime endDate) async {
    return await _transactionDao.getTotalProfit(startDate, endDate);
  }

  /// Get transaction count for a date range
  Future<int> getTransactionCount(DateTime startDate, DateTime endDate) async {
    return await _transactionDao.getTransactionCount(startDate, endDate);
  }

  /// Delete transaction
  Future<int> deleteTransaction(int id) async {
    final db = await _dbHelper.database;

    return await db.transaction((txn) async {
      final items = await txn.query(
        'transaction_items',
        where: 'transaction_id = ?',
        whereArgs: [id],
      );

      for (final item in items) {
        await txn.rawUpdate(
          '''
          UPDATE products
          SET stock = stock + ?, updated_at = ?
          WHERE id = ?
          ''',
          [
            item['quantity'] as int,
            DateTime.now().toIso8601String(),
            item['product_id'] as int,
          ],
        );
      }

      await txn.delete(
        'transaction_items',
        where: 'transaction_id = ?',
        whereArgs: [id],
      );

      return await txn.delete(
        'transactions',
        where: 'id = ?',
        whereArgs: [id],
      );
    });
  }
}
