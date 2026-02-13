import 'dart:convert';
import 'dart:io';

class DepartureService {
  static const String _bridgeScript = 'scripts/fetch_departures_bridge.py';

  const DepartureService();

  Future<List<Map<String, dynamic>>> fetchDepartures(String stopName) async {
    try {
      final result = await Process.run('python3', <String>[_bridgeScript, stopName]);

      if (result.exitCode != 0) {
        final stderr = (result.stderr as String?)?.trim();
        throw ProcessException('python3', <String>[_bridgeScript, stopName], stderr, result.exitCode);
      }

      final stdout = (result.stdout as String).trim();
      if (stdout.isEmpty) {
        return const <Map<String, dynamic>>[];
      }

      final decoded = jsonDecode(stdout) as List<dynamic>;
      return decoded.map((item) => Map<String, dynamic>.from(item as Map)).toList();
    } on UnsupportedError {
      rethrow;
    } catch (error) {
      throw StateError('Could not fetch departures for "$stopName": $error');
    }
  }
}
