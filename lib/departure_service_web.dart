import 'dart:convert';
import 'dart:html';

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
  final uri = Uri.base.resolve('/api/departures').replace(
    queryParameters: <String, String>{'stop': stopName},
  );

  try {
    final response = await HttpRequest.request(
      uri.toString(),
      method: 'GET',
      requestHeaders: const <String, String>{'Accept': 'application/json'},
    );

    if (response.status != 200) {
      throw StateError('Unexpected status code ${response.status}');
    }

    final body = response.responseText?.trim() ?? '';
    if (body.isEmpty) {
      return const <Map<String, dynamic>>[];
    }

    final decoded = jsonDecode(body) as List<dynamic>;
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
  } catch (error) {
    throw StateError(
      'Could not fetch departures for "$stopName" on web. '
      'Expected backend endpoint GET /api/departures?stop=<name>: $error',
    );
  }
}
