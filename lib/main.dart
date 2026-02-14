import 'dart:io';

import 'package:basttrafik/map_config.dart';
import 'package:basttrafik/map_page.dart';
import 'package:basttrafik/station.dart';
import 'package:flutter/material.dart';

List<Station> stations = [];
MapConfig mapConfig = MapConfig.fallback;

void main() async {
  stations = await Station.readFile(File("assets/data/stations.json"));

  final mapConfigFile = File('assets/data/map_config.json');
  if (await mapConfigFile.exists()) {
    mapConfig = await MapConfig.readFile(mapConfigFile);
  }

  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(home: MapPage(stations: stations, mapConfig: mapConfig));
  }
}
