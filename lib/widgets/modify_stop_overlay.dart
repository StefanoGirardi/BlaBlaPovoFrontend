import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:multi_user_flutter_app/models/stop_model.dart';

class ModifyStopOverlay extends StatelessWidget {
  final List<Stop> stops;
  final int currentUserId;
  final ValueChanged<Stop> onStopModified;

  const ModifyStopOverlay({
    super.key,
    required this.stops,
    required this.currentUserId,
    required this.onStopModified,
  });

  @override
  Widget build(BuildContext context) {
    final currentUserStops = stops.where((stop) => stop.id == currentUserId).toList();
    final otherUserStops = stops.where((stop) => stop.id != currentUserId).toList();

    return Stack(
      children: [
        // Render other users' stops first (non-interactive)
        if (otherUserStops.isNotEmpty)
          MarkerLayer(
            markers: otherUserStops.map((stop) => Marker(
              point: stop.stop,
              width: 40,
              height: 60, // Increased height to accommodate all content
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Number badge
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: Colors.grey,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    child: Text(
                      '${_getStopNumber(otherUserStops, stop)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 8, // Reduced font size
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 2), // Reduced spacing
                  // Icon
                  const Icon(Icons.location_on, color: Colors.grey, size: 24), // Reduced icon size
                  const SizedBox(height: 2), // Reduced spacing
                  // User label
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Text(
                      'User ${stop.id}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 7, // Reduced font size
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            )).toList(),
          ),

        // Render current user's stops on top (interactive)
        if (currentUserStops.isNotEmpty)
          MarkerLayer(
            markers: currentUserStops.map((stop) => Marker(
              point: stop.stop,
              width: 40,
              height: 60, // Increased height to accommodate all content
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Number badge
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: _getStopColor(currentUserStops, stop),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    child: Text(
                      '${_getStopNumber(currentUserStops, stop)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 8, // Reduced font size
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 2), // Reduced spacing
                  // Interactive icon
                  GestureDetector(
                    onTap: () => onStopModified(stop),
                    child: Icon(
                      _getStopIcon(currentUserStops, stop),
                      color: _getStopColor(currentUserStops, stop),
                      size: 24, // Reduced icon size
                    ),
                  ),
                  const SizedBox(height: 2), // Reduced spacing
                  // User label
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: const Text(
                      'You',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 7, // Reduced font size
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            )).toList(),
          ),
      ],
    );
  }

  int _getStopNumber(List<Stop> userStops, Stop stop) {
    final index = userStops.indexWhere((s) => s.stop == stop.stop);
    return index + 1;
  }

  Color _getStopColor(List<Stop> userStops, Stop stop) {
    final stopNumber = _getStopNumber(userStops, stop);
    switch (stopNumber) {
      case 1:
        return Colors.blue;
      case 2:
        return Colors.green;
      default:
        return Colors.purple;
    }
  }

  IconData _getStopIcon(List<Stop> userStops, Stop stop) {
    final stopNumber = _getStopNumber(userStops, stop);
    switch (stopNumber) {
      case 1:
        return Icons.location_on;
      case 2:
        return Icons.flag;
      default:
        return Icons.location_pin;
    }
  }
}