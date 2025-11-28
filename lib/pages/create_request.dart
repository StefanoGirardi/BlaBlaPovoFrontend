// Page to handle ride requests creations

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:multi_user_flutter_app/l10n/app_localizations.dart';
import 'package:multi_user_flutter_app/models/user_model.dart';
import 'package:multi_user_flutter_app/widgets/base_map_widget.dart';
import 'package:multi_user_flutter_app/widgets/drawer_menu.dart';
import 'package:multi_user_flutter_app/widgets/map_widget.dart';
import 'package:multi_user_flutter_app/widgets/map_widget.dart';

import 'package:latlong2/latlong.dart';
import 'package:multi_user_flutter_app/widgets/start_arrival_overlay.dart';

class CreateRequestModel {
  final int passenger_id;
  final LatLng start;
  final LatLng arrival;
  final DateTime start_time;
  final int n_seats_requested;

  const CreateRequestModel({
    required this.passenger_id,
    required this.start,
    required this.arrival,
    required this.start_time,
    required this.n_seats_requested,
  });

  Map<String, dynamic> _latLngToJson(LatLng point) {
    return {
      'lat': point.latitude,
      'lng': point.longitude,
    };
  }

  Map<String, dynamic> toJson() {
    return {
      'passenger_id': passenger_id,
      'start': _latLngToJson(start),
      'arrival': _latLngToJson(arrival),
      'start_time': start_time.toUtc().toIso8601String(),
      'n_seats_requested': n_seats_requested, // Assuming 1 seat by default, adjust as needed (It's always one consider removing it entirly)
    };
  }

  factory CreateRequestModel.fromJson(Map<String, dynamic> json) {
    return CreateRequestModel(
      passenger_id: json['passenger_id'] as int,
      start: LatLng(
          json['start']['lat'] as double, json['start']['lon'] as double),
      arrival: LatLng(
          json['arrival']['lat'] as double, json['arrival']['lon'] as double),
      start_time: DateTime.parse(json['start_time'] as String),
      n_seats_requested: json['n_seat_requested'] as int,
    );
  }
}

class CreateRequest extends StatefulWidget {
  final UserModel userModel;

  const CreateRequest({super.key, required this.userModel});

  @override
  State<CreateRequest> createState() => _CreateRequestState(userModel: userModel);
}

class _CreateRequestState extends State<CreateRequest> {
  final String apiBaseUrl = 'http://localhost:8000';
  

  final SafeMapController controller = SafeMapController();
  final UserModel userModel;
  LatLng? startPoint;
  LatLng? arrivalPoint;

  final TextEditingController startController = TextEditingController();
  final TextEditingController arrivalController = TextEditingController();

  List<Map<String, dynamic>> startSuggestions = [];
  List<Map<String, dynamic>> arrivalSuggestions = [];

  int passengers = 1;
  DateTime? selectedStartTime;

  _CreateRequestState({required this.userModel});

  // Define bounds constraint for Northern Italy(Trento)
  static final LatLngBounds northernItalyBounds = LatLngBounds(
    const LatLng(45.5, 10.0), // Southwest corner
    const LatLng(47.1, 12.5), // Northeast corner
  );

  Future<void> _searchLocation(String query, bool isStart) async {
    if (query.isEmpty) {
      setState(() {
        if (isStart) {
          startSuggestions = [];
        } else {
          arrivalSuggestions = [];
        }
      });
      return;
    }
  
    final url = "https://photon.komoot.io/api/?q=$query&lang=it&limit=10";
  
    final res = await http.get(Uri.parse(url));
    if (res.statusCode == 200) {
      final data = json.decode(res.body);
      final features = data["features"] as List?;
  
      if (features != null) {
        final suggestions = features.map<Map<String, dynamic>>((f) {
          final props = f["properties"] as Map<String, dynamic>;
          final geometry = f["geometry"] as Map<String, dynamic>;
          final coords = geometry["coordinates"] as List;
  
          final street = props["street"] ?? props["name"];
          final city = props["city"] ?? props["county"];
          final postcode = props["postcode"];
          final country = props["country"];
  
          // Build a readable label
          final List<String> parts = [];
          if (street != null) parts.add(street);
          if (city != null) parts.add(city);
          if (postcode != null) parts.add(postcode);
          if (country != null) parts.add(country);
  
          return {
            "label": parts.join(", "), // for display in UI
            "lat": coords[1],
            "lon": coords[0],
            "properties": props,
          };
        }).toList();
  
        setState(() {
          if (isStart) {
            startSuggestions = suggestions;
          } else {
            arrivalSuggestions = suggestions;
          }
        });
      }
    }
  }

  void _fitMapToPoints() {
    if (startPoint != null && arrivalPoint != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final bounds = LatLngBounds(startPoint!, arrivalPoint!);
        controller.fitCamera(
          CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(50)),
        );
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

  void _pickStartTime() async {
    final now = DateTime.now().add(Duration(minutes: 5)); //At leasts five, consider 10.
  
    // today or tomorrow
    final selectedDay = await showDialog<DateTime>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text("${AppLocalizations.of(context).selectDay}"),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, DateTime(now.year, now.month, now.day)),
            child: Text("${AppLocalizations.of(context).today}"),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, DateTime(now.year, now.month, now.day + 1)),
            child: Text("${AppLocalizations.of(context).tomorrow}"),
          ),
        ],
      ),
    );
  
    if (selectedDay == null) return;
  
    
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(now),
    );
  
    if (pickedTime != null) {
      final dt = DateTime(
        selectedDay.year,
        selectedDay.month,
        selectedDay.day,
        pickedTime.hour,
        pickedTime.minute,
      );
  
      // Validation: if today, time must be >= now
      if (dt.isBefore(now)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please select a future time")),
        );
        return;
      }
  
      setState(() {
        selectedStartTime = dt;
      });
    }
  }

  Future<void> _saveRequest() async {
    if (startPoint == null ||
        arrivalPoint == null ||
        selectedStartTime == null 
      ) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("${AppLocalizations.of(context).completeFields}")),
      );
      return;
    }

    final crm = CreateRequestModel(
        passenger_id: userModel.currentUser!.id,
        start: startPoint!,
        arrival: arrivalPoint!,
        start_time: selectedStartTime!,
        n_seats_requested: passengers,
      );
    await createReq(crm);
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Request saved successfully")),
    );

    Navigator.pop(context);
    Navigator.pushNamed(context, "/home_page");
  }

  Future<void> createReq(CreateRequestModel crm) async {
    try {
      final response = await http.post(
        Uri.parse('$apiBaseUrl/api/requests'),
        headers: {
          'Content-Type': 'application/json',
          "Authorization":"Bearer ${await userModel.jwt.getAccessToken()}"
        },
        body: jsonEncode(crm.toJson()),
      );

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('✓ ${AppLocalizations.of(context).reqCreatedSucc}')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text('✗ ${AppLocalizations.of(context).failed}: ${response.statusCode} - ${response.body}')),
        );
      }
    } catch (e) {
      debugPrint('Network error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Network error: $e')),
      );
    }
  }

  void _selectSuggestion(Map<String, dynamic> suggestion, bool isStart) {
    LatLng selected = LatLng(
      double.parse(suggestion["lat"]),
      double.parse(suggestion["lon"]),
    );
    setState(() {
      if (isStart) {
        startPoint = selected;
        startController.text = suggestion["display_name"];
        startSuggestions = [];
      } else {
        arrivalPoint = selected;
        arrivalController.text = suggestion["display_name"];
        arrivalSuggestions = [];
      }
    });
  }

  void _onMapTap(TapPosition tapPosition, LatLng point) async {
    if (startPoint == null) {
      setState(() {
        startPoint = point;
      });
      final name = await getPlaceName(point.latitude, point.longitude);
      setState(() {
        startController.text = name;
      });
    } else if (arrivalPoint == null) {
      setState(() {
        arrivalPoint = point;
      });
      final name = await getPlaceName(point.latitude, point.longitude);
      if (!mounted) return;
      setState(() {
        arrivalController.text = name;
      });
    } else {
      setState(() {
        startPoint = point;
        arrivalPoint = null;
        startController.clear();
        arrivalController.clear();
      });
      final name = await getPlaceName(point.latitude, point.longitude);
      setState(() {
        startController.text = name;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("${AppLocalizations.of(context).createRequest}"),
        backgroundColor: Colors.redAccent,
        centerTitle: true,
      ),
      endDrawer: DrawerMenu(userModel: widget.userModel),
      body: Column(
        children: [
          _buildSearchBar(true),
          _buildSearchBar(false),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _pickStartTime,
                  child: Text(selectedStartTime == null
                      ? "${AppLocalizations.of(context).pickTime}"
                      : "${selectedStartTime!.hour.toString().padLeft(2, '0')}:${selectedStartTime!.minute.toString().padLeft(2, '0')}"),
                ),
              ),
            ],
          ),
          Expanded(
            child: BaseMapWidget(
              controller: controller,
              boundsConstraint: northernItalyBounds,
              onTap:(tapPos,point) => _onMapTap(tapPos,point),
              overlays: [
                StartArrivalOverlay(
                  startPoint: startPoint,
                  arrivalPoint: arrivalPoint,
                  onStartRemoved: () => setState(() {
                    startPoint=null;
                  }),
                  onArrivalRemoved: () => setState(() {
                    arrivalPoint=null;
                  }),
                )
              ],
            ),
          ),
          ElevatedButton(
            onPressed: _saveRequest,
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text("Save Request"),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(bool isStart) {
    final controller = isStart ? startController : arrivalController;
    final suggestions = isStart ? startSuggestions : arrivalSuggestions;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: TextField(
            controller: controller,
            decoration: InputDecoration(
              labelText: isStart ? "${AppLocalizations.of(context).startPoint}" : "${AppLocalizations.of(context).arrivalPoint}",
              border: const OutlineInputBorder(),
            ),
            onChanged: (value) => _searchLocation(value, isStart),
          ),
        ),
        if (suggestions.isNotEmpty)
          SizedBox(
            height: 120,
            child: ListView.builder(
              itemCount: suggestions.length,
              itemBuilder: (context, index) {
                final s = suggestions[index];
                return ListTile(
                  title: Text(s["display_name"]),
                  onTap: () => _selectSuggestion(s, isStart),
                );
              },
            ),
          ),
      ],
    );
  }
}