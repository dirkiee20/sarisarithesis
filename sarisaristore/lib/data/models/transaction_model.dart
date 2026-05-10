/// Transaction model for sales records
class TransactionModel {
  final int? id;
  final String transactionNumber;
  final double totalAmount;
  final double totalProfit;
  final DateTime transactionDate;
  final String? notes;
  final String? paymentMethod;
  final double? paymentAmount;
  final double? changeAmount;
  final String? customerName;
  final String? customerContact;
  final DateTime createdAt;

  TransactionModel({
    this.id,
    String? transactionNumber,
    required this.totalAmount,
    required this.totalProfit,
    DateTime? transactionDate,
    this.notes,
    this.paymentMethod,
    this.paymentAmount,
    this.changeAmount,
    this.customerName,
    this.customerContact,
    DateTime? createdAt,
  })  : transactionNumber = transactionNumber ?? _generateTransactionNumber(),
        transactionDate = transactionDate ?? DateTime.now(),
        createdAt = createdAt ?? DateTime.now();

  static String _generateTransactionNumber() {
    final now = DateTime.now();
    return 'TXN-${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}-${now.millisecondsSinceEpoch.toString().substring(7)}';
  }

  /// Convert to Map for database storage
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'transaction_number': transactionNumber,
      'total_amount': totalAmount,
      'total_profit': totalProfit,
      'transaction_date': transactionDate.toIso8601String(),
      'notes': notes,
      'payment_method': paymentMethod,
      'payment_amount': paymentAmount,
      'change_amount': changeAmount,
      'customer_name': customerName,
      'customer_contact': customerContact,
      'created_at': createdAt.toIso8601String(),
    };
  }

  /// Create from Map (database result)
  factory TransactionModel.fromMap(Map<String, dynamic> map) {
    final paymentAmountValue = map['payment_amount'];
    final changeAmountValue = map['change_amount'];
    final transactionDateValue = map['transaction_date'];
    final createdAtValue = map['created_at'] ?? transactionDateValue;

    return TransactionModel(
      id: map['id'] is int ? map['id'] as int : null,
      transactionNumber: map['transaction_number'] as String?,
      totalAmount: (map['total_amount'] as num?)?.toDouble() ?? 0,
      totalProfit: (map['total_profit'] as num?)?.toDouble() ?? 0,
      transactionDate: transactionDateValue != null
          ? DateTime.parse(transactionDateValue as String)
          : DateTime.now(),
      notes: map['notes'] as String?,
      paymentMethod: map['payment_method'] as String?,
      paymentAmount:
          paymentAmountValue is num ? paymentAmountValue.toDouble() : null,
      changeAmount:
          changeAmountValue is num ? changeAmountValue.toDouble() : null,
      customerName: map['customer_name'] as String?,
      customerContact: map['customer_contact'] as String?,
      createdAt: createdAtValue != null
          ? DateTime.parse(createdAtValue as String)
          : DateTime.now(),
    );
  }

  @override
  String toString() {
    return 'TransactionModel(id: $id, transactionNumber: $transactionNumber, totalAmount: $totalAmount)';
  }
}
