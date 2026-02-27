import 'dart:convert';
import 'dart:io';

import '../engines/atlas_engine.dart';
import '../engines/veil_edge_policy.dart';

class PrismJoiner {
  final Directory root; // repo root containing /mcp
  PrismJoiner(this.root);

  /// Join last [daysBack] days (30–90). Writes mcp/fusions/daily/YYYY-MM.jsonl
  Future<void> joinRange({int daysBack = 30, String tz = 'UTC'}) async {
    assert(daysBack >= 30 && daysBack <= 90);
    final now = DateTime.now().toUtc();
    final startDay = DateTime.utc(now.year, now.month, now.day)
        .subtract(Duration(days: daysBack - 1));

    final months = _monthsBetween(startDay, now);
    final health = await _loadByDay('streams/health', months, 'health.timeslice.daily');
    final journal = await _loadByDay('streams/journal', months, 'journal.daily.summary');
    final keywords = await _loadByDay('streams/keywords', months, 'keywords.daily.tally');
    final phase = await _loadByDay('streams/phase', months, 'atlas.phase.daily');
    final chrono = await _loadByDay('streams/chrono', months, 'chrono.daily.tags');

    final outByMonth = <String, IOSink>{};
    try {
      for (int i = 0; i < daysBack; i++) {
        final day = startDay.add(Duration(days: i));
        final dayKey = _key(day);
        final h = health[dayKey];
        if (h == null) continue; // only emit if health exists (anchor stream)

        final fused = _fuse(day, tz, h, journal[dayKey], keywords[dayKey], phase[dayKey], chrono[dayKey]);

        final monthKey = '${day.year}-${day.month.toString().padLeft(2, '0')}';
        final outPath = root.uri.resolve('mcp/fusions/daily/$monthKey.jsonl').toFilePath();
        await File(outPath).create(recursive: true);
        final sink = outByMonth.putIfAbsent(outPath, () => File(outPath).openWrite(mode: FileMode.append));
        sink.writeln(jsonEncode(fused));

        // Also write compact VEIL policy stream
        await _writeVeilPolicy(fused['day_key'] as String, fused['veil_policy'] as Map<String, dynamic>);
      }
    } finally {
      for (final s in outByMonth.values) {
        await s.close();
      }
    }
  }

  Map<String, dynamic> _fuse(
    DateTime day,
    String tz,
    Map<String, dynamic> h,
    Map<String, dynamic>? j,
    Map<String, dynamic>? k,
    Map<String, dynamic>? p,
    Map<String, dynamic>? c,
  ) {
    final metrics = (h['metrics'] as Map<String, dynamic>);
    final derived = (h['derived'] as Map<String, dynamic>? ?? {});

    num? mVal(String key) {
      final v = metrics[key];
      if (v is Map && v.containsKey('value')) return v['value'] as num?;
      if (v is num) return v;
      return null;
    }

    // Raw pulls (null-safe)
    final steps = mVal('steps') ?? 0;
    final activeKcal = mVal('active_energy') ?? 0;
    final basalKcal = mVal('resting_energy') ?? 0;
    final exMin = mVal('exercise_minutes') ?? 0;
    final restHr = mVal('resting_hr');
    final avgHr = mVal('avg_hr');
    final hrv = mVal('hrv_sdnn');
    final rec1m = mVal('cardio_recovery_1min');
    final sleepMin = (metrics['sleep_total_minutes'] ?? 0) as int;
    final standMin = mVal('stand_minutes') ?? 0;
    final workouts = (metrics['workouts'] as List?)?.cast<Map<String, dynamic>>() ?? const [];

    // Simple derived from health
    final recoveryIdx = (derived['recovery_index']?['value'] as num? ?? 0).toDouble();
    final sleepDebtMin = sleepMin - 420; // vs 7h target

    // Stress/readiness features
    double stressHint = 0;
    if (restHr != null) stressHint += ((restHr - 52) / 30).clamp(0, 1);
    if (avgHr != null) stressHint += ((avgHr - 70) / 40).clamp(0, 1);
    if (hrv != null) stressHint += ((40 - hrv) / 40).clamp(0, 1);
    if (sleepDebtMin < 0) stressHint += (-sleepDebtMin / 180).clamp(0, 1);
    if (rec1m != null) {
      final poor = (15 - rec1m).clamp(0, 15) / 15; // smaller drop → more stress
      stressHint += poor;
    }
    stressHint = (stressHint / 5).clamp(0, 1).toDouble();

    final activityBalance = ((activeKcal / (basalKcal + 1)).clamp(0, 2)) / 2;
    final readinessHint = (0.5 * recoveryIdx + 0.35 * (1 - stressHint) + 0.15 * activityBalance)
        .clamp(0, 1)
        .toDouble();

    final workoutCount = workouts.length;
    final workoutMinutes = workouts.fold<int>(0, (s, w) => s + ((w['duration_min'] as num?)?.toInt() ?? 0));
    final workoutEnergy = workouts.fold<double>(0, (s, w) => s + ((w['energy_kcal'] as num?)?.toDouble() ?? 0));

    final dayKey = _key(day);

    final fusedBase = {
      'mcp_version': '1.0',
      'type': 'prism.fusion.daily',
      'day_key': dayKey,
      'timeslice': {
        'start': '${dayKey}T00:00:00Z',
        'end': '${dayKey}T23:59:59Z',
        'tz': tz,
      },
      'phase': {
        'label': p?['phase'],
        'confidence': p?['confidence'],
      },
      'health': {
        'steps': steps,
        'active_energy_kcal': activeKcal,
        'resting_energy_kcal': basalKcal,
        'exercise_min': exMin,
        'resting_hr': restHr,
        'avg_hr': avgHr,
        'hrv_sdnn': hrv,
        'cardio_recovery_1min': rec1m,
        'sleep_min': sleepMin,
        'workout_count': workoutCount,
        'workout_minutes': workoutMinutes,
        'workout_energy_kcal': double.parse(workoutEnergy.toStringAsFixed(1)),
      },
      'journal': {
        'entries': j?['summary']?['entries'],
        'word_count': j?['summary']?['word_count'],
        'valence': j?['sentiment']?['valence'],
        'abstract_register': j?['echo']?['abstract_register'],
      },
      'keywords_top': ((k?['top'] as List?)?.map((e) => e['token'] as String).take(5).toList()) ?? const <String>[],
      'chrono': (c?['tags'] as List?)?.cast<String>() ?? const <String>[],
      'features': {
        'stress_hint': double.parse(stressHint.toStringAsFixed(3)),
        'sleep_debt_min': sleepDebtMin,
        'readiness_hint': double.parse(readinessHint.toStringAsFixed(3)),
        'activity_balance': double.parse(activityBalance.toStringAsFixed(3)),
        'workout_count': workoutCount,
        'workout_minutes': workoutMinutes,
        'workout_energy_kcal': double.parse(workoutEnergy.toStringAsFixed(1)),
        'stand_minutes': standMin,
      },
      'provenance': {
        'sources': [
          'health.timeslice.daily',
          if (j != null) 'journal.daily.summary',
          if (k != null) 'keywords.daily.tally',
          if (p != null) 'atlas.phase.daily',
          if (c != null) 'chrono.daily.tags',
        ],
        'collected_at': DateTime.now().toUtc().toIso8601String(),
      },
    };

    // Enrich with ATLAS and VEIL
    final atlas = AtlasEngine.analyzeDay(fusedBase);
    final veil = VeilEdgePolicy.planDay(fusedBase, atlas);

    fusedBase['atlas'] = atlas;
    fusedBase['veil_policy'] = veil;

    return fusedBase;
  }

  Future<void> _writeVeilPolicy(String dayKey, Map<String, dynamic> veil) async {
    final monthKey = dayKey.substring(0, 7);
    final path = root.uri.resolve('mcp/policies/veil/$monthKey.jsonl').toFilePath();
    await File(path).create(recursive: true);
    final sink = File(path).openWrite(mode: FileMode.append);
    final line = {
      'type': 'veil.policy.daily',
      'day_key': dayKey,
      'source': 'veil-edge',
      'generated_at': DateTime.now().toUtc().toIso8601String(),
      ...veil,
    };
    sink.writeln(jsonEncode(line));
    await sink.close();
  }

  Future<Map<String, Map<String, dynamic>>> _loadByDay(
      String relDir, List<String> months, String expectType) async {
    final map = <String, Map<String, dynamic>>{};
    for (final m in months) {
      final file = root.uri.resolve('mcp/$relDir/$m.jsonl').toFilePath();
      final io = File(file);
      if (!await io.exists()) continue;
      final lines = io.openRead().transform(utf8.decoder).transform(const LineSplitter());
      await for (final line in lines) {
        if (line.trim().isEmpty) continue;
        final obj = jsonDecode(line) as Map<String, dynamic>;
        if (obj['type'] != expectType) continue;
        final key = (obj['fusion_keys']?['day_key'] ?? obj['day_key']) as String?;
        if (key == null) continue;
        map[key] = obj; // last write wins
      }
    }
    return map;
  }

  List<String> _monthsBetween(DateTime a, DateTime b) {
    final list = <String>[];
    var y = a.year, m = a.month;
    while (y < b.year || (y == b.year && m <= b.month)) {
      list.add('$y-${m.toString().padLeft(2, '0')}');
      m++;
      if (m == 13) {
        m = 1;
        y++;
      }
    }
    return list;
  }

  String _key(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}


