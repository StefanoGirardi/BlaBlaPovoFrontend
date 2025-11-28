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

class NewStarredRoute extends StatefulWidget {
  final UserModel userModel;

  const NewStarredRoute({super.key, required this.userModel});

  @override
  State<NewStarredRoute> createState() =>
      _NewStarredRouteState(userModel: this.userModel);
}

class _NewStarredRouteState extends State<NewStarredRoute> {
  final UserModel userModel;
  final String apiBaseUrl = 'http://localhost:8000';
  

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

  _NewStarredRouteState({required this.userModel});

  // Define bounds constraint for Northern Italy
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
    final url = "https://router.project-osrm.org/route/v1/driving/"
        "${startPoint!.longitude},${startPoint!.latitude};"
        "${arrivalPoint!.longitude},${arrivalPoint!.latitude}"
        "?overview=full&geometries=geojson&alternatives=true";

    final res = await http.get(Uri.parse(url));
    if (res.statusCode == 200) {
      final data = json.decode(res.body);
      final routes = data["routes"] as List;
      print("Number of routes: ${routes.length}");

      setState(() {
        allRoutes.clear();

        for (var route in routes.take(3)) {
          final coords = route["geometry"]["coordinates"];
          final points = coords
              .map<LatLng>((c) => LatLng(c[1].toDouble(), c[0].toDouble()))
              .toList();

          final durationSec = route["duration"] as num? ?? 0;
          final minutes = (durationSec / 60).round();

          final distanceMeters = route["distance"] as num? ?? 0;
          final distanceKm = (distanceMeters / 1000).toDouble();

          // ✅ Skip invalid routes
          if (distanceKm.isNaN || distanceKm.isInfinite) {
            print("⚠️ Skipping invalid route (NaN/Infinity distance)");
            continue;
          }

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
        }
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

  Future<void> saveRoute(int id, String? name, List<LatLng> route) async {
    try {
      final body = {
        'name': name,
        'route': {
          'route': route
              .map((p) => {'lat': p.latitude, 'lng': p.longitude})
              .toList()
        },
      };
      final response = await http.patch(
        Uri.parse('$apiBaseUrl/api/users/$id/new_starred_route'),
        headers: {
          'Content-Type': 'application/json',
          "Authorization":"Bearer ${await userModel.jwt.getAccessToken()}"
        },
        body: jsonEncode(body),
      );
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('✓ ${AppLocalizations.of(context).routeSavedSucc}')),
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

      allRoutes.clear();
      selectedRouteIndex = null;
      eta = null;
      etaMinutesRaw = null;
      etaMarkerPoint = null;
    });
    _tryFetchRoute();
  }

  void _onMapTap(TapPosition tapPosition, LatLng latlng) {
    setState(() {
      if (startPoint == null) {
        startPoint = latlng;
      } else if (arrivalPoint == null) {
        arrivalPoint = latlng;
      } else {
        // Do nothing – both are already set.
      }

      if (startPoint != null && arrivalPoint != null) {
        _fetchRoute();
      }
    });
  }

  void _handleRouteSelection(int index) {
    setState(() {
      selectedRouteIndex = index;
      final route = allRoutes[index];
      etaMinutesRaw = route.etaMinutes;
      eta = "${route.etaMinutes} min";
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title:  Text("${AppLocalizations.of(context).registerNewRoute}"),
        backgroundColor: Colors.redAccent,
        centerTitle: true,
      ),
      endDrawer: DrawerMenu(userModel: widget.userModel),
      body: Column(
        children: [
          _buildSearchBar(true),
          _buildSearchBar(false),
          Expanded(
            child: BaseMapWidget(
              onTap: (tapPos, latLng) => _onMapTap(tapPos, latLng),
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
                  onRouteSelected: (i) =>
                      setState(() => _handleRouteSelection(i)),
                ),
              ],
            ),
          ),
          if (selectedRouteIndex != null)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "${AppLocalizations.of(context).from}: ${startController.text.isEmpty ? '${AppLocalizations.of(context).startPoint}' : startController.text}",
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    "${AppLocalizations.of(context).to}: ${arrivalController.text.isEmpty ? '${AppLocalizations.of(context).destination}' : arrivalController.text}",
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  Builder(builder: (context) {
                    double distance =
                        allRoutes[selectedRouteIndex!].distanceKm;
                    String distanceText = (distance.isNaN || distance.isInfinite)
                        ? "N/A"
                        : "${distance.toStringAsFixed(1)} km";
                    return Text(
                      "${AppLocalizations.of(context).distance}: $distanceText",
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600),
                    );
                  }),
                ],
              ),
            ),
          if (selectedRouteIndex != null)
            ElevatedButton.icon(
              onPressed: () async {
                final route = allRoutes[selectedRouteIndex!];

                final TextEditingController nameController =
                    TextEditingController();
                final String? customName = await showDialog<String>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text("${AppLocalizations.of(context).saveRoute}"),
                    content: TextField(
                      controller: nameController,
                      decoration: InputDecoration(
                        hintText: "${AppLocalizations.of(context).nameForRoute}",
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text("${AppLocalizations.of(context).cancel}"),
                      ),
                      ElevatedButton(
                        onPressed: () =>
                            Navigator.pop(context, nameController.text.trim()),
                        child: Text("${AppLocalizations.of(context).save}"),
                      ),
                    ],
                  ),
                );

                if (customName != null && customName.isNotEmpty) {
                  setState(() {
                    userModel.currentUser!.starredRoutes![customName] = {
                      'route': route.points
                          .map((p) =>
                              {'lat': p.latitude, 'lng': p.longitude})
                          .toList(),
                    };
                  });

                  final List<dynamic> points =
                      userModel.currentUser?.starredRoutes![customName]!['route']
                          ?? [];

                  final latLngs = points
                      .map((p) => LatLng(
                            (p['lat'] as num).toDouble(),
                            (p['lng'] as num).toDouble(),
                          ))
                      .toList();

                  saveRoute(userModel.currentUser!.id, customName, latLngs);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("⭐ ${AppLocalizations.of(context).routeSaved} '$customName'")),
                  );
                }
              },
              icon: const Icon(Icons.star),
              label: Text("${AppLocalizations.of(context).saveRoute}"),
              style:
                  ElevatedButton.styleFrom(backgroundColor: Colors.amber),
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
