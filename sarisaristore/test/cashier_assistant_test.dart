import 'package:flutter_test/flutter_test.dart';
import 'package:sarisari_pro/core/cashier_assistant.dart';
import 'package:sarisari_pro/data/models/product_model.dart';

void main() {
  const parser = CashierAssistantParser();

  final products = [
    ProductModel(
      id: 1,
      name: 'Coca-Cola Mismo 290ml',
      category: 'Beverages',
      costPrice: 13,
      sellingPrice: 16,
      stock: 10,
    ),
    ProductModel(
      id: 2,
      name: 'SkyFlakes Crackers',
      category: 'Snacks',
      costPrice: 7.5,
      sellingPrice: 10,
      stock: 8,
    ),
    ProductModel(
      id: 3,
      name: 'Nescafe Original Sachet',
      category: 'Beverages',
      costPrice: 6,
      sellingPrice: 8,
      stock: 2,
    ),
  ];

  test('detects and prepares sale draft from natural command', () {
    final reply = parser.answer('sell 2 coke and 1 skyflakes', products);

    expect(reply.intent, CashierAssistantIntent.createSale);
    expect(reply.saleLines, hasLength(2));
    expect(reply.saleLines.first.quantity, 2);
    expect(reply.canOpenCheckout, isTrue);
    expect(reply.message, contains('PHP 42.00'));
  });

  test('prepares direct sale when payment method and amount are included', () {
    final reply = parser.answer('sell 2 coke cash 100', products);

    expect(reply.intent, CashierAssistantIntent.createSale);
    expect(reply.saleLines, hasLength(1));
    expect(reply.canCompleteSale, isTrue);
    expect(reply.canOpenCheckout, isFalse);
    expect(reply.paymentMethod, 'cash');
    expect(reply.paymentAmount, 100);
    expect(reply.message, contains('change'));
  });

  test('keeps sale as draft when cashier asks for draft only', () {
    final reply = parser.answer('draft only sell 2 coke cash 100', products);

    expect(reply.intent, CashierAssistantIntent.createSale);
    expect(reply.draftOnly, isTrue);
    expect(reply.canCompleteSale, isFalse);
    expect(reply.canOpenCheckout, isTrue);
  });

  test('rejects direct sale with insufficient payment', () {
    final reply = parser.answer('sell 2 coke cash 10', products);

    expect(reply.intent, CashierAssistantIntent.createSale);
    expect(reply.canCompleteSale, isFalse);
    expect(reply.message, contains('amount received is only'));
  });

  test('parses add stock command', () {
    final reply = parser.answer('add stock 10 coke', products);

    expect(reply.intent, CashierAssistantIntent.addStock);
    expect(reply.stockAction?.product.name, contains('Coca-Cola'));
    expect(reply.stockAction?.quantityToAdd, 10);
  });

  test('parses add expense command', () {
    final reply =
        parser.answer('add expense utilities 250 electricity bill', products);

    expect(reply.intent, CashierAssistantIntent.addExpense);
    expect(reply.expenseAction?.category, 'utilities');
    expect(reply.expenseAction?.amount, 250);
  });

  test('parses report command', () {
    final reply = parser.answer('generate inventory report today', products);

    expect(reply.intent, CashierAssistantIntent.generateReport);
    expect(reply.reportAction?.reportType, 'inventory');
    expect(reply.reportAction?.period, 'Today');
  });

  test('answers price checks with matched product', () {
    final reply = parser.answer('price coke', products);

    expect(reply.intent, CashierAssistantIntent.priceCheck);
    expect(reply.message, contains('Coca-Cola'));
    expect(reply.message, contains('PHP 16.00'));
  });

  test('lists low-stock products', () {
    final reply = parser.answer('low stock', products);

    expect(reply.intent, CashierAssistantIntent.lowStock);
    expect(reply.message, contains('Nescafe'));
    expect(reply.message, contains('SkyFlakes'));
  });
}
