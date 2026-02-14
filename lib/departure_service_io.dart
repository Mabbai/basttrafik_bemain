import 'dart:convert';
import 'dart:io';

const String _bridgeScript = 'scripts/fetch_departures_bridge.py';
const Map<String, List<String>> _stopAliases = <String, List<String>>{
  'Skolvägen': <String>['Skolvägen, Ale', 'Skolvägen, Partille'],
};

Future<List<Map<String, dynamic>>> fetchDepartures(String stopName) async {
  final stopNames = <String>[stopName, ...?_stopAliases[stopName]];
  final allDepartures = <Map<String, dynamic>>[];

  for (final name in stopNames) {
    allDepartures.addAll(await _fetchDeparturesForStop(name));
  }

  return allDepartures;
}

Future<List<Map<String, dynamic>>> _fetchDeparturesForStop(String stopName) async {
  final String pythonExec = Platform.isWindows ? 'python' : 'python3';

  try {
    final result = await Process.run(pythonExec, <String>[_bridgeScript, stopName]);

    if (result.exitCode != 0) {
      final stderr = result.stderr.toString().trim();

      throw ProcessException(
        pythonExec,
        [_bridgeScript, stopName],
        stderr,
        result.exitCode,
      );
    }

    final stdout = (result.stdout as String).trim();
    if (stdout.isEmpty) {
      return const <Map<String, dynamic>>[];
    }

    final decodedBody = jsonDecode(stdout);
    return _normalizeDepartures(decodedBody);
  } catch (error) {
    throw StateError('Could not fetch departures for "$stopName": $error');
  }
}

List<Map<String, dynamic>> _normalizeDepartures(dynamic decodedBody) {
  final List<dynamic> departures;

  if (decodedBody is List<dynamic>) {
    departures = decodedBody;
  } else if (decodedBody is Map && decodedBody['departures'] is List<dynamic>) {
    departures = decodedBody['departures'] as List<dynamic>;
  } else {
    throw const FormatException('Expected a list of departures or an object with a departures list.');
  }

  return departures.map((dynamic item) {
    final raw = Map<String, dynamic>.from(item as Map);
    final line = raw['line'] ?? raw['bus'] ?? '';
    final direction = raw['direction'] ?? raw['destination'] ?? '';
    final time = raw['displayTime'] ?? raw['time'] ?? '';
    final isCancelled = raw['isCancelled'] == true || raw['isCanceled'] == true;

    return <String, dynamic>{
      'line': line,
      'direction': direction,
      'wheelchair': raw['wheelchair'],
      'time': time,
      'displayTime': time,
      'isCanceled': isCancelled,
      'bus': line,
      'destination': direction,
      'isCancelled': isCancelled,
    };
  }).toList();
}
