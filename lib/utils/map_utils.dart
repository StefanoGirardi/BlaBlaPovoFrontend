// utils/map_utils.dart
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

/// Creates a LatLngBounds from any two points, automatically determining
/// the correct southwest and northeast corners
LatLngBounds createBoundsFromPoints(LatLng point1, LatLng point2) {
  final southWest = LatLng(
    point1.latitude < point2.latitude ? point1.latitude : point2.latitude,
    point1.longitude < point2.longitude ? point1.longitude : point2.longitude,
  );

  final northEast = LatLng(
    point1.latitude > point2.latitude ? point1.latitude : point2.latitude,
    point1.longitude > point2.longitude ? point1.longitude : point2.longitude,
  );

  return LatLngBounds(southWest, northEast);
}

/// Alternative: Using the constructor directly (order doesn't matter)
LatLngBounds createBoundsSimple(LatLng point1, LatLng point2) {
  // The LatLngBounds constructor automatically handles opposite corners
  return LatLngBounds(point1, point2);
}

/// Creates bounds that include a list of points with some padding
LatLngBounds createBoundsFromPointsList(List<LatLng> points,
    {double padding = 0.1}) {
  if (points.isEmpty) {
    return LatLngBounds(LatLng(0, 0), LatLng(0, 0));
  }

  double minLat = points.first.latitude;
  double maxLat = points.first.latitude;
  double minLon = points.first.longitude;
  double maxLon = points.first.longitude;

  for (final point in points) {
    if (point.latitude < minLat) minLat = point.latitude;
    if (point.latitude > maxLat) maxLat = point.latitude;
    if (point.longitude < minLon) minLon = point.longitude;
    if (point.longitude > maxLon) maxLon = point.longitude;
  }

  // Add padding
  final latPadding = (maxLat - minLat) * padding;
  final lonPadding = (maxLon - minLon) * padding;

  return LatLngBounds(
    LatLng(minLat - latPadding, minLon - lonPadding),
    LatLng(maxLat + latPadding, maxLon + lonPadding),
  );
}
