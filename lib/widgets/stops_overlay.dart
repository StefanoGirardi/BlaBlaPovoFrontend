import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:multi_user_flutter_app/models/stop_model.dart';
import 'package:multi_user_flutter_app/routes.dart';

class StopsOverlay extends StatelessWidget {
  final List<Stop>? stops;
  final String token; // New required field

  const StopsOverlay({
    super.key,
    required this.stops,
    required this.token, // New required parameter
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        if (stops != null && stops!.isNotEmpty)
          MarkerLayer(
            markers: stops!
                .map(
                  (point) => Marker(
                    point: point.stop,
                    width: 40,
                    height: 50,
                    child: FutureBuilder<String?>(
                      future: getUsername(point.id, token),
                      builder: (context, snapshot) {
                        // Show loading or username
                        final displayText = snapshot.connectionState == ConnectionState.waiting
                            ? "..."
                            : snapshot.data ?? "";
                        
                        return Container(
                          width: 40,
                          height: 80,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(2),
                                decoration: BoxDecoration(
                                  color: Color.fromARGB(255, 0, 51, 255),
                                  shape: BoxShape.rectangle,
                                ),
                                child: FittedBox( // Scales text to fit
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    displayText,
                                    style: const TextStyle(
                                      color: Colors.black,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    textAlign: TextAlign.center,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 2),
                              const Icon(
                                Icons.location_on,
                                color: Color.fromARGB(255, 0, 51, 255),
                                size: 30,
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                )
                .toList(),
          ),
      ]
    );
  }

  Future<String?> getUsername(int id, String token) async {
    try {
      final response = await http.get(
        Uri.parse("$apiBaseUrl/api/get_username/$id"),
        headers: {
          "Authorization": "Bearer $token"
        },
      );
      
      if (response.statusCode == 200) {
        final username = response.body.trim();
        return username.isNotEmpty ? username : null;
      } else if (response.statusCode == 404) {
        return null;
      } else {
        print('Failed to get username: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('Error getting username: $e');
      return null;
    }
  }
}