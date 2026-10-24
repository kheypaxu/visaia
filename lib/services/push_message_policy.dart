/// Reject deliveries queued before logout or a switch to another farmer.
bool shouldDisplayPush({
  required String? recipientUid,
  required Map<String, dynamic> data,
  required DateTime now,
  required List<String> seen,
}) {
  final eventId = data['eventId'];
  if (recipientUid == null || recipientUid.isEmpty ||
      data['farmerId'] != recipientUid || eventId is! String || eventId.isEmpty ||
      seen.contains(eventId)) return false;
  final expires = int.tryParse(data['expiresAt']?.toString() ?? '');
  return expires != null && now.millisecondsSinceEpoch < expires;
}
