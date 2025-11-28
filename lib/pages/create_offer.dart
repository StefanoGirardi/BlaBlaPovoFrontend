//Create offer page it has all the needed instruments to create a ride offer.

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
import 'package:multi_user_flutter_app/widgets/route_overlay.dart';
import 'package:multi_user_flutter_app/widgets/start_arrival_overlay.dart';

class CreateOffer extends StatefulWidget {
  final UserModel userModel;

  const CreateOffer({super.key, required this.userModel});

  @override
  State<CreateOffer> createState() =>
      _CreateOfferState(userModel: this.userModel);
}

class _CreateOfferState extends State<CreateOffer> {
  final UserModel userModel;
  final String apiBaseUrl = 'http://localhost:8000';
  
  // The apibaseurl can be removed if neccesary use just one defined in the routes.dart file or better create an
  // ApiServiceClass that handles all api calls.
  LatLng? startPoint;
  LatLng? arrivalPoint;

  List<RouteOption> allRoutes = [];
  int? selectedRouteIndex;

  String? eta;
  num? etaMinutesRaw;
  LatLng? etaMarkerPoint;

  final TextEditingController startController = TextEditingController();
  final TextEditingController arrivalController = TextEditingController();

  List<Map<String, dynamic>> startSuggestions = [];
  List<Map<String, dynamic>> arrivalSuggestions = [];

  int passengers = 1;
  DateTime? selectedStartTime;
  String? arrivalTime;
  
  // Waypoint management
  List<LatLng> _waypoints = [];
  bool _reorderMode = false;
  bool _modifyMode = false;
  
  _CreateOfferState({required this.userModel});

  // Define bounds constraint for Northern Italy (Trento)
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
  
    final url = "https://photon.komoot.io/api/?q=$query&lang=it&limit=5";
  
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
  
          final List<String> parts = [];
          if (street != null) parts.add(street);
          if (city != null) parts.add(city);
          if (postcode != null) parts.add(postcode);
          if (country != null) parts.add(country);
  
          return {
            "label": parts.join(", "),
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

  Future<void> _tryFetchRoute() async {
    if (startPoint != null && arrivalPoint != null) {
      await _fetchRoute();
    } else {
      setState(() {
        allRoutes.clear();
        eta = null;
        etaMinutesRaw = null;
        etaMarkerPoint = null;
        selectedRouteIndex = null;
      });
    }
  }

  Future<void> _fetchRoute() async {
    List<LatLng> coords = List.from([startPoint!]);
    coords.addAll(_waypoints);
    coords.add(arrivalPoint!);
    final coordsFinal = coords.map((p) => "${p.longitude},${p.latitude}").join(";");

    final url = "https://router.project-osrm.org/route/v1/driving/"
        "$coordsFinal"
        "?overview=full&geometries=geojson&alternatives=true";

    final res = await http.get(Uri.parse(url));
    if (res.statusCode == 200) {
      final data = json.decode(res.body);
      final routes = data["routes"] as List;

      setState(() {
        allRoutes.clear();

        for (var route in routes.take(3)) {
          final coords = route["geometry"]["coordinates"];
          final points = coords
              .map<LatLng>((c) => LatLng(c[1].toDouble(), c[0].toDouble()))
              .toList();

          final durationSec = route["duration"] as num;
          final minutes = (durationSec / 60).round();

          final distanceMeters = route["distance"] as num;
          final distanceKm = (distanceMeters / 1000).toDouble();

          allRoutes.add(RouteOption(
            points: points,
            etaMinutes: minutes,
            distanceKm: distanceKm,
          ));
        }

        if (allRoutes.isNotEmpty) {
          selectedRouteIndex = 0;
          etaMinutesRaw = allRoutes[0].etaMinutes;
          eta = "${allRoutes[0].etaMinutes} min";

          final mainRoute = allRoutes[0].points;
          final midIndex = mainRoute.length ~/ 2;
          etaMarkerPoint = mainRoute[midIndex];

          if (selectedStartTime != null) {
            final arrive = selectedStartTime!.add(
              Duration(minutes: allRoutes[0].etaMinutes),
            );
            arrivalTime =
                "${arrive.hour.toString().padLeft(2, '0')}:${arrive.minute.toString().padLeft(2, '0')}";
          } else {
            arrivalTime = null;
          }
        }
      });
    }
  }

  void _pickStartTime() async {
    final now = DateTime.now().add(Duration(minutes: 5)); // at least five minute otherwise it doesn't make sense. Consider 10.
  
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
  
      if (dt.isBefore(now)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please select a future time")),
        );
        return;
      }
  
      setState(() {
        selectedStartTime = dt;
  
        if (etaMinutesRaw != null) {
          final arrive = selectedStartTime!.add(
            Duration(minutes: etaMinutesRaw!.toInt()),
          );
          arrivalTime =
              "${arrive.hour.toString().padLeft(2, '0')}:${arrive.minute.toString().padLeft(2, '0')}";
        }
      });
    }
  }

  // fn to add start7arrival points or modify them.
  void _handleTap(TapPosition tap, LatLng point) async {
    if (_modifyMode && !_reorderMode) {
      setState(() {
        _waypoints.add(point);
        _tryFetchRoute();
      });
    } else if (!_modifyMode) {
      setState(() {
        if (startPoint == null) {
          startPoint = point;
        } else if (arrivalPoint == null) {
          arrivalPoint = point;
        }
        if (startPoint != null && arrivalPoint != null) {
          _fetchRoute();
        }
      });
    }
  }
  //remove the waypoints for route modification
  void _removeWaypoint(int index) {
    setState(() {
      _waypoints.removeAt(index);
      _tryFetchRoute();
    });
  }

  void _reorderWaypoint(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final LatLng item = _waypoints.removeAt(oldIndex);
      _waypoints.insert(newIndex, item);
      _tryFetchRoute();
    });
  }

  void _swapWaypoints(int index1, int index2) {
    setState(() {
      final temp = _waypoints[index1];
      _waypoints[index1] = _waypoints[index2];
      _waypoints[index2] = temp;
      _tryFetchRoute();
    });
  }

  void _moveWaypointUp(int index) {
    if (index > 0) _swapWaypoints(index, index - 1);
  }

  void _moveWaypointDown(int index) {
    if (index < _waypoints.length - 1) _swapWaypoints(index, index + 1);
  }

  void _reverseRoute() {
    setState(() {
      if (startPoint != null && arrivalPoint != null) {
        final temp = startPoint;
        startPoint = arrivalPoint;
        arrivalPoint = temp;
        _waypoints = _waypoints.reversed.toList();
        _tryFetchRoute();
      }
    });
  }

  void _clearAllWaypoints() {
    setState(() {
      _waypoints.clear();
      _tryFetchRoute();
    });
  }
  
  //call to fn that calls api to save offer and passing the route selected if ther are more than one.
  Future<void> _saveOffer() async {
    if (startPoint == null || arrivalPoint == null || selectedStartTime == null || selectedRouteIndex == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("${AppLocalizations.of(context).completeFields}")),
      );
      return;
    }

    final selectedRoute = allRoutes[selectedRouteIndex!];
    Car ? auto = null;
    if (userModel.currentUser!.auto!= null)
      auto = Car.fromJson(userModel.currentUser!.auto!);
    final crm = CreateOfferModel(
      driver_id: userModel.currentUser!.id,
      route: selectedRoute.points,
      start: selectedRoute.points.first,
      arrival: selectedRoute.points.last,
      start_time: selectedStartTime!,
      arrival_time: selectedStartTime!,
      negotiable_route: false,
      auto: auto,
      seats_available: passengers,
    );
    
    await createOffer(crm);
    Navigator.pop(context);
    Navigator.pushNamed(context, "/home_page");
  }

  Future<bool> createOffer(CreateOfferModel crm) async {
    try {
      final token = await userModel.jwt.getAccessToken();
      final response = await http.post(
        Uri.parse('$apiBaseUrl/api/offers'),
        headers: {
          'Authorization' : 'Bearer ${token}',
          'Content-Type': 'application/json'
          },
        body: json.encode(crm.toJson()),
      );

      if (response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✓ Offer created successfully')),
        );
        return true;
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: ${response.statusCode}')),
        );
        return false;
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Network error: $e')),
      );
      return false;
    }
  }

  void _selectSuggestion(Map<String, dynamic> suggestion, bool isStart) {
    LatLng selected = LatLng(
      double.parse(suggestion["lat"].toString()),
      double.parse(suggestion["lon"].toString()),
    );
    setState(() {
      if (isStart) {
        startPoint = selected;
        startController.text = suggestion["label"];
        startSuggestions = [];
      } else {
        arrivalPoint = selected;
        arrivalController.text = suggestion["label"];
        arrivalSuggestions = [];
      }

      allRoutes.clear();
      selectedRouteIndex = null;
      eta = null;
      etaMinutesRaw = null;
      etaMarkerPoint = null;
      arrivalTime = null;
    });
    _tryFetchRoute();
  }

  void _handleRouteSelection(int index) {
    setState(() {
      selectedRouteIndex = index;
      final route = allRoutes[index];
      etaMinutesRaw = route.etaMinutes;
      eta = "${route.etaMinutes} min";
      if (selectedStartTime != null) {
        final arrive = selectedStartTime!.add(Duration(minutes: route.etaMinutes));
        arrivalTime = "${arrive.hour.toString().padLeft(2, '0')}:${arrive.minute.toString().padLeft(2, '0')}";
      }
    });
  }

  //fns to build the review of the offer shown on top of the map
  Widget _buildRouteInfoCard() {
    if (selectedRouteIndex == null) return const SizedBox();
    
    final route = allRoutes[selectedRouteIndex!];
    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Route Details",
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.redAccent,
              ),
            ),
            const SizedBox(height: 8),
            _buildInfoRow("${AppLocalizations.of(context).from}:", startController.text.isEmpty ? '${AppLocalizations.of(context).startPoint}' : startController.text),
            _buildInfoRow("${AppLocalizations.of(context).to}:", arrivalController.text.isEmpty ? '${AppLocalizations.of(context).arrivalPoint}' : arrivalController.text),
            _buildInfoRow("${AppLocalizations.of(context).distance}:", "${route.distanceKm.toStringAsFixed(1)} km"),
            _buildInfoRow("${AppLocalizations.of(context).duration}:", "${route.etaMinutes} min"),
            if (arrivalTime != null)
              _buildInfoRow("Arrival:", arrivalTime!),
            if (_waypoints.isNotEmpty)
              _buildInfoRow("Waypoints:", "${_waypoints.length} stops"),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.grey),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  // builder of waypoint controller
  Widget _buildWaypointControls() {
    if (!_modifyMode) return const SizedBox();
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.tune, color: Colors.blue[700]),
                const SizedBox(width: 8),
                Text(
                  "Route Customization",
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[700],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            // Control Buttons
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildControlButton(
                  "Reverse Route",
                  Icons.swap_horiz,
                  Colors.blue,
                  _reverseRoute,
                ),
                _buildControlButton(
                  "${AppLocalizations.of(context).clear}",
                  Icons.clear_all,
                  Colors.orange,
                  _clearAllWaypoints,
                ),
                if (_waypoints.length > 1)
                  _buildControlButton(
                    _reorderMode ? "Done Reordering" : "Reorder",
                    _reorderMode ? Icons.check : Icons.swap_vert,
                    _reorderMode ? Colors.green : Colors.purple,
                    () => setState(() => _reorderMode = !_reorderMode),
                  ),
              ],
            ),
            
            // Waypoints List
            if (_waypoints.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                _reorderMode ? "Drag to reorder:" : "Waypoints:",
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: _reorderMode ? 80 : 60,
                child: _reorderMode 
                    ? ReorderableListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _waypoints.length,
                        onReorder: _reorderWaypoint,
                        itemBuilder: (context, index) {
                          return Padding(
                            key: Key('waypoint_$index'),
                            padding: const EdgeInsets.only(right: 8),
                            child: _buildWaypointChip(index, true),
                          );
                        },
                      )
                    : ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _waypoints.length,
                        itemBuilder: (context, index) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: _buildWaypointChip(index, false),
                          );
                        },
                      ),
              ),
            ],
            
            // Instruction Text
            const SizedBox(height: 8),
            Text(
              _reorderMode 
                  ? "Drag waypoints to reorder them" 
                  : "Tap on map to add waypoints",
              style: TextStyle(
                fontStyle: FontStyle.italic,
                color: Colors.grey[600],
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlButton(String text, IconData icon, Color? color, VoidCallback onPressed) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(text, style: const TextStyle(fontSize: 12)),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
    );
  }

  Widget _buildWaypointChip(int index, bool isReorderMode) {
    return Chip(
      label: Text("Stop ${index + 1}"),
      backgroundColor: isReorderMode ? Colors.purple[100] : Colors.orange[100],
      deleteIcon: isReorderMode ? const Icon(Icons.drag_handle) : const Icon(Icons.close),
      onDeleted: isReorderMode ? null : () => _removeWaypoint(index),
    );
  }

  Widget _buildActionButtons() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey[300]!)),
      ),
      child: Column(
        children: [
          if (!_modifyMode && startPoint != null && arrivalPoint != null)
            _buildMainButton(
              "${AppLocalizations.of(context).modifyRoute}",
              Icons.tune,
              Colors.blue,
              () => setState(() {
                _modifyMode = true;
                _waypoints.clear();
                _reorderMode = false;
              }),
            ),
          
          if (_modifyMode) ...[
            Row(
              children: [
                Expanded(
                  child: _buildMainButton(
                    "${AppLocalizations.of(context).cancel}",
                    Icons.close,
                    Colors.grey,
                    () => setState(() {
                      _modifyMode = false;
                      _waypoints.clear();
                      _reorderMode = false;
                      _tryFetchRoute();
                    }),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMainButton(
                    "Save Offer",
                    Icons.check,
                    Colors.green,
                    _saveOffer,
                  ),
                ),
              ],
            ),
          ] else if (selectedRouteIndex != null) ...[
            _buildMainButton(
              "${AppLocalizations.of(context).saveRoute}",
              Icons.star,
              Colors.amber,
              _saveRoute,
            ),
            const SizedBox(height: 8),
            _buildMainButton(
              "${AppLocalizations.of(context).createOffer}",
              Icons.directions_car,
              Colors.green,
              _saveOffer,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMainButton(String text, IconData icon, Color color, VoidCallback onPressed) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(text),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
  
  //fn to save a route directly from this page instead of going to the starred route page
  Future<void> _saveRoute() async {
    if (selectedRouteIndex == null) return;
    
    final route = allRoutes[selectedRouteIndex!];
    final TextEditingController nameController = TextEditingController();
    
    final String? customName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("${AppLocalizations.of(context).saveRoute}"),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
            hintText: "Enter a name for this route",
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("${AppLocalizations.of(context).cancel}"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, nameController.text.trim()),
            child: const Text("Save"),
          ),
        ],
      ),
    );

    if (customName != null && customName.isNotEmpty) {
      // Save route logic here
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("⭐ Route saved as '$customName'")),
      );
    }
  }

  // main builder
  Widget _buildFormSection() {
    return Expanded(
      flex: 2,
      child: SingleChildScrollView(
        child: Column(
          children: [
            // Search Bars
            Card(
              margin: const EdgeInsets.all(12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _buildSearchBar(true),
                    const SizedBox(height: 12),
                    _buildSearchBar(false),
                  ],
                ),
              ),
            ),

            // Basic Info Row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          children: [
                            const Icon(Icons.people, size: 20, color: Colors.blue),
                            const SizedBox(height: 4),
                            DropdownButton<int>(
                              value: passengers,
                              items: List.generate(4, (i) => i + 1)
                                  .map((num) => DropdownMenuItem(
                                        value: num,
                                        child: Text("$num"),
                                      ))
                                  .toList(),
                              onChanged: (val) => setState(() => passengers = val!),
                              underline: const SizedBox(),
                              isDense: true,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          children: [
                            const Icon(Icons.access_time, size: 20, color: Colors.green),
                            const SizedBox(height: 4),
                            TextButton(
                              onPressed: _pickStartTime,
                              child: Text(
                                selectedStartTime == null
                                    ? "${AppLocalizations.of(context).time}"
                                    : "${selectedStartTime!.hour.toString().padLeft(2, '0')}:${selectedStartTime!.minute.toString().padLeft(2, '0')}",
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Starred Routes Dropdown
            if (userModel.currentUser?.starredRoutes != null && userModel.currentUser!.starredRoutes!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.star, size: 20, color: Colors.amber[700]),
                            const SizedBox(width: 8),
                            Text(
                              "Saved Routes",
                              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          decoration: const InputDecoration(
                            hintText: "Select a saved route",
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12),
                          ),
                          items: userModel.currentUser!.starredRoutes!.keys.map((key) {
                            return DropdownMenuItem<String>(
                              value: key,
                              child: Text(key),
                            );
                          }).toList(),
                          onChanged: (val) async {
                            if (val != null) {
                              final List<dynamic> points =
                                  userModel.currentUser?.starredRoutes![val]!['route'] ?? [];

                              final latLngs = points
                                  .map((p) => LatLng(
                                        (p['lat'] as num).toDouble(),
                                        (p['lng'] as num).toDouble(),
                                      ))
                                  .toList();
                              final selectedRoute = await buildRouteOptionFromOsrm(latLngs);
                              setState(() {
                                allRoutes.clear();
                                allRoutes.add(selectedRoute);
                                selectedRouteIndex = 0;
                                etaMinutesRaw = selectedRoute.etaMinutes;
                                eta = "${selectedRoute.etaMinutes} min";
                                startPoint = selectedRoute.points.first;
                                arrivalPoint = selectedRoute.points.last;
                                _waypoints.clear();
                              });
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // Route Info Card
            if (selectedRouteIndex != null) _buildRouteInfoCard(),

            // Waypoint Controls
            _buildWaypointControls(),
          ],
        ),
      ),
    );
  }

  // map builder uses BaseMapWidget with the startArrivalOverlay and RouteOverlay defined in lib/widgets/
  Widget _buildMapSection() {
    return Expanded(
      flex: 3,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Card(
          elevation: 4,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: BaseMapWidget(
              onTap: (tapPos, latLng) => _handleTap(tapPos, latLng),
              overlays: [
                StartArrivalOverlay(
                  startPoint: startPoint,
                  arrivalPoint: arrivalPoint,
                  onStartRemoved: () => setState(() => startPoint = null),
                  onArrivalRemoved: () => setState(() => arrivalPoint = null),
                ),
                RouteOverlay(
                  routes: allRoutes,
                  selectedRouteIndex: selectedRouteIndex,
                  onRouteSelected: (i) => setState(() => _handleRouteSelection(i)),
                ),
                if (_modifyMode && _waypoints.isNotEmpty)
                  MarkerLayer(
                    markers: _waypoints.asMap().entries.map((entry) {
                      final index = entry.key;
                      return Marker(
                        point: entry.value,
                        width: 35,
                        height: 35,
                        child: GestureDetector(
                          onTap: () => _removeWaypoint(index),
                          child: Container(
                            decoration: BoxDecoration(
                              color: _reorderMode ? Colors.purple : Colors.orange,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: Center(
                              child: Text(
                                "${index + 1}",
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text("${AppLocalizations.of(context).createOffer}"),
        backgroundColor: Colors.redAccent,
        centerTitle: true,
        elevation: 0,
      ),
      endDrawer: DrawerMenu(userModel: widget.userModel),
      body: Column(
        children: [
          // Form Section (Scrollable)
          _buildFormSection(),

          // Map Section (Fixed Height)
          _buildMapSection(),

          // Action Buttons (Fixed at bottom)
          _buildActionButtons(),
        ],
      ),
    );
  }

  Widget _buildSearchBar(bool isStart) {
    final controller = isStart ? startController : arrivalController;
    final suggestions = isStart ? startSuggestions : arrivalSuggestions;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isStart ? "Departure Location" : "Destination",
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: isStart ? "Enter start point..." : "Enter destination...",
            border: const OutlineInputBorder(),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            prefixIcon: Icon(isStart ? Icons.location_on : Icons.flag, size: 20),
          ),
          onChanged: (value) => _searchLocation(value, isStart),
        ),
        if (suggestions.isNotEmpty)
          Container(
            height: 100,
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(4),
            ),
            child: ListView.builder(
              itemCount: suggestions.length,
              itemBuilder: (context, index) {
                final s = suggestions[index];
                return ListTile(
                  dense: true,
                  leading: const Icon(Icons.place, size: 16),
                  title: Text(
                    s["label"],
                    style: const TextStyle(fontSize: 12),
                  ),
                  onTap: () => _selectSuggestion(s, isStart),
                );
              },
            ),
          ),
      ],
    );
  }
}

// defined multiple times consider refractoring
class Car {
  String brand;
  String model;
  Car({required this.brand, required this.model});
  
  factory Car.fromJson(Map<String, dynamic> json) {
    return Car(
      brand: json['brand'] as String,
      model: json['model'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
        'brand': brand,
        'model': model,
      };
}

class CreateOfferModel {
  final int driver_id;
  final List<LatLng> route;
  final LatLng start;
  final LatLng arrival;
  final DateTime start_time;
  final DateTime arrival_time;
  final bool negotiable_route;
  Car? auto;
  final int seats_available;

  CreateOfferModel({
    required this.driver_id,
    required this.route,
    required this.start,
    required this.arrival,
    required this.start_time,
    required this.arrival_time,
    required this.negotiable_route,
    this.auto,
    required this.seats_available,
  });

  Map<String, dynamic> _latLngToJson(LatLng point) {
    return {
      'lat': point.latitude,
      'lng': point.longitude,
    };
  }

  Map<String, dynamic> toJson() {
    return {
      'driver_id': driver_id,
      'start': _latLngToJson(start),
      'arrival': _latLngToJson(arrival),
      'start_time': start_time.toUtc().toIso8601String(),
      'arrival_time': arrival_time.toUtc().toIso8601String(),
      'route': {
        'route': route.map(_latLngToJson).toList(),
      },
      'negotiable_route': negotiable_route,
      'auto': auto?.toJson(),
      'seats_available': seats_available,
    };
  }

  factory CreateOfferModel.fromJson(Map<String, dynamic> json) {
    return CreateOfferModel(
      driver_id: json['driver_id'] as int,
      route: (json['route']['route'] as List)
          .map((point) => LatLng(point['lat'] as double, point['lng'] as double))
          .toList(),
      start: LatLng(json['start']['lat'] as double, json['start']['lng'] as double),
      arrival: LatLng(json['arrival']['lat'] as double, json['arrival']['lng'] as double),
      start_time: DateTime.parse(json['start_time'] as String),
      arrival_time: DateTime.parse(json['arrival_time'] as String),
      negotiable_route: json['negotiable_route'] as bool,
      auto: json['auto'] != null ? Car.fromJson(json['auto']) : null,
      seats_available: json['seats_available'] as int? ?? 1,
    );
  }
}