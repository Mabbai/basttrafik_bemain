import 'dart:io';
import 'dart:math' as math;

import 'package:xml/xml.dart';

void main() async {
  final file = File('assets/images/map.svg');
  final text = await file.readAsString();
  final document = XmlDocument.parse(text);

  final stations = [...getStationsFromSmallStopLayer(document), ...getStationsFromLargeStopLayer(document)];

  await File('assets/data/stations.json').writeAsString(
    '[${stations.map((station) => station.toJson()).join(',\n')}]',
  );

  print('Wrote ${stations.length} stations to assets/data/stations.json');
}

String escapeJson(String value) {
  return value.replaceAll(r'\\', r'\\\\').replaceAll('"', r'\\"');
}

class ParsedStation {
  const ParsedStation({required this.name, required this.x, required this.y, this.radius});

  final String name;
  final double x;
  final double y;
  final double? radius;

  String toJson() {
    final radiusPart = radius == null ? '' : ', "radius": $radius';
    return '{"name": "${escapeJson(name)}", "location": {"x": $x, "y": $y}$radiusPart}';
  }
}

List<ParsedStation> getStationsFromSmallStopLayer(XmlDocument document) {
  final smallStopLayer = document.findAllElements('g').firstWhere(
    (element) => element.getAttribute('inkscape:label') == 'liten_hållplats',
  );

  final stations = <ParsedStation>[];

  for (final group in smallStopLayer.childElements.where((e) => e.name.local == 'g')) {
    final use = group.descendants.whereType<XmlElement>().firstWhereOrNull(
      (e) => e.name.local == 'use' && e.getAttribute('xlink:href') != null,
    );
    final text = group.descendants.whereType<XmlElement>().firstWhereOrNull((e) => e.name.local == 'text');

    if (use == null || text == null) {
      continue;
    }

    final stopPosition = getUsePosition(document, use);
    final stopName = extractText(text);

    if (stopName.isEmpty) {
      continue;
    }

    stations.add(ParsedStation(name: stopName, x: stopPosition.$1, y: stopPosition.$2));
  }

  return stations;
}

List<ParsedStation> getStationsFromLargeStopLayer(XmlDocument document) {
  final largeStopLayer = document.findAllElements('g').firstWhere(
    (element) => element.getAttribute('inkscape:label') == 'stor_hållplats',
  );

  final stations = <ParsedStation>[];

  for (final group in largeStopLayer.childElements.where((e) => e.name.local == 'g')) {
    final circle = group.descendants.whereType<XmlElement>().firstWhereOrNull((e) => e.name.local == 'circle');
    final text = group.descendants.whereType<XmlElement>().firstWhereOrNull((e) => e.name.local == 'text');

    if (circle == null || text == null) {
      continue;
    }

    final stopPosition = getCirclePosition(circle);
    final radius = getCircleRadius(circle, stopPosition.$1, stopPosition.$2);
    final stopName = extractText(text);

    if (stopName.isEmpty) {
      continue;
    }

    stations.add(ParsedStation(name: stopName, x: stopPosition.$1, y: stopPosition.$2, radius: radius));
  }

  return stations;
}

(double, double) getUsePosition(XmlDocument document, XmlElement use) {
  final href = use.getAttribute('xlink:href')?.replaceFirst('#', '');

  if (href == null) {
    return (0, 0);
  }

  final base = document.descendants.whereType<XmlElement>().firstWhere(
    (element) => element.getAttribute('id') == href,
  );

  var x = (double.tryParse(base.getAttribute('cx') ?? '') ?? 0) + (double.tryParse(use.getAttribute('x') ?? '') ?? 0);
  var y = (double.tryParse(base.getAttribute('cy') ?? '') ?? 0) + (double.tryParse(use.getAttribute('y') ?? '') ?? 0);

  final transformChain = [use, ...use.ancestors.whereType<XmlElement>()];

  for (final element in transformChain) {
    (x, y) = applyTransform(element.getAttribute('transform'), x, y);
  }

  return (x, y);
}

(double, double) getCirclePosition(XmlElement circle) {
  var x = double.tryParse(circle.getAttribute('cx') ?? '') ?? 0;
  var y = double.tryParse(circle.getAttribute('cy') ?? '') ?? 0;

  final transformChain = [circle, ...circle.ancestors.whereType<XmlElement>()];

  for (final element in transformChain) {
    (x, y) = applyTransform(element.getAttribute('transform'), x, y);
  }

  return (x, y);
}

double getCircleRadius(XmlElement circle, double centerX, double centerY) {
  final radius = double.tryParse(circle.getAttribute('r') ?? '') ?? 0;
  var edgeX = (double.tryParse(circle.getAttribute('cx') ?? '') ?? 0) + radius;
  var edgeY = double.tryParse(circle.getAttribute('cy') ?? '') ?? 0;

  final transformChain = [circle, ...circle.ancestors.whereType<XmlElement>()];

  for (final element in transformChain) {
    (edgeX, edgeY) = applyTransform(element.getAttribute('transform'), edgeX, edgeY);
  }

  final dx = edgeX - centerX;
  final dy = edgeY - centerY;

  return math.sqrt(dx * dx + dy * dy);
}

(double, double) applyTransform(String? transform, double x, double y) {
  if (transform == null || transform.isEmpty) {
    return (x, y);
  }

  final operations = RegExp(r'(\w+)\(([^)]+)\)').allMatches(transform);

  var currentX = x;
  var currentY = y;

  for (final operation in operations) {
    final name = operation.group(1);
    final args = operation
        .group(2)
        ?.split(RegExp(r'[\s,]+'))
        .where((value) => value.isNotEmpty)
        .map((value) => double.tryParse(value))
        .whereType<double>()
        .toList();

    if (args == null || args.isEmpty) {
      continue;
    }

    switch (name) {
      case 'translate':
        final tx = args[0];
        final ty = args.length >= 2 ? args[1] : 0.0;
        currentX += tx;
        currentY += ty;
        break;
      case 'matrix':
        if (args.length < 6) {
          continue;
        }

        final nextX = args[0] * currentX + args[2] * currentY + args[4];
        final nextY = args[1] * currentX + args[3] * currentY + args[5];
        currentX = nextX;
        currentY = nextY;
        break;
      case 'scale':
        final sx = args[0];
        final sy = args.length >= 2 ? args[1] : sx;
        currentX *= sx;
        currentY *= sy;
        break;
      case 'rotate':
        final angle = args[0] * math.pi / 180;
        final centerX = args.length >= 3 ? args[1] : 0.0;
        final centerY = args.length >= 3 ? args[2] : 0.0;
        final shiftedX = currentX - centerX;
        final shiftedY = currentY - centerY;
        final rotatedX = shiftedX * math.cos(angle) - shiftedY * math.sin(angle);
        final rotatedY = shiftedX * math.sin(angle) + shiftedY * math.cos(angle);
        currentX = rotatedX + centerX;
        currentY = rotatedY + centerY;
        break;
      default:
        continue;
    }
  }

  return (currentX, currentY);
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
