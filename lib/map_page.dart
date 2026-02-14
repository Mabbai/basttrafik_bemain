import 'package:basttrafik/departure_service.dart';
import 'package:basttrafik/station.dart';
import 'package:flutter/material.dart';

class MapPage extends StatefulWidget {
  const MapPage({super.key, this.stations = const []});

  final List<Station> stations;

  static final Size imageSize = const Size(10760, 13146);
  static final Size stationsSize = const Size(911, 1113);
  static final double scale = imageSize.width / stationsSize.width;

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  final DepartureService _departureService = const DepartureService();

  Station? _selectedStation;
  List<Map<String, dynamic>> _departures = const [];
  bool _isLoadingDepartures = false;
  String? _departureError;

  Future<void> _showStationDepartures(Station station) async {
    setState(() {
      _selectedStation = station;
      _isLoadingDepartures = true;
      _departures = const [];
      _departureError = null;
    });

    try {
      final departures = await _departureService.fetchDepartures(station.apiName);

      if (!mounted) return;

      setState(() {
        _departures = departures;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _departureError = 'Could not load departures.';
      });
    } finally {
      if (!mounted) return;

      setState(() {
        _isLoadingDepartures = false;
      });
    }
  }

  void _clearStationDepartures() {
    if (_selectedStation == null) return;

    setState(() {
      _selectedStation = null;
      _departures = const [];
      _isLoadingDepartures = false;
      _departureError = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Bästtrafik")),
      body: GestureDetector(
        onTap: _clearStationDepartures,
        behavior: HitTestBehavior.opaque,
        child: InteractiveViewer(
          minScale: 0.1,
          maxScale: 2.5,
          constrained: false,
          child: SizedBox(
            width: MapPage.imageSize.width,
            height: MapPage.imageSize.height,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Image.asset('assets/images/map.png'),
                for (var station in widget.stations)
                  StationMarker(
                    station: station,
                    onTap: () => _showStationDepartures(station),
                  ),
                if (_selectedStation != null)
                  DeparturesPopup(
                    station: _selectedStation!,
                    departures: _departures,
                    isLoading: _isLoadingDepartures,
                    errorMessage: _departureError,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class StationMarker extends StatelessWidget {
  const StationMarker({super.key, required this.station, required this.onTap});

  final Station station;
  final VoidCallback onTap;

  double get markerSize =>
      (station.radius != null && station.radius! > 0) ? station.radius! * MapPage.scale * 2 : 20;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: station.location.dx * MapPage.scale - markerSize / 2,
      top: station.location.dy * MapPage.scale - markerSize / 2,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: markerSize,
          height: markerSize,
          decoration: BoxDecoration(
            //color: Colors.red,
            borderRadius: BorderRadius.circular(markerSize / 2),
          ),
        ),
      ),
    );
  }
}

class DeparturesPopup extends StatelessWidget {
  const DeparturesPopup({
    super.key,
    required this.station,
    required this.departures,
    required this.isLoading,
    this.errorMessage,
  });

  final Station station;
  final List<Map<String, dynamic>> departures;
  final bool isLoading;
  final String? errorMessage;

  static const double _popupWidth = 360;

  double get _markerSize =>
      (station.radius != null && station.radius! > 0) ? station.radius! * MapPage.scale * 2 : 20;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: station.location.dx * MapPage.scale - _popupWidth / 2,
      top: station.location.dy * MapPage.scale - _markerSize / 2 - 12,
      child: Transform.translate(
        offset: const Offset(0, -120),
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: _popupWidth,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFBFE3FF).withOpacity(0.88),
              borderRadius: BorderRadius.circular(14),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x33000000),
                  blurRadius: 12,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: _buildContent(context),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    if (isLoading) {
      return const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator()));
    }

    if (errorMessage != null) {
      return Text(
        errorMessage!,
        style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600, color: Colors.red.shade900),
      );
    }

    if (departures.isEmpty) {
      return Text(
        'No departures found.',
        style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final departure in departures)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${departure['line'] ?? ''} ${departure['direction'] ?? ''}'.trim(),
                    style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  departure['isCanceled'] == true
                      ? 'canceled'
                      : (departure['displayTime'] ?? departure['time'] ?? '').toString(),
                  style: textTheme.bodyMedium,
                  textAlign: TextAlign.right,
                ),
              ],
            ),
          ),
      ],
    );
  }
}
