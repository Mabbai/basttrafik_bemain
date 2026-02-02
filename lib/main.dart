import 'dart:io';

import 'package:basttrafik/map_page.dart';
import 'package:basttrafik/station.dart';
import 'package:flutter/material.dart';

List<Station> stations = [];

void main() async {
  stations = await Station.readFile(File("assets/data/stations.json"));
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(home: MapPage(stations: stations));
  }
}
