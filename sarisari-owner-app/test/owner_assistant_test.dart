import 'package:flutter_test/flutter_test.dart';
import 'package:sarisari_owner/core/owner_assistant.dart';

void main() {
  const assistant = OwnerAssistant();
  final snapshot = BusinessSnapshot.sample(
    ownerName: 'Maria',
    storeName: 'Maria Store',
  );

  test('detects sales intent from common owner question', () {
    expect(
      assistant.detectIntentForTesting('How much sales today?'),
      AssistantIntent.salesToday,
    );
  });

  test('answers low stock questions with affected products', () {
    final reply = assistant.answer('What products are low stock?', snapshot);

    expect(reply.intent, AssistantIntent.lowStock);
    expect(reply.message, contains('Chippy BBQ'));
    expect(reply.message, contains('Marlboro Red'));
    expect(reply.message, contains('Skyflakes Crackers'));
  });

  test('builds introductory health message with owner and store name', () {
    final reply = assistant.buildIntro(snapshot);

    expect(reply.message, contains('Maria'));
    expect(reply.message, contains('Maria Store'));
    expect(reply.message, contains('pretty healthy'));
  });

  test('health answer compares expenses against profit and margin', () {
    const tightSnapshot = BusinessSnapshot(
      ownerName: 'Maria',
      storeName: 'Maria Store',
      todayRevenue: 3000,
      todayProfit: 1000,
      todayExpenses: 1400,
      todayTransactions: 20,
      weeklyRevenue: 12000,
      weeklyProfit: 4200,
      weeklyExpenses: 5200,
      pendingOrders: 0,
      products: [],
      topProducts: [],
    );

    final reply = assistant.answer('Is my business healthy?', tightSnapshot);

    expect(reply.intent, AssistantIntent.businessHealth);
    expect(reply.message, contains('needs attention'));
    expect(reply.message, contains('net income'));
    expect(reply.message, contains('Expenses are higher than gross profit'));
  });

  test('expense answer explains expense ratio', () {
    final reply = assistant.answer('Are my expenses okay?', snapshot);

    expect(reply.intent, AssistantIntent.expenses);
    expect(reply.message, contains('of today revenue'));
    expect(reply.message, contains('Expenses are not eating too much'));
  });
}
