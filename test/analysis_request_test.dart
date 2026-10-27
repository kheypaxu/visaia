import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:visaia/services/api_service.dart';

class _DelayedClient extends http.BaseClient {
  final headers = Completer<http.StreamedResponse>();
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      headers.future;
}

void main() {
  testWidgets('analysis waits beyond 30 seconds for headers and body', (
    tester,
  ) async {
    final client = _DelayedClient();
    final pending = ApiService.awaitAnalysisResponse(
      http.MultipartRequest('POST', Uri.parse('${ApiService.baseUrl}/predict')),
      client: client,
    );
    var completed = false;
    pending.then((_) => completed = true);
    await tester.pump(const Duration(minutes: 2));
    expect(completed, isFalse);
    final body = StreamController<List<int>>();
    client.headers.complete(http.StreamedResponse(body.stream, 200));
    await tester.pump();
    await tester.pump(const Duration(minutes: 2));
    expect(completed, isFalse);
    body.add(utf8.encode('{"analysis":"Complete"}'));
    unawaited(body.close());
    await tester.pump();
    expect(completed, isTrue);
    expect((await pending).body, contains('Complete'));
  });
}
