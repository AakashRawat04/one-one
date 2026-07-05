class NotificationResult {
  const NotificationResult({
    required this.notificationEventId,
    required this.eventType,
    required this.sent,
    required this.failed,
    required this.targetDevices,
  });

  final String notificationEventId;
  final String eventType;
  final int sent;
  final int failed;
  final int targetDevices;

  static NotificationResult fromJson(Map<String, dynamic> data) {
    return NotificationResult(
      notificationEventId: data['notificationEventId'].toString(),
      eventType: data['eventType'].toString(),
      sent: _readInt(data['sent']),
      failed: _readInt(data['failed']),
      targetDevices: _readInt(data['targetDevices']),
    );
  }
}

int _readInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
