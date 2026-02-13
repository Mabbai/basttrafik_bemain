import 'package:basttrafik/station.dart';
import 'package:flutter/material.dart';

class MapPage extends StatelessWidget {
  const MapPage({super.key, this.stations = const []});

  final List<Station> stations;

  static final Size imageSize = const Size(10760, 13146);
  static final Size stationsSize = const Size(911, 1113);
  static final double scale = imageSize.width / stationsSize.width;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Bästtrafik")),
      body: InteractiveViewer(
        minScale: 0.1,
        maxScale: 2.5,
        constrained: false,
        child: SizedBox(
          width: imageSize.width,
          height: imageSize.height,
          child: Stack(
            children: [
              Image.asset('assets/images/map.png'),
              for (var station in stations) StationMarker(station: station),
            ],
          ),
        ),
      ),
    );
  }
}

class StationMarker extends StatelessWidget {
  const StationMarker({super.key, required this.station});

  final Station station;

  double get markerSize =>
      (station.radius != null && station.radius! > 0) ? station.radius! * MapPage.scale * 2 : 20;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: station.location.dx * MapPage.scale - markerSize / 2,
      top: station.location.dy * MapPage.scale - markerSize / 2,
      child: GestureDetector(
        onTap: () {
          print("Tapped ${station.name}");
        },
        child: Container(
          width: markerSize,
          height: markerSize,
          decoration: BoxDecoration(
            color: Colors.red,
            borderRadius: BorderRadius.circular(markerSize / 2),
          ),
        ),
      ),
    );
  }
}
