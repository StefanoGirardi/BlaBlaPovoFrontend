import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:multi_user_flutter_app/models/history_models.dart';
import 'package:multi_user_flutter_app/models/user_model.dart';
import 'package:multi_user_flutter_app/routes.dart';

class RequestHistoryCard extends StatefulWidget {
  final RequestRideHistory history;
  final VoidCallback onTap;
  final UserModel userModel;

  const RequestHistoryCard({
    super.key,
    required this.history,
    required this.onTap,
    required this.userModel,
  });

  @override
  State<RequestHistoryCard> createState() => _RequestHistoryCardState();
}

class _RequestHistoryCardState extends State<RequestHistoryCard> {
  late String startName = "";
  late String destinationName = "";
  String? driverName;
  String? passengerName;
  bool _loadingNames = true;

  @override
  void initState() {
    super.initState();
    _loadPlaces();
    _loadUserNames();
  }

  Future<void> _loadUserNames() async {
    try {
      final token = await widget.userModel.jwt.getAccessToken();
      if (token == null) return;

      // Load driver name
      final driver = await getUsername(widget.history.driverId, token);
      
      // Load passenger name
      final passenger = await getUsername(widget.history.passengerId, token);

      if (mounted) {
        setState(() {
          driverName = driver ?? "Driver #${widget.history.driverId}";
          passengerName = passenger ?? "Passenger #${widget.history.passengerId}";
          _loadingNames = false;
        });
      }
    } catch (e) {
      print('Error loading user names: $e');
      if (mounted) {
        setState(() {
          driverName = "Driver #${widget.history.driverId}";
          passengerName = "Passenger #${widget.history.passengerId}";
          _loadingNames = false;
        });
      }
    }
  }

  Future<void> _loadPlaces() async {
    final start = await getPlaceName(
      widget.history.start.stop.latitude,
      widget.history.start.stop.longitude,
    );

    final dest = await getPlaceName(
      widget.history.arrival.stop.latitude,
      widget.history.arrival.stop.longitude,
    );

    if (mounted) {
      setState(() {
        startName = start;
        destinationName = dest;
      });
    }
  }

  Future<String> getPlaceName(double lat, double lon) async {
    try {
      final url = Uri.parse(
        "https://photon.komoot.io/reverse?lat=$lat&lon=$lon",
      );
  
      final response = await http
          .get(url)
          .timeout(const Duration(seconds: 10));
  
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
  
        final features = data["features"] as List?;
        if (features != null && features.isNotEmpty) {
          final props = features.first["properties"] as Map<String, dynamic>?;
  
          if (props != null) {
            final street = props["street"] ?? props["name"];
            final city = props["city"] ?? props["county"] ?? props["state"];
            final postcode = props["postcode"];
            final country = props["country"];
  
            final List<String> parts = [];
  
            if (street != null) parts.add(street);
            if (city != null) parts.add(city);
            if (postcode != null) parts.add(postcode);
            if (country != null) parts.add(country);
  
            if (parts.isNotEmpty) {
              return parts.join(", ");
            }
          }
        }
      } else {
        print("Photon API error: ${response.statusCode}");
      }
    } catch (e) {
      print("Error getting place name: $e");
    }
  
    return "Location (${lat.toStringAsFixed(5)}, ${lon.toStringAsFixed(5)})";
  }

  Future<String?> getUsername(int id, String token) async {
    if (id <= 0) return null;
    
    try {
      final response = await http.get(
        Uri.parse("$apiBaseUrl/api/get_user_full_name/$id"),
        headers: {
          "Authorization": "Bearer $token"
        },
      );
      
      print('Username API response: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final username = response.body.trim();
        print('Username received: $username');
        return username.isNotEmpty ? username : null;
      } else if (response.statusCode == 404) {
        print('Username not found for ID: $id');
        return null;
      } else {
        print('Failed to get username: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      print('Error getting username: $e');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 6,
              offset: Offset(0, 3),
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Ride Request",
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left column
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_loadingNames)
                        const Text("Loading names...")
                      else
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Driver: $driverName"),
                            const SizedBox(height: 8),
                            Text("Passenger: $passengerName"),
                          ],
                        ),
                      const SizedBox(height: 8),
                      Text("From: $startName"),
                      const SizedBox(height: 8),
                      Text("To: $destinationName"),
                    ],
                  ),
                ),
                // Right column
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Session ID: ${widget.history.sessionId}"),
                      const SizedBox(height: 8),
                      Text("Date: ${_formatDate(widget.history.day)}"),
                      const SizedBox(height: 8),
                      Text("Time: ${_formatTime(widget.history.day)}"),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return "${date.day}/${date.month}/${date.year}";
  }

  String _formatTime(DateTime date) {
    return "${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}";
  }
}

class OfferHistoryCard extends StatefulWidget {
  final OfferRideHistory history;
  final VoidCallback onTap;
  final UserModel userModel;

  const OfferHistoryCard({
    super.key,
    required this.history,
    required this.onTap,
    required this.userModel,
  });

  @override
  State<OfferHistoryCard> createState() => _OfferHistoryCardState();
}

class _OfferHistoryCardState extends State<OfferHistoryCard> {
  late String startName = "";
  late String destinationName = "";
  String? driverName;
  List<String> passengerNames = [];
  bool _loadingNames = true;

  @override
  void initState() {
    super.initState();
    _loadPlaces();
    _loadUserNames();
  }

  Future<void> _loadUserNames() async {
    try {
      final token = await widget.userModel.jwt.getAccessToken();
      if (token == null) return;

      // Load driver name
      final driver = await getUsername(widget.history.driverId, token);
      
      // Load passenger names
      final List<String> names = [];
      for (final passengerId in widget.history.passengerIds) {
        final name = await getUsername(passengerId, token);
        if (name != null) {
          names.add(name);
        } else {
          names.add("Passenger #$passengerId");
        }
      }

      if (mounted) {
        setState(() {
          driverName = driver ?? "Driver #${widget.history.driverId}";
          passengerNames = names.isNotEmpty ? names : ["No passengers"];
          _loadingNames = false;
        });
      }
    } catch (e) {
      print('Error loading user names: $e');
      if (mounted) {
        setState(() {
          driverName = "Driver #${widget.history.driverId}";
          passengerNames = widget.history.passengerIds.isNotEmpty 
              ? widget.history.passengerIds.map((id) => "Passenger #$id").toList()
              : ["No passengers"];
          _loadingNames = false;
        });
      }
    }
  }

  Future<void> _loadPlaces() async {
    final start = await getPlaceName(
      widget.history.start.stop.latitude,
      widget.history.start.stop.longitude,
    );

    final dest = await getPlaceName(
      widget.history.arrival.stop.latitude,
      widget.history.arrival.stop.longitude,
    );

    if (mounted) {
      setState(() {
        startName = start;
        destinationName = dest;
      });
    }
  }

  Future<String> getPlaceName(double lat, double lon) async {
    try {
      final url = Uri.parse(
        "https://photon.komoot.io/reverse?lat=$lat&lon=$lon",
      );
  
      final response = await http
          .get(url)
          .timeout(const Duration(seconds: 10));
  
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
  
        final features = data["features"] as List?;
        if (features != null && features.isNotEmpty) {
          final props = features.first["properties"] as Map<String, dynamic>?;
  
          if (props != null) {
            final street = props["street"] ?? props["name"];
            final city = props["city"] ?? props["county"] ?? props["state"];
            final postcode = props["postcode"];
            final country = props["country"];
  
            final List<String> parts = [];
  
            if (street != null) parts.add(street);
            if (city != null) parts.add(city);
            if (postcode != null) parts.add(postcode);
            if (country != null) parts.add(country);
  
            if (parts.isNotEmpty) {
              return parts.join(", ");
            }
          }
        }
      } else {
        print("Photon API error: ${response.statusCode}");
      }
    } catch (e) {
      print("Error getting place name: $e");
    }
  
    return "Location (${lat.toStringAsFixed(5)}, ${lon.toStringAsFixed(5)})";
  }

  Future<String?> getUsername(int id, String token) async {
    if (id <= 0) return null;
    
    try {
      final response = await http.get(
        Uri.parse("$apiBaseUrl/api/get_user_full_name/$id"),
        headers: {
          "Authorization": "Bearer $token"
        },
      );
      
      print('Username API response: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final username = response.body.trim();
        print('Username received: $username');
        return username.isNotEmpty ? username : null;
      } else if (response.statusCode == 404) {
        print('Username not found for ID: $id');
        return null;
      } else {
        print('Failed to get username: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      print('Error getting username: $e');
      return null;
    }
  }

  String _formatPassengerNames() {
    if (passengerNames.isEmpty) return "No passengers";
    if (passengerNames.length == 1) return passengerNames.first;
    if (passengerNames.length == 2) return "${passengerNames[0]} and ${passengerNames[1]}";
    return "${passengerNames[0]}, ${passengerNames[1]} and ${passengerNames.length - 2} more";
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 6,
              offset: Offset(0, 3),
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Ride Offer",
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left column
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_loadingNames)
                        const Text("Loading names...")
                      else
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Driver: $driverName"),
                            const SizedBox(height: 8),
                            Text("Passengers: ${_formatPassengerNames()}"),
                          ],
                        ),
                      const SizedBox(height: 8),
                      Text("From: $startName"),
                      const SizedBox(height: 8),
                      Text("To: $destinationName"),
                    ],
                  ),
                ),
                // Right column
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Session ID: ${widget.history.sessionId}"),
                      const SizedBox(height: 8),
                      Text("Stops: ${widget.history.stops.length}"),
                      const SizedBox(height: 8),
                      Text("Date: ${_formatDate(widget.history.day)}"),
                      const SizedBox(height: 8),
                      Text("Time: ${_formatTime(widget.history.day)}"),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return "${date.day}/${date.month}/${date.year}";
  }

  String _formatTime(DateTime date) {
    return "${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}";
  }
}