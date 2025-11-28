// widgets/start_arrival_overlay.dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class StartArrivalOverlay extends StatelessWidget {
  final LatLng? startPoint;
  final LatLng? arrivalPoint;
  final VoidCallback? onStartRemoved;
  final VoidCallback? onArrivalRemoved;

  const StartArrivalOverlay({
    super.key,
    this.startPoint,
    this.arrivalPoint,
    this.onStartRemoved,
    this.onArrivalRemoved,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        if (startPoint != null)
          MarkerLayer(
            markers: [
              Marker(
                point: startPoint!,
                width: 40,
                height: 40,
                child: GestureDetector(
                  onTap: onStartRemoved,
                  child: const Icon(Icons.location_on,
                      color: Colors.green, size: 40),
                ),
              ),
            ],
          ),
        if (arrivalPoint != null)
          MarkerLayer(
            markers: [
              Marker(
                point: arrivalPoint!,
                width: 40,
                height: 40,
                child: GestureDetector(
                  onTap: onArrivalRemoved,
                  child: const Icon(Icons.flag, color: Colors.red, size: 40),
                ),
              ),
            ],
          ),
      ],
    );
  }
}
