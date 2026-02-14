import 'package:basttrafik/map_config.dart';
import 'package:basttrafik/map_page.dart';
import 'package:basttrafik/station.dart';
import 'package:flutter/material.dart';

List<Station> stations = [];
MapConfig mapConfig = MapConfig.fallback;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  stations = await Station.readAsset('assets/data/stations.json');

  try {
    mapConfig = await MapConfig.readAsset('assets/data/map_config.json');
  } catch (_) {
    mapConfig = MapConfig.fallback;
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
