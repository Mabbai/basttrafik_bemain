import 'dart:io';
import 'dart:math' as math;

import 'package:xml/xml.dart';

void main() async {
  final svgFile = File('assets/images/map.svg');
  final pngFile = File('assets/images/map.png');
  final jpgFile = File('assets/images/map.jpg');

  final text = await svgFile.readAsString();
  final document = XmlDocument.parse(text);

  final stations = [...getStationsFromSmallStopLayer(document), ...getStationsFromLargeStopLayer(document)];
  final stationsCanvasSize = getStationsCanvasSize(document);
  final pngSize = await readPngSize(pngFile);
  final jpgSize = await readJpegSize(jpgFile);

  if (pngSize.$1 != jpgSize.$1 || pngSize.$2 != jpgSize.$2) {
    throw StateError(
      'map.png (${pngSize.$1}x${pngSize.$2}) and map.jpg (${jpgSize.$1}x${jpgSize.$2}) must have matching dimensions.',
    );
  }

  final scale = pngSize.$1 / stationsCanvasSize.$1;

  await File('assets/data/stations.json').writeAsString(
    '[${stations.map((station) => station.toJson()).join(',\n')}]',
  );

  await File('assets/data/map_config.json').writeAsString(
    '{"image": {"width": ${pngSize.$1}, "height": ${pngSize.$2}}, '
    '"stations": {"width": ${stationsCanvasSize.$1}, "height": ${stationsCanvasSize.$2}}, '
    '"scale": $scale}',
  );

  print('Wrote ${stations.length} stations to assets/data/stations.json');
  print('Wrote map configuration to assets/data/map_config.json');
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

  var skolvagenCount = 0;

  for (final group in smallStopLayer.childElements.where((e) => e.name.local == 'g')) {
    final use = group.descendants.whereType<XmlElement>().firstWhereOrNull(
      (e) => e.name.local == 'use' && e.getAttribute('xlink:href') != null,
    );
    final text = group.descendants.whereType<XmlElement>().firstWhereOrNull((e) => e.name.local == 'text');

    if (use == null || text == null) {
      continue;
    }

    final stopPosition = getUsePosition(document, use);
    var stopName = extractText(text);

    if (stopName == 'Skolvägen') {
      if (skolvagenCount == 0) {
        stopName = 'Skolvägen, Ale';
      } else if (skolvagenCount == 1) {
        stopName = 'Skolvägen, Partille';
      }
      skolvagenCount += 1;
    }

    if (stopName.isEmpty) {
      continue;
    }

    stations.add(ParsedStation(name: stopName, x: stopPosition.$1, y: stopPosition.$2));
  }

  return stations;
}

(double, double) getStationsCanvasSize(XmlDocument document) {
  final svg = document.rootElement;
  final viewBox = svg.getAttribute('viewBox');

  if (viewBox != null) {
    final values = viewBox
        .split(RegExp(r'\s+'))
        .where((v) => v.isNotEmpty)
        .map(double.tryParse)
        .whereType<double>()
        .toList();

    if (values.length == 4) {
      return (values[2], values[3]);
    }
  }

  final width = parseSvgLength(svg.getAttribute('width'));
  final height = parseSvgLength(svg.getAttribute('height'));

  if (width > 0 && height > 0) {
    return (width, height);
  }

  throw StateError('Could not determine SVG canvas size.');
}

double parseSvgLength(String? value) {
  if (value == null || value.isEmpty) {
    return 0;
  }

  return double.tryParse(value.replaceAll(RegExp(r'[^0-9\.-]'), '')) ?? 0;
}

Future<(double, double)> readPngSize(File file) async {
  final bytes = await file.readAsBytes();

  if (bytes.length < 24 || String.fromCharCodes(bytes.sublist(1, 4)) != 'PNG') {
    throw StateError('Invalid PNG file: ${file.path}');
  }

  final width = readUint32BigEndian(bytes, 16);
  final height = readUint32BigEndian(bytes, 20);
  return (width.toDouble(), height.toDouble());
}

Future<(double, double)> readJpegSize(File file) async {
  final bytes = await file.readAsBytes();

  if (bytes.length < 4 || bytes[0] != 0xFF || bytes[1] != 0xD8) {
    throw StateError('Invalid JPEG file: ${file.path}');
  }

  var index = 2;
  while (index + 9 < bytes.length) {
    if (bytes[index] != 0xFF) {
      index += 1;
      continue;
    }

    final marker = bytes[index + 1];
    index += 2;

    if (marker == 0xD8 || marker == 0xD9 || (marker >= 0xD0 && marker <= 0xD7)) {
      continue;
    }

    if (index + 1 >= bytes.length) {
      break;
    }

    final segmentLength = (bytes[index] << 8) | bytes[index + 1];
    if (segmentLength < 2 || index + segmentLength > bytes.length) {
      break;
    }

    final isSofMarker = marker == 0xC0 ||
        marker == 0xC1 ||
        marker == 0xC2 ||
        marker == 0xC3 ||
        marker == 0xC5 ||
        marker == 0xC6 ||
        marker == 0xC7 ||
        marker == 0xC9 ||
        marker == 0xCA ||
        marker == 0xCB ||
        marker == 0xCD ||
        marker == 0xCE ||
        marker == 0xCF;

    if (isSofMarker && segmentLength >= 7) {
      final height = (bytes[index + 3] << 8) | bytes[index + 4];
      final width = (bytes[index + 5] << 8) | bytes[index + 6];
      return (width.toDouble(), height.toDouble());
    }

    index += segmentLength;
  }

  throw StateError('Could not locate JPEG dimensions in: ${file.path}');
}

int readUint32BigEndian(List<int> bytes, int offset) {
  return (bytes[offset] << 24) |
      (bytes[offset + 1] << 16) |
      (bytes[offset + 2] << 8) |
      bytes[offset + 3];
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
