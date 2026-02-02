import 'dart:io';
import 'dart:math';

import 'package:xml/xml.dart';

class HungarianAlgorithm {
  final int n;
  final List<List<double>> costs;
  late List<double> lx, ly, slack;
  late List<int> matchX, matchY, pre;
  late List<bool> visX, visY;

  HungarianAlgorithm(this.costs) : n = costs.length {
    lx = List.filled(n, 0.0);
    ly = List.filled(n, 0.0);
    slack = List.filled(n, 0.0);
    matchX = List.filled(n, -1);
    matchY = List.filled(n, -1);
    pre = List.filled(n, -1);
    visX = List.filled(n, false);
    visY = List.filled(n, false);
  }

  void _bfs(int startNode) {
    fill(slack, double.infinity);
    fill(visX, false);
    fill(visY, false);
    fill(pre, -1);

    int qHead = 0;
    List<int> queue = [startNode];
    visX[startNode] = true;

    while (true) {
      while (qHead < queue.length) {
        int u = queue[qHead++];
        for (int v = 0; v < n; v++) {
          double delta = costs[u][v] - lx[u] - ly[v];
          if (!visY[v] && delta < slack[v]) {
            slack[v] = delta;
            pre[v] = u;
            if (slack[v] == 0) {
              visY[v] = true;
              if (matchY[v] == -1) {
                _augment(v);
                return;
              }
              int nextX = matchY[v];
              visX[nextX] = true;
              queue.add(nextX);
            }
          }
        }
      }

      // No zero-delta edge found, update labels
      double a = double.infinity;
      for (int j = 0; j < n; j++) {
        if (!visY[j]) a = min(a, slack[j]);
      }

      for (int i = 0; i < n; i++) {
        if (visX[i]) lx[i] += a;
      }
      for (int j = 0; j < n; j++) {
        if (visY[j]) {
          ly[j] -= a;
        } else {
          slack[j] -= a;
        }
      }

      // Check if any new zero-delta edges were created
      for (int j = 0; j < n; j++) {
        if (!visY[j] && slack[j] == 0) {
          visY[j] = true;
          if (matchY[j] == -1) {
            _augment(j);
            return;
          }
          int nextX = matchY[j];
          visX[nextX] = true;
          queue.add(nextX);
        }
      }
    }
  }

  void _augment(int v) {
    while (v != -1) {
      int u = pre[v];
      int nextV = matchX[u];
      matchY[v] = u;
      matchX[u] = v;
      v = nextV;
    }
  }

  List<int> solve() {
    // Initial label reduction for rows
    for (int i = 0; i < n; i++) {
      lx[i] = costs[i].reduce(min);
    }

    for (int i = 0; i < n; i++) {
      _bfs(i);
    }
    return matchX;
  }

  void fill<T>(List<T> list, T value) {
    for (int i = 0; i < list.length; i++) {
      list[i] = value;
    }
  }
}

void main() async {
  File file = File('assets/images/map.svg');

  var text = await file.readAsString();

  final document = XmlDocument.parse(text);
  final locations = getStationLocations(document);
  final names = getStationNames(document);
  final matched = matchLocationWithName(locations, names);
  print(
    "Matched ${matched.length} stations of ${names.length} names and ${locations.length} locations.",
  );
  await File('assets/data/stations.json').writeAsString(
    "[${matched.map((element) => '{"name": "${element.$1}", "location": {"x": ${element.$2}, "y": ${element.$3}}}').join(',\n')}]",
  );
}

List<(double, double)> getStationLocations(XmlDocument document) {
  final regex = RegExp(r"hållplats(.*)");
  final transformRegex = RegExp(r"translate\(([\d.-]+)[\s,]+([\d.-]+)\)");

  // Find all elements with an 'id' matching the regex
  final matches = document.findAllElements('use').where((element) {
    final label = element.getAttribute('inkscape:label');
    return label != null && regex.hasMatch(label);
  });

  List<(double, double)> locations = [];

  for (var element in matches) {
    // Base position
    final baseId = element.getAttribute('xlink:href')?.substring(1);
    final baseElement = document
        .findAllElements('circle')
        .firstWhere((element) => element.getAttribute('id') == baseId);

    double x = double.parse(baseElement.getAttribute('cx') ?? "0");
    double y = double.parse(baseElement.getAttribute('cy') ?? "0");

    // Additional transform
    final transform = element.getAttribute('transform') ?? '';
    final match = transformRegex.firstMatch(transform);

    if (match != null) {
      // group(1) is the first number (x), group(2) is the second (y)
      x += double.parse(match.group(1)!);
      y += double.parse(match.group(2)!);
    }
    locations.add((x, y));
  }
  return locations;
}

List<(String name, double x, double y)> getStationNames(XmlDocument document) {
  final regex = RegExp(r"text(.*)");

  // Find all elements with an 'id' matching the regex
  final matches = document.findAllElements('text').where((element) {
    final id = element.getAttribute('id');
    return id != null && regex.hasMatch(id);
  });

  List<(String name, double x, double y)> names = [];

  for (var element in matches) {
    final name = element.children
        .map((child) => child.firstChild?.value)
        .nonNulls
        .join(" ")
        .replaceAll("- ", "");
    if (name.isEmpty ||
        RegExp(r"X?\d+").hasMatch(name) || // Bus name
        name.startsWith("Mot") ||
        name.startsWith("Linje")) {
      continue;
    }
    final x = element.getAttribute('x')!;
    final y = element.getAttribute('y')!;

    // Avoid duplicates
    if (names.any((element) => element.$1 == name)) continue;

    names.add((name, double.parse(x), double.parse(y)));
  }

  return names;
}

List<(String name, double x, double y)> matchLocationWithName(
  List<(double x, double y)> locations,
  List<(String name, double x, double y)> names,
) {
  int n = max(locations.length, names.length);

  // Initialize matrix with 0 or a very large number for padding
  // If a 'dummy' location is picked, it means that name has no real match.
  List<List<double>> matrix = List.generate(n, (_) => List.filled(n, 0.0));

  for (int i = 0; i < n; i++) {
    for (int j = 0; j < n; j++) {
      if (i < names.length && j < locations.length) {
        double dx = names[i].$2 - locations[j].$1;
        double dy = names[i].$3 - locations[j].$2;
        matrix[i][j] = dx * dx + dy * dy;
      } else {
        // Padding: 0 cost ensures dummy matches don't penalize the total
        matrix[i][j] = 0.0;
      }
    }
  }

  // 2. Run the algorithm
  var hungarian = HungarianAlgorithm(matrix);
  List<int> assignments = hungarian.solve();

  // 3. Return results
  List<(String name, double x, double y)> results = [];
  for (int i = 0; i < names.length; i++) {
    int locIdx = assignments[i];
    if (locIdx < locations.length) {
      results.add((names[i].$1, locations[locIdx].$1, locations[locIdx].$2));
    }
  }
  return results;
}
