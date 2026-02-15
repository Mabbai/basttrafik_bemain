import 'dart:convert';
import 'dart:html';

const String _departuresApiBase = String.fromEnvironment('DEPARTURES_API_BASE');

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
  final baseUri = _departuresApiBase.isEmpty ? Uri.base : Uri.parse(_departuresApiBase);
  final uri = baseUri.resolve('/api/departures').replace(
    queryParameters: <String, String>{'stop': stopName},
  );

  try {
    final response = await HttpRequest.request(
      uri.toString(),
      method: 'GET',
      requestHeaders: const <String, String>{'Accept': 'application/json'},
    );

    if (response.status != 200) {
      throw StateError('Unexpected status code ${response.status} from $uri');
    }

    final contentType = response.getResponseHeader('content-type') ?? '';
    final body = response.responseText?.trim() ?? '';
    if (body.isEmpty) {
      return const <Map<String, dynamic>>[];
    }

    if (contentType.contains('text/html') || body.startsWith('<!DOCTYPE html')) {
      throw StateError(
        'Received HTML instead of JSON from $uri. '
        'This usually means /api/departures is not routed to a backend in web mode. '
        'Current content-type: $contentType',
      );
    }

    final decodedBody = jsonDecode(body);
    return _normalizeDepartures(decodedBody);
  } catch (error) {
    throw StateError(
      'Could not fetch departures for "$stopName" on web. '
      'Expected backend endpoint GET /api/departures?stop=<name>. '
      'You can override the API host with --dart-define=DEPARTURES_API_BASE=<origin>: $error',
    );
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
