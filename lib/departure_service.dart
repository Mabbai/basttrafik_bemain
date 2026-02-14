import 'departure_service_io.dart' if (dart.library.html) 'departure_service_web.dart' as impl;

class DepartureService {
  const DepartureService();

  Future<List<Map<String, dynamic>>> fetchDepartures(String stopName) {
    return impl.fetchDepartures(stopName);
  }
}
