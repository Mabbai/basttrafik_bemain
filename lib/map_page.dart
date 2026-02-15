import 'package:basttrafik/departure_service.dart';
import 'package:basttrafik/map_config.dart';
import 'package:basttrafik/station.dart';
import 'package:flutter/material.dart';

class MapPage extends StatefulWidget {
  const MapPage({super.key, this.stations = const [], required this.mapConfig});

  final List<Station> stations;
  final MapConfig mapConfig;

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  final DepartureService _departureService = const DepartureService();
  static const int _maxDepartureFetchAttempts = 3;

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
      final departures = await _fetchDeparturesWithRetry(station.apiName);

      if (!mounted) return;

      setState(() {
        _departures = departures;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _departureError = _friendlyDepartureError(error);
      });
    } finally {
      if (!mounted) return;

      setState(() {
        _isLoadingDepartures = false;
      });
    }
  }

  Future<List<Map<String, dynamic>>> _fetchDeparturesWithRetry(String stopName) async {
    Object? lastError;

    for (var attempt = 1; attempt <= _maxDepartureFetchAttempts; attempt++) {
      try {
        return await _departureService.fetchDepartures(stopName);
      } catch (error) {
        lastError = error;
      }
    }

    if (lastError != null) {
      throw lastError;
    }

    throw StateError('Could not load departures.');
  }

  String _friendlyDepartureError(Object error) {
    final message = error.toString();

    if (message.contains('Backend returned HTML instead of departures JSON')) {
      return 'Departures API is not connected in web mode. '
          'Route /api/departures to your backend or set DEPARTURES_API_BASE.';
    }

    if (message.contains('Invalid departures JSON')) {
      return 'Departures API returned invalid JSON.';
    }

    return 'Could not load departures.';
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
            width: widget.mapConfig.imageSize.width,
            height: widget.mapConfig.imageSize.height,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Image.asset('assets/images/map.png'),
                for (var station in widget.stations)
                  StationMarker(
                    station: station,
                    mapConfig: widget.mapConfig,
                    onTap: () => _showStationDepartures(station),
                  ),
                if (_selectedStation != null)
                  DeparturesPopup(
                    station: _selectedStation!,
                    mapConfig: widget.mapConfig,
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
  const StationMarker({super.key, required this.station, required this.mapConfig, required this.onTap});

  final Station station;
  final MapConfig mapConfig;
  final VoidCallback onTap;

  double get markerSize =>
      (station.radius != null && station.radius! > 0) ? station.radius! * mapConfig.scale * 2 : 20;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: station.location.dx * mapConfig.scale - markerSize / 2,
      top: station.location.dy * mapConfig.scale - markerSize / 2,
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
    required this.mapConfig,
    required this.departures,
    required this.isLoading,
    this.errorMessage,
  });

  final Station station;
  final MapConfig mapConfig;
  final List<Map<String, dynamic>> departures;
  final bool isLoading;
  final String? errorMessage;

  static const double _popupWidth = 360;
  static const double _pointerHeight = 12;
  static const double _pointerWidth = 24;
  static const double _popupSpacingFromMarker = 8;
  static const double _popupPadding = 12;
  static const double _titleHeight = 24;
  static const double _titleBottomSpacing = 8;
  static const double _loadingHeight = 24;
  static const double _messageHeight = 22;
  static const double _departureRowHeight = 28;

  List<_DepartureRowData> get _displayedDepartureRows {
    final groupedDepartures = <String, List<Map<String, dynamic>>>{};
    final keyOrder = <String>[];

    for (final departure in departures) {
      final key = '${departure['line'] ?? ''}|${departure['direction'] ?? ''}';
      if (!groupedDepartures.containsKey(key)) {
        groupedDepartures[key] = [];
        keyOrder.add(key);
      }
      groupedDepartures[key]!.add(departure);
    }

    return [
      for (final key in keyOrder)
        _buildDepartureRow(
          groupedDepartures[key]!,
        ),
    ];
  }

  _DepartureRowData _buildDepartureRow(List<Map<String, dynamic>> groupedDepartureEntries) {
    final departure = groupedDepartureEntries.first;

    if (groupedDepartureEntries.length >= 3) {
      return _DepartureRowData(
        title: '${departure['line'] ?? ''} ${departure['direction'] ?? ''}'.trim(),
        timeText: _departureTimeText(departure),
      );
    }

    if (groupedDepartureEntries.length == 2) {
      return _DepartureRowData(
        title: '${departure['line'] ?? ''} ${departure['direction'] ?? ''}'.trim(),
        timeText: groupedDepartureEntries.map(_departureTimeText).join('   '),
      );
    }

    return _DepartureRowData(
      title: '${departure['line'] ?? ''} ${departure['direction'] ?? ''}'.trim(),
      timeText: _departureTimeText(departure),
    );
  }

  String _departureTimeText(Map<String, dynamic> departure) {
    return departure['isCanceled'] == true
        ? 'canceled'
        : (departure['displayTime'] ?? departure['time'] ?? '').toString();
  }

  double get _markerSize =>
      (station.radius != null && station.radius! > 0) ? station.radius! * mapConfig.scale * 2 : 20;

  double get _departuresContentHeight {
    if (isLoading) {
      return _loadingHeight;
    }

    if (errorMessage != null || departures.isEmpty) {
      return _messageHeight;
    }

    return _displayedDepartureRows.length * _departureRowHeight;
  }

  double get _popupHeight =>
      (_popupPadding * 2) + _titleHeight + _titleBottomSpacing + _departuresContentHeight;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: station.location.dx * mapConfig.scale - _popupWidth / 2,
      top:
          station.location.dy * mapConfig.scale -
          _markerSize / 2 -
          _pointerHeight -
          _popupSpacingFromMarker -
          _popupHeight,
      child: Material(
        color: Colors.transparent,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
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
            CustomPaint(
              size: const Size(_pointerWidth, _pointerHeight),
              painter: _PopupPointerPainter(
                color: const Color(0xFFBFE3FF).withOpacity(0.88),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          station.name,
          style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        _buildDeparturesContent(context),
      ],
    );
  }

  Widget _buildDeparturesContent(BuildContext context) {
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

    final displayedRows = _displayedDepartureRows;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final departure in displayedRows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    departure.title,
                    style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  departure.timeText,
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

class _DepartureRowData {
  const _DepartureRowData({required this.title, required this.timeText});

  final String title;
  final String timeText;
}

class _PopupPointerPainter extends CustomPainter {
  const _PopupPointerPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(size.width, 0)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _PopupPointerPainter oldDelegate) => oldDelegate.color != color;
}
