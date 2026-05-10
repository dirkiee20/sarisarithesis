/// Expense model for tracking business expenses
class ExpenseModel {
  final int? id;
  final String? title;
  final String category;
  final double amount;
  final String? description;
  final DateTime expenseDate;
  final DateTime createdAt;

  ExpenseModel({
    this.id,
    this.title,
    required this.category,
    required this.amount,
    this.description,
    DateTime? expenseDate,
    DateTime? createdAt,
  })  : expenseDate = expenseDate ?? DateTime.now(),
        createdAt = createdAt ?? DateTime.now();

  String get displayTitle {
    final normalizedTitle = title?.trim();
    if (normalizedTitle != null && normalizedTitle.isNotEmpty) {
      return normalizedTitle;
    }
    return category;
  }

  /// Convert to Map for database storage
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': displayTitle,
      'category': category,
      'amount': amount,
      'description': description,
      'expense_date': expenseDate.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }

  /// Create from Map (database result)
  factory ExpenseModel.fromMap(Map<String, dynamic> map) {
    final title = map['title'] as String?;
    final category = (map['category'] as String?) ?? title ?? 'General';
    final expenseDateValue = map['expense_date'];
    final createdAtValue = map['created_at'] ?? expenseDateValue;

    return ExpenseModel(
      id: map['id'] is int ? map['id'] as int : null,
      title: title,
      category: category,
      amount: (map['amount'] as num?)?.toDouble() ?? 0,
      description: map['description'] as String?,
      expenseDate: expenseDateValue != null
          ? DateTime.parse(expenseDateValue as String)
          : DateTime.now(),
      createdAt: createdAtValue != null
          ? DateTime.parse(createdAtValue as String)
          : DateTime.now(),
    );
  }

  /// Create a copy with updated fields
  ExpenseModel copyWith({
    int? id,
    String? title,
    String? category,
    double? amount,
    String? description,
    DateTime? expenseDate,
    DateTime? createdAt,
  }) {
    return ExpenseModel(
      id: id ?? this.id,
      title: title ?? this.title,
      category: category ?? this.category,
      amount: amount ?? this.amount,
      description: description ?? this.description,
      expenseDate: expenseDate ?? this.expenseDate,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() {
    return 'ExpenseModel(id: $id, title: $displayTitle, amount: $amount)';
  }
}
