import 'package:flutter_test/flutter_test.dart';
import 'package:one_one_app/features/nudges/data/nudge_repository.dart';

void main() {
  test('all-friends target emits only the scope', () {
    const target = NudgeTarget.allFriends();
    expect(target.json, {'targetScope': 'all_friends'});
    expect(target.query, {'targetScope': 'all_friends'});
  });

  test('single-friend target includes the recipient in JSON and query', () {
    const target = NudgeTarget.singleFriend('friend-123');
    expect(target.json, {
      'targetScope': 'single_friend',
      'targetUserId': 'friend-123',
    });
    expect(target.query, {
      'targetScope': 'single_friend',
      'targetUserId': 'friend-123',
    });
  });
}
