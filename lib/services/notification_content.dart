/// Presentation rules shared by the inbox and notification details.
class NotificationContent {
  final Map<String, dynamic> data;
  const NotificationContent(this.data);
  String text(String key) => (data[key] ?? '').toString().trim();
  String get office {
    final explicit = text('issuingOffice').toUpperCase();
    if (explicit == 'MAO' || explicit == 'RCPC') return explicit;
    final legacy =
        '${text('source')} ${text('sender')} ${text('issuer')} ${text('type')} ${text('category')}'
            .toLowerCase();
    if (legacy.contains('mao') ||
        legacy.contains('local_administrative') ||
        legacy.contains('local_advisory'))
      return 'MAO';
    if (legacy.contains('rcpc') || legacy.contains('technical')) return 'RCPC';
    return '';
  }

  bool get isMao => office == 'MAO';
  bool get isPestAlert {
    if (isMao) return false;
    if (text('notificationKind').isNotEmpty)
      return text('notificationKind') == 'pest_alert';
    final type = text('type').toLowerCase();
    if (type.contains('advisory') || type.contains('administrative'))
      return false;
    return type.contains('technical') ||
        type.contains('pest_outbreak') ||
        text('category').toLowerCase().contains('pest outbreak') ||
        (text('detection').isNotEmpty && text('risk').isNotEmpty);
  }

  String get label => isMao
      ? 'MAO · Local Advisory'
      : office == 'RCPC'
      ? (isPestAlert ? 'RCPC · Pest Alert' : 'RCPC · Advisory')
      : isPestAlert
      ? 'Pest Alert'
      : 'Advisory';
  String get risk => isPestAlert
      ? (text('riskLevel').isNotEmpty ? text('riskLevel') : text('risk'))
      : '';
  String get priority =>
      text('priority').isNotEmpty ? text('priority') : text('severity');
  String get message =>
      text('message').isNotEmpty ? text('message') : text('description');
  String get recommendations => text('mitigationStrategy');
}
