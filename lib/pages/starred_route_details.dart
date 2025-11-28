import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'package:multi_user_flutter_app/l10n/app_localizations.dart';
import 'package:multi_user_flutter_app/models/user_model.dart';
import 'package:multi_user_flutter_app/routes.dart';
import 'package:multi_user_flutter_app/widgets/base_map_widget.dart';
import 'package:multi_user_flutter_app/widgets/drawer_menu.dart';
import 'package:multi_user_flutter_app/widgets/map_widget.dart';
import 'package:multi_user_flutter_app/widgets/route_overlay.dart';

class StarredDetails extends StatefulWidget {
  final UserModel userModel;

  const StarredDetails({super.key, required this.userModel});

  @override
  State<StarredDetails> createState() =>
      _StarredDetailsState(userModel: userModel);
}

class _StarredDetailsState extends State<StarredDetails> {
  final UserModel userModel;
  List<LatLng>? route;
  RouteOption? routeOption;
  LatLng? startPoint;
  LatLng? arrivalPoint;

  String? _startName;
  String? _arrivalName;
  bool modify = false;
  String _routeName = "";
  bool _isReversed = false;
  
  // Track which points are being edited
  List<LatLng> _waypoints = [];
  bool _reorderMode = false;
  
  _StarredDetailsState({required this.userModel});

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (route == null) {
      final args = ModalRoute.of(context)!.settings.arguments as List<dynamic>;
      route = args.first as List<LatLng>;
      String name = args[1] as String;
      startPoint = route!.first;
      arrivalPoint = route!.last;
      _routeName = name;
      _buildRoute();
      _loadPlaceNames();
    }
  }

  Future<void> _buildRoute() async {
    if (route != null) {
      final r = await buildRouteOptionFromOsrm(route!);
      setState(() {
        routeOption = r;
      });
    }
  }

  Future<void> _tryFetchRoute() async {
    if (startPoint != null && arrivalPoint != null) {
      await _fetchRoute();
    } else {
      setState(() {
        routeOption = null;
      });
    }
  }

  Future<void> _fetchRoute() async {
    List<LatLng> coords = List.from([startPoint!]);
    coords.addAll(_waypoints);
    coords.add(arrivalPoint!);
    final coordsFinal =
        coords.map((p) => "${p.longitude},${p.latitude}").join(";");

    final url = "https://router.project-osrm.org/route/v1/driving/"
        "$coordsFinal"
        "?overview=full&geometries=geojson";

    final res = await http.get(Uri.parse(url));
    if (res.statusCode == 200) {
      final data = json.decode(res.body);
      final routes = data["routes"] as List;
      print("Number of routes: ${routes.length}");

      setState(() {
        var route = routes.take(1).first;
        final coords = route["geometry"]["coordinates"];
        final points = coords
            .map<LatLng>((c) => LatLng(c[1].toDouble(), c[0].toDouble()))
            .toList();

        final durationSec = route["duration"] as num;
        final minutes = (durationSec / 60).round();

        final distanceMeters = route["distance"] as num;
        final distanceKm = (distanceMeters / 1000).toDouble();

        routeOption = RouteOption(
          points: points,
          etaMinutes: minutes,
          distanceKm: distanceKm,
        );
      });
    }
  }

  Future<void> _loadPlaceNames() async {
    final startName = await getPlaceName(
      route!.first.latitude,
      route!.first.longitude,
    );
    final arrivalName = await getPlaceName(
      route!.last.latitude,
      route!.last.longitude,
    );
    setState(() {
      _startName = startName;
      _arrivalName = arrivalName;
    });
  }

  /// Reverse geocoding
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

  void _handleTap(TapPosition tap, LatLng point) async {
    if (modify && !_reorderMode) {
      setState(() {
        _waypoints.add(point);
        print("Added waypoint: $point");
        _tryFetchRoute();
      });
    }
  }

  void _removeWaypoint(int index) {
    setState(() {
      _waypoints.removeAt(index);
      _tryFetchRoute();
    });
  }

  void _reorderWaypoint(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) {
        newIndex -= 1;
      }
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
    if (index > 0) {
      _swapWaypoints(index, index - 1);
    }
  }

  void _moveWaypointDown(int index) {
    if (index < _waypoints.length - 1) {
      _swapWaypoints(index, index + 1);
    }
  }

  void _reverseRoute() {
    setState(() {
      _isReversed = !_isReversed;
      if (startPoint != null && arrivalPoint != null) {
        final temp = startPoint;
        startPoint = arrivalPoint;
        arrivalPoint = temp;
        
        // Also reverse waypoints
        _waypoints = _waypoints.reversed.toList();
        
        _tryFetchRoute();
        _loadPlaceNames(); // Reload place names since start/arrival swapped
      }
    });
  }

  void _clearAllWaypoints() {
    setState(() {
      _waypoints.clear();
      _tryFetchRoute();
    });
  }

  Future<void> _patchRoute() async {
    final String url = "$apiBaseUrl/api/users/${userModel.currentUser!.id}/patch_route";

    if (routeOption != null) {
      try {
        final body = {
          'name': _routeName, 
          'route': {
            'route': routeOption!.points.map((p) => ({
              'lat': p.latitude, 
              'lng': p.longitude
            })).toList()
          },
        };
        final response = await http.patch(
          Uri.parse(url),
          body: jsonEncode(body),
          headers: {
            'Content-Type': 'application/json',
            "Authorization":"Bearer ${await userModel.jwt.getAccessToken()}"
          }
        );
        if (response.statusCode == 200) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Route: $_routeName has been modified')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to update route: ${response.statusCode}')),
          );
        }
      } catch (e) {
        debugPrint('Network error: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Network error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.redAccent,
        title: Text("${AppLocalizations.of(context).route}: $_routeName"),
      ),
      endDrawer: DrawerMenu(userModel: userModel),
      body: Column(
        children: [
          // ======= INFO PANEL =======
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_startName != null) 
                  Text("${AppLocalizations.of(context).from}: $_startName", style: TextStyle(fontWeight: FontWeight.bold)),
                if (_arrivalName != null) 
                  Text("${AppLocalizations.of(context).to}: $_arrivalName", style: TextStyle(fontWeight: FontWeight.bold)),
                if (routeOption != null) ...[
                  SizedBox(height: 8),
                  Text("${AppLocalizations.of(context).distance}: ${routeOption!.distanceKm.toStringAsFixed(1)} km"),
                  Text("${AppLocalizations.of(context).duration}: ${routeOption!.etaMinutes} min"),
                ],
              ],
            ),
          ),

          // ======= MODIFICATION CONTROLS =======
          if (modify) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Column(
                children: [
                  // Main control buttons
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _reverseRoute,
                          icon: Icon(Icons.swap_horiz),
                          label: Text(_isReversed ? "Reverse Back" : "Reverse Route"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _clearAllWaypoints,
                          icon: Icon(Icons.clear_all),
                          label: Text("${AppLocalizations.of(context).clear} Waypoints"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  
                  // Reorder mode toggle
                  if (_waypoints.length > 1)
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              setState(() {
                                _reorderMode = !_reorderMode;
                              });
                            },
                            icon: Icon(_reorderMode ? Icons.check : Icons.swap_vert),
                            label: Text(_reorderMode ? "${AppLocalizations.of(context).starBanner1}" : "${AppLocalizations.of(context).starBanner2}"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _reorderMode ? Colors.green : Colors.purple,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  
                  SizedBox(height: 8),
                  
                  // Waypoints list
                  if (_waypoints.isNotEmpty) ...[
                    Text(
                      _reorderMode ? "${AppLocalizations.of(context).starBanner3}:" : "${AppLocalizations.of(context).waypoints} ${AppLocalizations.of(context).starBanner4}:", 
                      style: TextStyle(fontWeight: FontWeight.bold)
                    ),
                    SizedBox(height: 4),
                    Container(
                      height: _reorderMode ? 150 : 60,
                      child: _reorderMode 
                          ? ReorderableListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: _waypoints.length,
                              onReorder: _reorderWaypoint,
                              itemBuilder: (context, index) {
                                return Padding(
                                  key: Key('waypoint_$index'),
                                  padding: const EdgeInsets.only(right: 8),
                                  child: Container(
                                    width: 80,
                                    child: Card(
                                      color: Colors.purple[100],
                                      child: Padding(
                                        padding: const EdgeInsets.all(8.0),
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              "${index + 1}",
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                              ),
                                            ),
                                            Icon(Icons.drag_handle, size: 20),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            )
                          : ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: _waypoints.length,
                              itemBuilder: (context, index) {
                                return Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: Container(
                                    width: 80,
                                    child: Card(
                                      color: Colors.red[100],
                                      child: Padding(
                                        padding: const EdgeInsets.all(8.0),
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              "${index + 1}",
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                              ),
                                            ),
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                if (_waypoints.length > 1) ...[
                                                  IconButton(
                                                    icon: Icon(Icons.arrow_upward, size: 16),
                                                    onPressed: () => _moveWaypointUp(index),
                                                    padding: EdgeInsets.zero,
                                                  ),
                                                  IconButton(
                                                    icon: Icon(Icons.arrow_downward, size: 16),
                                                    onPressed: () => _moveWaypointDown(index),
                                                    padding: EdgeInsets.zero,
                                                  ),
                                                ],
                                                IconButton(
                                                  icon: Icon(Icons.close, size: 16),
                                                  onPressed: () => _removeWaypoint(index),
                                                  padding: EdgeInsets.zero,
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                    SizedBox(height: 8),
                  ],
                  
                  Text(
                    _reorderMode 
                        ? "${AppLocalizations.of(context).starBanner3}" 
                        : "${AppLocalizations.of(context).starBanner5}",
                    style: TextStyle(
                      fontStyle: FontStyle.italic,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ],

          // ======= MAP =======
          Expanded(
            child: BaseMapWidget(
              onTap: (tapPos, point) async => _handleTap(tapPos, point),
              overlays: [
                if (routeOption != null)
                  RouteOverlay(
                    routes: [routeOption!],
                    selectedRouteIndex: 0,
                    onRouteSelected: (_) => setState(() => _handleRouteSelection()),
                  ),
                
                // Start and arrival markers
                if (startPoint != null)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: startPoint!,
                        width: 40,
                        height: 40,
                        child: GestureDetector(
                          onTap: () {
                            if (modify && !_reorderMode) {
                              setState(() {
                                startPoint = null;
                                _tryFetchRoute();
                              });
                            }
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: modify && !_reorderMode ? Colors.red : Colors.green,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: Icon(
                              Icons.location_on,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
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
                          onTap: () {
                            if (modify && !_reorderMode) {
                              setState(() {
                                arrivalPoint = null;
                                _tryFetchRoute();
                              });
                            }
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: modify && !_reorderMode ? Colors.red : Colors.blue,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: Icon(
                              Icons.flag,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                
                // Waypoint markers
                if (modify && _waypoints.isNotEmpty)
                  MarkerLayer(
                    markers: _waypoints.asMap().entries.map((entry) {
                      final index = entry.key;
                      final waypoint = entry.value;
                      return Marker(
                        point: waypoint,
                        width: 35,
                        height: 35,
                        child: GestureDetector(
                          onTap: () {
                            if (!_reorderMode) {
                              _removeWaypoint(index);
                            }
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: _reorderMode ? Colors.purple : Colors.orange,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: Center(
                              child: Text(
                                "${index + 1}",
                                style: TextStyle(
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

          // ======= ACTION BUTTONS =======
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                if (!modify)
                  ElevatedButton(
                    onPressed: () => setState(() {
                      modify = true;
                      _waypoints.clear();
                      _reorderMode = false;
                    }),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      minimumSize: Size(double.infinity, 50),
                    ),
                    child: Text("${AppLocalizations.of(context).modifyRoute}"),
                  ),
                
                if (modify) ...[
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => setState(() {
                            modify = false;
                            _waypoints.clear();
                            _reorderMode = false;
                            _isReversed = false;
                            // Reset to original route
                            if (route != null) {
                              startPoint = route!.first;
                              arrivalPoint = route!.last;
                              _buildRoute();
                            }
                          }),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey,
                            foregroundColor: Colors.white,
                          ),
                          child: Text("${AppLocalizations.of(context).cancel}"),
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _patchRoute,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                          ),
                          child: Text("${AppLocalizations.of(context).saveRoute}"),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _handleRouteSelection() {
    // Handle route selection if needed
  }
}