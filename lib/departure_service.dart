import 'dart:convert';
import 'dart:io';

class DepartureService {
  static const String _bridgeScript = 'scripts/fetch_departures_bridge.py';

  const DepartureService();

  Future<List<Map<String, dynamic>>> fetchDepartures(String stopName) async {

    final String pythonExec = Platform.isWindows ? 'python' : 'python3';

    try {
      final result = await Process.run(pythonExec, <String>[_bridgeScript, stopName]);

      if (result.exitCode != 0) {
        // Use 'as dynamic' or 'toString()' to handle both String and List<int>
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

      final decoded = jsonDecode(stdout) as List<dynamic>;
      return decoded
          .map((item) => _normalizeDeparture(Map<String, dynamic>.from(item as Map)))
          .toList();
    } on UnsupportedError {
      rethrow;
    } catch (error) {
      throw StateError('Could not fetch departures for "$stopName": $error');
    }
  }

  Map<String, dynamic> _normalizeDeparture(Map<String, dynamic> raw) {
    final normalized = <String, dynamic>{...raw};

    normalized['line'] = _firstStringValue(raw, const <String>[
      'line',
      'line_name',
      'lineName',
      'line_number',
      'lineNumber',
      'route_short_name',
      'routeShortName',
      'sname',
      'shortName',
      'name',
      'number',
    ], nested: const <List<String>>[
      <String>['serviceJourney', 'line', 'shortName'],
      <String>['serviceJourney', 'line', 'name'],
      <String>['line', 'shortName'],
      <String>['line', 'name'],
      <String>['route', 'shortName'],
      <String>['route', 'name'],
    ]);

    normalized['direction'] = _firstStringValue(raw, const <String>[
      'direction',
      'direction_name',
      'directionName',
      'destination',
      'destination_name',
      'destinationName',
      'headsign',
      'towards',
      'trip_headsign',
      'tripHeadsign',
    ], nested: const <List<String>>[
      <String>['serviceJourney', 'direction'],
      <String>['serviceJourney', 'destination'],
      <String>['trip', 'headsign'],
      <String>['destination', 'name'],
    ]);

    normalized['displayTime'] = _firstStringValue(raw, const <String>[
      'displayTime',
      'display_time',
      'timeDisplay',
      'countdown',
      'rtTime',
    ]);

    normalized['time'] = _firstStringValue(raw, const <String>[
      'time',
      'departureTime',
      'departure_time',
      'scheduledTime',
      'scheduled_time',
      'std',
    ], nested: const <List<String>>[
      <String>['planned', 'time'],
      <String>['estimated', 'time'],
    ]);

    normalized['isCanceled'] = _firstBoolValue(raw, const <String>[
      'isCanceled',
      'is_cancelled',
      'isCancelled',
      'cancelled',
      'canceled',
      'cancelledTrip',
    ]);

    return normalized;
  }

  String? _firstStringValue(
    Map<String, dynamic> source,
    List<String> keys, {
    List<List<String>> nested = const <List<String>>[],
  }) {
    for (final key in keys) {
      final value = _valueForLooseKey(source, key);
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
      if (value is num || value is bool) {
        return value.toString();
      }
    }

    for (final path in nested) {
      final value = _nestedValue(source, path);
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
      if (value is num || value is bool) {
        return value.toString();
      }
    }

    return null;
  }

  bool _firstBoolValue(Map<String, dynamic> source, List<String> keys) {
    for (final key in keys) {
      final value = _valueForLooseKey(source, key);
      if (value is bool) {
        return value;
      }
      if (value is String) {
        final lower = value.toLowerCase().trim();
        if (lower == 'true' || lower == '1' || lower == 'yes') return true;
        if (lower == 'false' || lower == '0' || lower == 'no') return false;
      }
      if (value is num) {
        return value != 0;
      }
    }
    return false;
  }

  dynamic _valueForLooseKey(Map map, String targetKey) {
    if (map.containsKey(targetKey)) {
      return map[targetKey];
    }

    final normalizedTarget = _normalizeKey(targetKey);
    for (final entry in map.entries) {
      if (_normalizeKey(entry.key.toString()) == normalizedTarget) {
        return entry.value;
      }
    }
    return null;
  }

  dynamic _nestedValue(Map<String, dynamic> map, List<String> path) {
    dynamic current = map;
    for (final key in path) {
      if (current is! Map) {
        return null;
      }
      current = _valueForLooseKey(current, key);
      if (current == null) {
        return null;
      }
    }
    return current;
  }

  String _normalizeKey(String key) => key.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
}
