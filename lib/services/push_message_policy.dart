/// Only accounts authenticated and retained on this installation may notify it.
bool shouldDisplayPush({
  required List<String> recipientUids,
  required Map<String, dynamic> data,
  required DateTime now,
  required List<String> seen,
}) {
  final eventId = data['eventId'];
  if (!recipientUids.contains(data['farmerId']) ||
      eventId is! String ||
      eventId.isEmpty ||
      seen.contains(eventId)) {
    return false;
  }
  final expires = int.tryParse(data['expiresAt']?.toString() ?? '');
  return expires != null && now.millisecondsSinceEpoch < expires;
}

({String title, String body}) pushPresentation({
  required Map<String, dynamic> data,
  required String? activeUid,
}) {
  final name = (data['accountName'] as String?)?.trim();
  final label = name == null || name.isEmpty ? 'Saved account' : name;
  if (data['farmerId'] != activeUid) {
    return (
      title: '$label · VISAIA',
      body: 'This account has a new notification. Sign in to view it.',
    );
  }
  return (
    title: '$label · ${data['title'] ?? 'VISAIA'}',
    body: data['body'] as String? ?? '',
  );
}

int pushNotificationId(String eventId) => eventId.codeUnits.fold<int>(
  0,
  (value, unit) => (value * 31 + unit) & 0x7fffffff,
);
