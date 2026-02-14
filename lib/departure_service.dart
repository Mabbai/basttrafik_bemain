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
      return decoded.map((dynamic item) {
        final raw = Map<String, dynamic>.from(item as Map);
        return <String, dynamic>{
          'line': raw['bus'],
          'direction': raw['destination'],
          'wheelchair': raw['wheelchair'],
          'time': raw['time'],
          'displayTime': raw['time'],
          'isCanceled': raw['isCancelled'] == true,
          'bus': raw['bus'],
          'destination': raw['destination'],
          'isCancelled': raw['isCancelled'],
        };
      }).toList();
    } on UnsupportedError {
      rethrow;
    } catch (error) {
      throw StateError('Could not fetch departures for "$stopName": $error');
    }
  }
}
