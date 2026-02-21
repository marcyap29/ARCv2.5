import 'dart:io';
import 'dart:convert';

import 'package:my_app/prism/models/health_summary.dart';

Future<void> appendHealthSummaryLine(HealthSummary summary, {String? dir}) async {
  final d = summary.startIso.toUtc();
  final monthKey = "${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}";
  final base = dir ?? 'mcp/streams/health';
  final file = File('$base/$monthKey.jsonl');
  await file.create(recursive: true);
  final sink = file.openWrite(mode: FileMode.append);
  sink.writeln(summary.toMcpJsonLine());
  await sink.close();
}

Future<void> appendHealthLinkLine(HealthLinkRecord link, {String? dir}) async {
  final d = DateTime.now().toUtc();
  final monthKey = "${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}";
  final base = dir ?? 'mcp/streams/health';
  final file = File('$base/${monthKey}_links.jsonl');
  await file.create(recursive: true);
  final sink = file.openWrite(mode: FileMode.append);
  sink.writeln(jsonEncode(link.toMcpJson()));
  await sink.close();
}


