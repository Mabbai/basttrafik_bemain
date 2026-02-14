import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'package:flutter/material.dart';

import 'package:flutter/material.dart';

class MapConfig {
  // 1. Keep the constructor const, but remove 'scale' from it
  const MapConfig({
    required this.imageSize, 
    required this.stationsSize
  });

  final Size imageSize;
  final Size stationsSize;

  // 2. Turn 'scale' into a getter. 
  // This moves the math from "Compile-time" to "Runtime"
  double get scale => imageSize.width / stationsSize.width;

  // 3. Now this 'const' is valid because there is no math inside the constructor
  static const MapConfig fallback = MapConfig(
    imageSize: Size(10760, 13146),
    stationsSize: Size(911, 1113),
  );

  static Future<MapConfig> readAsset(String assetPath) async {
    final json = jsonDecode(await rootBundle.loadString(assetPath)) as Map<String, dynamic>;
    final image = json['image'] as Map<String, dynamic>;
    final stations = json['stations'] as Map<String, dynamic>;

    return MapConfig(
      imageSize: Size((image['width'] as num).toDouble(), (image['height'] as num).toDouble()),
      stationsSize: Size((stations['width'] as num).toDouble(), (stations['height'] as num).toDouble()),
    );
  }
}
