// widgets/route_overlay.dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:multi_user_flutter_app/widgets/map_widget.dart'; // your RouteOption class

class StarredRouteOverlay extends StatelessWidget {
  final RouteOption routes;

  StarredRouteOverlay({
    super.key,
    required this.routes,
  });

  @override
  Widget build(BuildContext context) {
    if (routes.points.length < 2) return const SizedBox.shrink();

    return Stack(
      children: [
        PolylineLayer(polylines: [
          Polyline(
            points: routes.points,
            strokeWidth: 6,
            color: Colors.lightBlue,
          ),
        ]),
        MarkerLayer(
          markers: [
            Marker(
              point: routes.points[routes.points.length ~/ 2],
              width: 90,
              height: 40,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white,
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
                  "${routes.etaMinutes} min",
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
