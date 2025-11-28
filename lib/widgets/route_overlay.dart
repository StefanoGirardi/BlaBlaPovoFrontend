// widgets/route_overlay.dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:multi_user_flutter_app/widgets/map_widget.dart'; // your RouteOption class

class RouteOverlay extends StatelessWidget {
  final List<RouteOption> routes;
  final int? selectedRouteIndex;
  final Function(int)? onRouteSelected;

  const RouteOverlay({
    super.key,
    required this.routes,
    this.selectedRouteIndex,
    this.onRouteSelected,
  });

  @override
  Widget build(BuildContext context) {
    if (routes.isEmpty) return const SizedBox.shrink();

    return Stack(
      children: [
        PolylineLayer(
          polylines: List.generate(routes.length, (i) {
            final isSelected = i == selectedRouteIndex;
            final colors = [Colors.blue, Colors.orange, Colors.purple];
            return Polyline(
              points: routes[i].points,
              strokeWidth: isSelected ? 6 : 3,
              color: colors[i % colors.length],
            );
          }),
        ),
        MarkerLayer(
          markers: List.generate(routes.length, (i) {
            final route = routes[i];
            final midIndex = route.points.length ~/ 2;
            final point = route.points[midIndex];
            final isSelected = i == selectedRouteIndex;

            return Marker(
              point: point,
              width: 90,
              height: 40,
              child: GestureDetector(
                onTap: () => onRouteSelected?.call(i),
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
