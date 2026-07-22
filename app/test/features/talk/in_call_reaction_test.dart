import 'package:flutter_test/flutter_test.dart';
import 'package:one_one_app/features/talk/models/in_call_reaction.dart';

void main() {
  test('chat reactions are hard-capped at twenty characters', () {
    expect(InCallReaction.maxTextLength, 20);
    expect(
      InCallReaction.sanitizeInput('12345678901234567890EXTRA'),
      '12345678901234567890',
    );
  });
}
