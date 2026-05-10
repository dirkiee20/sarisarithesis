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
}
