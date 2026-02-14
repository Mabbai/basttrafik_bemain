import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';

class MapConfig {
  const MapConfig({required this.imageSize, required this.stationsSize}) : scale = imageSize.width / stationsSize.width;

  final Size imageSize;
  final Size stationsSize;
  final double scale;

  static const MapConfig fallback = MapConfig(
    imageSize: Size(10760, 13146),
    stationsSize: Size(911, 1113),
  );

  static Future<MapConfig> readFile(File file) async {
    final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    final image = json['image'] as Map<String, dynamic>;
    final stations = json['stations'] as Map<String, dynamic>;

    return MapConfig(
      imageSize: Size((image['width'] as num).toDouble(), (image['height'] as num).toDouble()),
      stationsSize: Size((stations['width'] as num).toDouble(), (stations['height'] as num).toDouble()),
    );
  }
}
