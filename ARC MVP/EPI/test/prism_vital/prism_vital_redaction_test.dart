import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/mira/store/mcp/schema/mcp_redaction_policy.dart';

void main() {
  test('timestamp clamping to date_only', () {
    final p = McpRedactionPolicy(timestampPrecision: 'date_only');
    final t = DateTime.utc(2025, 1, 2, 13, 45, 10);
    final clamped = p.clampTimestamp(t);
    expect(clamped.hour, 0);
    expect(clamped.minute, 0);
  });

  test('quantization buckets', () {
    final p = McpRedactionPolicy(quantizeVitals: true);
    expect(p.quantizeHr(67), 60);
    expect(p.quantizeHrv(25), 20);
    expect(p.quantizeHrv(45), 45);
    expect(p.quantizeHrv(80), 70);
  });
}


