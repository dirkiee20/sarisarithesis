import 'dart:async';

import '../data/repositories/transaction_repository.dart';
import '../data/models/transaction_model.dart';
import '../data/models/transaction_item_model.dart';
import 'summary_sync_service.dart';

/// Service for Transaction business logic
class TransactionService {
  final TransactionRepository _transactionRepository = TransactionRepository();
  final SummarySyncService _summarySyncService = SummarySyncService();

  /// Create a new transaction with items
  Future<int> createTransaction(
    List<Map<String, dynamic>> items, {
    String? notes,
    String? paymentMethod,
    double? paymentAmount,
    String? customerName,
    String? customerContact,
  }) async {
    if (items.isEmpty) {
      throw Exception('Transaction must have at least one item');
    }

    final List<TransactionItemModel> transactionItems = items.map((item) {
      return TransactionItemModel(
        transactionId: 0,
        productId: item['productId'] as int,
        productName: '',
        unitPrice: 0.0,
        costPrice: 0.0,
        quantity: item['quantity'] as int,
        subtotal: 0.0,
        profit: 0.0,
      );
    }).toList();

    final transaction = TransactionModel(
      totalAmount: 0.0,
      totalProfit: 0.0,
      notes: notes,
      paymentMethod: paymentMethod,
      paymentAmount: paymentAmount,
      customerName: customerName,
      customerContact: customerContact,
    );

    // The repository resolves prices and updates stock inside one local DB transaction.
    final transactionId = await _transactionRepository.createTransaction(
      transaction,
      transactionItems,
    );

    unawaited(_summarySyncService.syncToday());
    return transactionId;
  }

  /// Get all transactions
  Future<List<TransactionModel>> getAllTransactions() async {
    return await _transactionRepository.getAllTransactions();
  }

  /// Get transaction by ID
  Future<TransactionModel?> getTransactionById(int id) async {
    return await _transactionRepository.getTransactionById(id);
  }

  /// Get transactions by date range
  Future<List<TransactionModel>> getTransactionsByDateRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    return await _transactionRepository.getTransactionsByDateRange(
        startDate, endDate);
  }

  /// Get transaction items by transaction ID
  Future<List<TransactionItemModel>> getTransactionItems(
      int transactionId) async {
    return await _transactionRepository.getTransactionItems(transactionId);
  }

  /// Get total revenue for a date range
  Future<double> getTotalRevenue(DateTime startDate, DateTime endDate) async {
    return await _transactionRepository.getTotalRevenue(startDate, endDate);
  }

  /// Get total profit for a date range
  Future<double> getTotalProfit(DateTime startDate, DateTime endDate) async {
    return await _transactionRepository.getTotalProfit(startDate, endDate);
  }

  /// Get transaction count for a date range
  Future<int> getTransactionCount(DateTime startDate, DateTime endDate) async {
    return await _transactionRepository.getTransactionCount(startDate, endDate);
  }

  /// Delete transaction (with stock restoration)
  Future<int> deleteTransaction(int id) async {
    final result = await _transactionRepository.deleteTransaction(id);
    unawaited(_summarySyncService.syncToday());
    return result;
  }
}
