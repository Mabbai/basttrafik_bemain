import 'dart:convert';
import 'dart:html';

final RegExp _htmlMarkerRegExp = RegExp(r'<\s*(?:!doctype|html|head|body)\b', caseSensitive: false);

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

    if (_looksLikeHtmlResponse(contentType, body)) {
      throw StateError(
        'Backend returned HTML instead of departures JSON from $uri. '
        'Configure /api/departures routing or set --dart-define=DEPARTURES_API_BASE=<origin>.',
      );
    }

    final decodedBody = jsonDecode(body);
    return _normalizeDepartures(decodedBody);
  } on FormatException catch (error) {
    throw StateError('Invalid departures JSON from $uri: $error');
  } catch (error) {
    throw StateError('Could not fetch departures from $uri: $error');
  }
}

bool _looksLikeHtmlResponse(String contentType, String body) {
  if (contentType.toLowerCase().contains('text/html')) {
    return true;
  }

  if (body.startsWith('<')) {
    return _htmlMarkerRegExp.hasMatch(body);
  }

  return false;
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
