// widgets/route_map_widget.dart

import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class RouteOption {
  final List<LatLng> points;
  final int etaMinutes;
  final double distanceKm;

  RouteOption({
    required this.points,
    required this.etaMinutes,
    required this.distanceKm,
  });
}

double _perpendicularDistance(LatLng p, LatLng start, LatLng end) {
  final dx = end.longitude - start.longitude;
  final dy = end.latitude - start.latitude;

  if (dx == 0 && dy == 0) {
    return sqrt(pow(p.longitude - start.longitude, 2) +
        pow(p.latitude - start.latitude, 2));
  }

  final t = ((p.longitude - start.longitude) * dx +
          (p.latitude - start.latitude) * dy) /
      (dx * dx + dy * dy);

  final nearest = LatLng(
    start.latitude + t.clamp(0, 1) * dy,
    start.longitude + t.clamp(0, 1) * dx,
  );

  return sqrt(pow(p.longitude - nearest.longitude, 2) +
      pow(p.latitude - nearest.latitude, 2));
}

/// Ramer-Douglas-Peucker simplification
List<LatLng> simplifyRoute(List<LatLng> points, double epsilon) {
  if (points.length < 3) return points;

  double maxDistance = 0;
  int index = 0;

  for (int i = 1; i < points.length - 1; i++) {
    final distance =
        _perpendicularDistance(points[i], points.first, points.last);
    if (distance > maxDistance) {
      index = i;
      maxDistance = distance;
    }
  }

  if (maxDistance > epsilon) {
    final left = simplifyRoute(points.sublist(0, index + 1), epsilon);
    final right = simplifyRoute(points.sublist(index), epsilon);
    return [
      ...left.sublist(0, left.length - 1),
      ...right
    ]; // merge without duplicate
  } else {
    return [points.first, points.last];
  }
}

Future<RouteOption> buildRouteOptionFromOsrm(List<LatLng> points) async {
  if (points.length < 2) {
    throw ArgumentError("Need at least start and end point");
  }

  final coords_simplified = simplifyRoute(points, 0.0005);
  final coords =
      coords_simplified.map((p) => "${p.longitude},${p.latitude}").join(";");
  final url = Uri.parse(
      "https://router.project-osrm.org/route/v1/driving/$coords?overview=false");

  final response = await http.get(url);

  if (response.statusCode != 200) {
    throw Exception("OSRM error: ${response.body}");
  }

  final data = jsonDecode(response.body);

  if (data["routes"] == null || data["routes"].isEmpty) {
    throw Exception("No route found");
  }

  final routeData = data["routes"][0];
  final distanceMeters = (routeData["distance"] as num).toDouble();
  final durationSeconds = (routeData["duration"] as num).toDouble();

  return RouteOption(
    points: points,
    distanceKm: distanceMeters / 1000.0,
    etaMinutes: (durationSeconds / 60).round(),
  );
}

class RouteMapWidget extends StatefulWidget {
  final LatLng? startPoint;
  final LatLng? arrivalPoint;
  final List<RouteOption> routes;
  final int? selectedRouteIndex;
  final Function(TapPosition, LatLng) onMapTap;
  final LatLngBounds? boundsConstraint;
  final LatLng initialCenter;
  final double initialZoom;
  final Function(int)? onRouteSelected;
  final MapController? externalMapController;
  final VoidCallback? onStartRemoved;
  final VoidCallback? onArrivalRemoved;

  const RouteMapWidget({
    super.key,
    required this.startPoint,
    required this.arrivalPoint,
    required this.routes,
    required this.selectedRouteIndex,
    required this.onMapTap,
    this.boundsConstraint,
    this.initialCenter = const LatLng(46.0669, 11.1217),
    this.initialZoom = 14,
    this.onRouteSelected,
    this.externalMapController,
    this.onStartRemoved,
    this.onArrivalRemoved,
  });

  @override
  State<RouteMapWidget> createState() => _RouteMapWidgetState();
}

class _RouteMapWidgetState extends State<RouteMapWidget> {
  late MapController _mapController;

  @override
  void initState() {
    super.initState();
    _mapController = widget.externalMapController ?? MapController();
  }

  @override
  void didUpdateWidget(covariant RouteMapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Fit map to bounds when both points are available
    if (widget.startPoint != null && widget.arrivalPoint != null) {
      _fitToBounds();
    }
  }

  void _fitToBounds() {
    // Create bounds from the two points (order doesn't matter)
    final bounds = LatLngBounds(widget.startPoint!, widget.arrivalPoint!);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _mapController.fitCamera(
        CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(50)),
      );
    });
  }

  void _onRouteTap(int index) {
    widget.onRouteSelected?.call(index);
  }

  @override
  Widget build(BuildContext context) {
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: widget.initialCenter,
        initialZoom: widget.initialZoom,
        onTap: widget.onMapTap,
        minZoom: 11,
        cameraConstraint: widget.boundsConstraint != null
            ? CameraConstraint.contain(bounds: widget.boundsConstraint!)
            : const CameraConstraint.unconstrained(),
      ),
      children: [
        TileLayer(
          urlTemplate: "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
          subdomains: const ['a', 'b', 'c'],
        ),

        // Start point marker
        if (widget.startPoint != null)
          MarkerLayer(
            markers: [
              Marker(
                point: widget.startPoint!,
                width: 40,
                height: 40,
                child: GestureDetector(
                    onTap: () {
                      widget.onStartRemoved?.call();
                    },
                    child: const Icon(Icons.location_on,
                        color: Colors.green, size: 40)),
              )
            ],
          ),

        // Arrival point marker
        if (widget.arrivalPoint != null)
          MarkerLayer(
            markers: [
              Marker(
                point: widget.arrivalPoint!,
                width: 40,
                height: 40,
                child: GestureDetector(
                    onTap: () {
                      widget.onArrivalRemoved?.call();
                    },
                    child: const Icon(Icons.flag, color: Colors.red, size: 40)),
              )
            ],
          ),

        // Route polylines
        if (widget.routes.isNotEmpty)
          PolylineLayer(
            polylines: List.generate(widget.routes.length, (i) {
              final isSelected = i == widget.selectedRouteIndex;
              final colors = [Colors.blue, Colors.orange, Colors.purple];
              return Polyline(
                points: widget.routes[i].points,
                strokeWidth: isSelected ? 6 : 3,
                color: colors[i % colors.length],
              );
            }),
          ),

        // ETA markers for each route
        if (widget.routes.isNotEmpty)
          MarkerLayer(
            markers: List.generate(widget.routes.length, (i) {
              final route = widget.routes[i];
              final midIndex = route.points.length ~/ 2;
              final point = route.points[midIndex];
              final isSelected = i == widget.selectedRouteIndex;

              return Marker(
                point: point,
                width: 90,
                height: 40,
                child: GestureDetector(
                  onTap: () => _onRouteTap(i),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.blueAccent : Colors.white,
                      borderRadius: BorderRadius.circular(6),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      "${route.etaMinutes} min",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: isSelected ? Colors.white : Colors.black,
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
      ],
    );
  }
}
