import 'dart:convert';

/// Ephemeral in-call emoji / short text sent over LiveKit data.
class InCallReaction {
  const InCallReaction({
    required this.id,
    required this.userId,
    required this.displayName,
    required this.text,
    required this.sentAtMs,
  });

  static const topic = 'in_call_reaction';
  static const maxTextLength = 20;

  final String id;
  final String userId;
  final String displayName;
  final String text;
  final int sentAtMs;

  bool get isEmojiOnly {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return false;
    // Rough: short payload with no spaces / letters / digits reads as emoji.
    if (trimmed.length > 8) return false;
    return !RegExp(r'[A-Za-z0-9]').hasMatch(trimmed);
  }

  Map<String, Object?> toJson() => {
        'type': 'reaction',
        'id': id,
        'userId': userId,
        'displayName': displayName,
        'text': text,
        'sentAtMs': sentAtMs,
      };

  List<int> encode() => utf8.encode(jsonEncode(toJson()));

  static InCallReaction? tryParse(List<int> data) {
    try {
      final decoded = jsonDecode(utf8.decode(data));
      if (decoded is! Map) return null;
      if (decoded['type'] != 'reaction') return null;

      final id = decoded['id']?.toString().trim() ?? '';
      final userId = decoded['userId']?.toString().trim() ?? '';
      final text = _sanitizeText(decoded['text']?.toString() ?? '');
      if (id.isEmpty || userId.isEmpty || text.isEmpty) return null;

      final displayName = decoded['displayName']?.toString().trim() ?? '';
      final sentAtRaw = decoded['sentAtMs'];
      final sentAtMs = sentAtRaw is int
          ? sentAtRaw
          : int.tryParse(sentAtRaw?.toString() ?? '') ??
              DateTime.now().millisecondsSinceEpoch;

      return InCallReaction(
        id: id,
        userId: userId,
        displayName: displayName.isEmpty ? 'friend' : displayName,
        text: text,
        sentAtMs: sentAtMs,
      );
    } catch (_) {
      return null;
    }
  }

  static String? sanitizeInput(String raw) {
    final text = _sanitizeText(raw);
    return text.isEmpty ? null : text;
  }

  static String _sanitizeText(String raw) {
    final collapsed = raw.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (collapsed.isEmpty) return '';
    final runes = collapsed.runes;
    if (runes.length <= maxTextLength) return collapsed;
    return String.fromCharCodes(runes.take(maxTextLength));
  }
}
