import 'package:visaia/services/notification_content.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Dashboard notification presentation preserves authored content', () {
    void check(bool condition, String name) {
      if (!condition) throw StateError(name);
      print('PASS: $name');
    }

    const mao = NotificationContent({
      'type': 'local_administrative_advisory',
      'source': 'LGU-MAO Personnel',
      'risk': 'High',
      'severity': 'Urgent',
      'message': 'Meeting tomorrow',
    });
    check(
      mao.isMao && !mao.isPestAlert && mao.risk.isEmpty,
      'MAO never displays pest risk',
    );
    check(
      mao.priority == 'Urgent' && mao.message == 'Meeting tomorrow',
      'MAO preserves supplied priority and message',
    );
    check(mao.recommendations.isEmpty, 'No generated recommendations');
    const rcpc = NotificationContent({
      'issuingOffice': 'RCPC',
      'notificationKind': 'advisory',
      'risk': 'High',
      'message': 'Training',
    });
    check(
      !rcpc.isPestAlert && rcpc.risk.isEmpty,
      'RCPC advisory hides pest metrics',
    );
    const pest = NotificationContent({
      'issuingOffice': 'RCPC',
      'notificationKind': 'pest_alert',
      'riskLevel': 'Low',
      'mitigationStrategy': 'Officer instructions',
    });
    check(
      pest.risk == 'Low' && pest.recommendations == 'Officer instructions',
      'Explicit risk and recommendations preserved',
    );
    const missing = NotificationContent({'type': 'technical_alert'});
    check(
      missing.risk.isEmpty && missing.recommendations.isEmpty,
      'Missing technical data stays empty',
    );
    const legacy = NotificationContent({'detection': 'FAW', 'risk': 'High'});
    check(
      legacy.isPestAlert && legacy.risk == 'High',
      'Legacy pest alerts supported',
    );
  });
}
