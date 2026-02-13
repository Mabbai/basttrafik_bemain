import 'dart:io';

import 'package:xml/xml.dart';

void main() async {
  final file = File('assets/images/map.svg');
  final text = await file.readAsString();
  final document = XmlDocument.parse(text);

  final stations = getStationsFromSmallStopLayer(document);

  await File('assets/data/stations.json').writeAsString(
    '[${stations.map((station) => '{"name": "${escapeJson(station.name)}", "location": {"x": ${station.x}, "y": ${station.y}}}').join(',\n')}]',
  );

  print('Wrote ${stations.length} stations to assets/data/stations.json');
}

String escapeJson(String value) {
  return value.replaceAll(r'\\', r'\\\\').replaceAll('"', r'\\"');
}

class ParsedStation {
  const ParsedStation({required this.name, required this.x, required this.y});

  final String name;
  final double x;
  final double y;
}

List<ParsedStation> getStationsFromSmallStopLayer(XmlDocument document) {
  final smallStopLayer = document.findAllElements('g').firstWhere(
    (element) => element.getAttribute('inkscape:label') == 'liten_hållplats',
  );

  final stations = <ParsedStation>[];

  for (final group in smallStopLayer.childElements.where((e) => e.name.local == 'g')) {
    final use = group.childElements.where((e) => e.name.local == 'use').firstOrNull;
    final text = group.childElements.where((e) => e.name.local == 'text').firstOrNull;

    if (use == null || text == null) {
      continue;
    }

    final stopPosition = getUsePosition(document, use, ancestor: group);
    final stopName = extractText(text);

    if (stopName.isEmpty) {
      continue;
    }

    stations.add(ParsedStation(name: stopName, x: stopPosition.$1, y: stopPosition.$2));
  }

  return stations;
}

(double, double) getUsePosition(
  XmlDocument document,
  XmlElement use,
  {XmlElement? ancestor}
) {
  final href = use.getAttribute('xlink:href')?.replaceFirst('#', '');

  if (href == null) {
    return (0, 0);
  }

  final base = document.descendants.whereType<XmlElement>().firstWhere(
    (element) => element.getAttribute('id') == href,
  );

  final baseX = double.tryParse(base.getAttribute('cx') ?? '') ?? 0;
  final baseY = double.tryParse(base.getAttribute('cy') ?? '') ?? 0;

  final useOffset = parseTranslate(use.getAttribute('transform'));
  final groupOffset = ancestor == null ? (0.0, 0.0) : parseTranslate(ancestor.getAttribute('transform'));

  return (baseX + useOffset.$1 + groupOffset.$1, baseY + useOffset.$2 + groupOffset.$2);
}

(double, double) parseTranslate(String? transform) {
  if (transform == null || transform.isEmpty) {
    return (0, 0);
  }

  final match = RegExp(r'translate\(([-\d.]+)[\s,]+([-\d.]+)\)').firstMatch(transform);

  if (match == null) {
    return (0, 0);
  }

  final x = double.tryParse(match.group(1) ?? '') ?? 0;
  final y = double.tryParse(match.group(2) ?? '') ?? 0;

  return (x, y);
}

String extractText(XmlElement textElement) {
  final lines = <String>[];

  for (final tspan in textElement.findElements('tspan')) {
    final value = tspan.innerText.trim();
    if (value.isNotEmpty) {
      lines.add(value);
    }
  }

  if (lines.isNotEmpty) {
    return joinStopNameLines(lines);
  }

  return textElement.innerText.trim();
}

String joinStopNameLines(List<String> lines) {
  if (lines.isEmpty) {
    return '';
  }

  final parts = <String>[lines.first];

  for (var i = 1; i < lines.length; i++) {
    final previous = parts.removeLast();
    final current = lines[i];

    if (previous.endsWith('-')) {
      parts.add('${previous.substring(0, previous.length - 1)}$current');
    } else {
      parts.add('$previous $current');
    }
  }

  return parts.join(' ').replaceAll(RegExp(r'\s+'), ' ').trim();
}
