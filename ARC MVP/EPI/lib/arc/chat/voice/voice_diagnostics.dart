import 'dart:collection';

class VoiceDiagnostics {
  final Map<String, int> _timestamps = {};
  final Queue<String> _events = Queue<String>();

  void record(String event) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    _timestamps[event] = timestamp;
    _events.add('$event: ${timestamp}ms');
    if (_events.length > 20) {
      _events.removeFirst();
    }
  }

  int? getTimestamp(String event) => _timestamps[event];

  int? getDuration(String startEvent, String endEvent) {
    final start = _timestamps[startEvent];
    final end = _timestamps[endEvent];
    if (start != null && end != null) {
      return end - start;
    }
    return null;
  }

  List<String> getRecentEvents() => _events.toList();

  void clear() {
    _timestamps.clear();
    _events.clear();
  }

  Map<String, dynamic> toMap() {
    return {
      'timestamps': Map<String, int>.from(_timestamps),
      'recentEvents': _events.toList(),
    };
  }
}

