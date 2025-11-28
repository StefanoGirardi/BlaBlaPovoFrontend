import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:multi_user_flutter_app/l10n/app_localizations.dart';
import 'package:multi_user_flutter_app/models/user_model.dart';
import 'package:multi_user_flutter_app/models/request_model.dart';
import 'package:multi_user_flutter_app/routes.dart';
import 'package:multi_user_flutter_app/utils/sse_utils.dart'; // Import SSE utils
import 'package:multi_user_flutter_app/widgets/base_map_widget.dart';
import 'package:multi_user_flutter_app/widgets/drawer_menu.dart';
import 'package:multi_user_flutter_app/widgets/map_widget.dart';
import 'package:multi_user_flutter_app/widgets/route_overlay.dart';
import 'package:multi_user_flutter_app/widgets/start_arrival_overlay.dart';

class RequestDetail extends StatefulWidget {
  final UserModel userModel;
  const RequestDetail({super.key, required this.userModel});

  @override
  State<RequestDetail> createState() => _RequestDetailState(userModel: userModel);
}

class _RequestDetailState extends State<RequestDetail> {
  LatLng? pickup;
  LatLng? dropoff;
  RequestModel? requestModel;
  List<RouteOption> allRoutes = [];
  int? selectedRouteIndex;

  final UserModel userModel;

  String? _startName;
  String? _arrivalName;

  // SSE service for real-time updates
  late RequestService _requestService;
  StreamSubscription<BroadcastResource>? _requestSubscription;

  _RequestDetailState({required this.userModel});

  @override
  void initState() {
    super.initState();
    _initializeSSE();
  }

  void _initializeSSE() {
    _requestService = RequestService();
    _requestSubscription = _requestService.connect().listen(
      (BroadcastResource resource) {
        _handleSSEEvent(resource);
      },
      onError: (error) {
        print('SSE error: $error');
      },
    );
  }

  void _handleSSEEvent(BroadcastResource resource) {
    if (resource.type == 'modified' && requestModel != null) {
      // Check if the modified request is the current one
      if (resource.id == requestModel!.session_id) {
        _refreshRequestData();
      }
    } else if (resource.type == 'deleted' && requestModel != null) {
      // Check if the deleted request is the current one
      if (resource.id == requestModel!.session_id) {
        _handleRequestDeleted();
      }
    }
  }

  Future<void> _refreshRequestData() async {
    if (requestModel == null) return;

    try {
      final getUrl = "$apiBaseUrl/api/get_request/${requestModel!.session_id}";
      final getRes = await http.get(
        Uri.parse(getUrl),
        headers: {
          'Content-Type': 'application/json',
          "Authorization": "Bearer ${await userModel.jwt.getAccessToken()}"
        },
      );

      if (getRes.statusCode == 200 || getRes.statusCode == 201) {
        final Map<String, dynamic> data = jsonDecode(getRes.body);
        
        if (mounted) {
          setState(() {
            // Update the request model with fresh data
            requestModel = RequestModel.fromJson(data);
            
            // Reload place names
            _loadPlaceNames();
          });
          
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Request updated with latest changes"),
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else {
        print("⚠️ Could not refetch request: ${getRes.statusCode}");
      }
    } catch (e) {
      print("Error refreshing request data: $e");
    }
  }

  void _handleRequestDeleted() {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("This request has been deleted by the passenger"),
          duration: Duration(seconds: 3),
        ),
      );
      
      // Navigate back to home page after a short delay
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/');
        }
      });
    }
  }

  @override
  void dispose() {
    _requestSubscription?.cancel();
    _requestService.disconnect();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (requestModel == null) {
      requestModel = ModalRoute.of(context)!.settings.arguments as RequestModel;
      _loadPlaceNames();
    }
  }

  Future<void> _loadPlaceNames() async {
    final startName = await getPlaceName(
      requestModel!.start.latitude,
      requestModel!.start.longitude,
    );
    final arrivalName = await getPlaceName(
      requestModel!.arrival.latitude,
      requestModel!.arrival.longitude,
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

  /// Forward geocoding for search
  Future<List<LatLng>> searchPlaces(String query) async {
    final url = Uri.parse(
        "https://photon.komoot.io/api/?q=$query&lang=it&limit=5");
  
    final response = await http.get(url);
  
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final features = data["features"] as List?;
  
      if (features != null) {
        return features.map<LatLng>((f) {
          final geometry = f["geometry"] as Map<String, dynamic>;
          final coords = geometry["coordinates"] as List;
          return LatLng(coords[1], coords[0]);
        }).toList();
      }
    }
    return [];
  }

  void _handleTap(TapPosition tap, LatLng point) {
    if (requestModel == null) return;
    
    setState(() {
      if (pickup == null) {
        pickup = point;
      } else if (dropoff == null) {
        dropoff = point;
        _fetchRoute();
      }
    });
  }

  Future<void> _fetchRoute() async {
    if (pickup == null || dropoff == null) return;

    final url = "https://router.project-osrm.org/route/v1/driving/"
        "${pickup!.longitude},${pickup!.latitude};"
        "${dropoff!.longitude},${dropoff!.latitude}"
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
        }
      });
    }
  }

  void _handleRouteSelection(int index) {
    setState(() {
      selectedRouteIndex = index;
    });
  }

  Future<void> _takeRequest() async {
    if (requestModel == null || pickup == null || dropoff == null || selectedRouteIndex == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("${AppLocalizations.of(context).takeReqBanner}")),
      );
      return;
    }

    final selectedRoute = allRoutes[selectedRouteIndex!];
    final String url = "$apiBaseUrl/api/take_request";
    final body = {
      'session_id': requestModel!.session_id,
      'start': _latLngToJson(pickup!),
      'arrival': _latLngToJson(dropoff!),
      'route': {
        'route': selectedRoute.points.map((p) => _latLngToJson(p)).toList()
      },
    };

    try {
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
          SnackBar(content: Text('${AppLocalizations.of(context).reqAccSucc}')),
        );

        // Create updated request model with the new route information
        final updatedRequest = RequestModel(
          session_id: requestModel!.session_id,
          passenger_id: requestModel!.passenger_id,
          driver_id: requestModel!.driver_id ?? userModel.currentUser!.id, // Use existing driver_id or current user
          start: requestModel!.start,
          arrival: requestModel!.arrival,
          driver_start: pickup,
          driver_arrival: dropoff,
          route: selectedRoute.points,
          startTime: requestModel!.startTime,
        );

        // Navigate to review page to see the accepted request
        Navigator.pushReplacementNamed(
          context, 
          '/request_review',
          arguments: updatedRequest,
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${AppLocalizations.of(context).reqAccFail}: ${response.statusCode} - ${response.body}')),
        );
      }
    } catch (e) {
      debugPrint('Network error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Network error: $e')),
      );
    }
  }

  Future<void> _deleteRequest() async {
    if (requestModel == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("${AppLocalizations.of(context).deleteRequest}"),
        content: Text("${AppLocalizations.of(context).delReqBanner}"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text("${AppLocalizations.of(context).cancel}"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text("${AppLocalizations.of(context).delete}"),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final response = await http.delete(
          Uri.parse("$apiBaseUrl/api/delete_request/${requestModel!.session_id}"),
          headers: {
            'Content-Type': 'application/json',
            "Authorization":"Bearer ${await userModel.jwt.getAccessToken()}"
          },
        );

        if (response.statusCode == 200) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${AppLocalizations.of(context).reqDelSucc}')),
          );
          Navigator.pop(context);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${AppLocalizations.of(context).reqDelFail}: ${response.statusCode}')),
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

  bool _isOwner() {
    return userModel.currentUser?.id == requestModel?.passenger_id;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("${AppLocalizations.of(context).request} ${AppLocalizations.of(context).details}"),
        backgroundColor: Colors.redAccent,
        centerTitle: true,
        actions: [
          if (_isOwner())
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.white),
              onPressed: _deleteRequest,
              tooltip: "${AppLocalizations.of(context).deleteRequest}",
            ),
        ],
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
                Card(
                  elevation: 2.0,
                  color: Colors.redAccent.shade200,
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      "${AppLocalizations.of(context).requestedTime}: ${requestModel?.startTime.toLocal().toString() ?? 'Not specified'}",
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                if (_startName != null) 
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2.0),
                    child: Text("${AppLocalizations.of(context).from}: $_startName"),
                  ),
                if (_arrivalName != null) 
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2.0),
                    child: Text("${AppLocalizations.of(context).to}: $_arrivalName"),
                  ),
                if (selectedRouteIndex != null && allRoutes.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2.0),
                    child: Text(
                      "${AppLocalizations.of(context).selRoute}: ${allRoutes[selectedRouteIndex!].distanceKm.toStringAsFixed(1)} km • ${allRoutes[selectedRouteIndex!].etaMinutes} min",
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
                    ),
                  ),
                if (_isOwner())
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Row(
                      children: [
                        Icon(Icons.person, size: 16, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text(
                          "Your request",
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          // ======= SEARCH BARS =======
          if (!_isOwner()) ...[
            if (pickup == null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: TypeAheadField<LatLng>(
                  suggestionsCallback: searchPlaces,
                  builder: (context, controller, focusNode) {
                    return TextField(
                      controller: controller,
                      focusNode: focusNode,
                      decoration: InputDecoration(
                        labelText: "${AppLocalizations.of(context).searchPick}",
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.location_on),
                      ),
                    );
                  },
                  itemBuilder: (context, suggestion) {
                    return ListTile(
                      leading: const Icon(Icons.place, size: 20),
                      title: Text(
                        "${suggestion.latitude.toStringAsFixed(5)}, ${suggestion.longitude.toStringAsFixed(5)}",
                        style: const TextStyle(fontSize: 12),
                      ),
                    );
                  },
                  onSelected: (suggestion) {
                    setState(() {
                      pickup = suggestion;
                    });
                  },
                ),
              ),
            if (dropoff == null && pickup != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: TypeAheadField<LatLng>(
                  suggestionsCallback: searchPlaces,
                  builder: (context, controller, focusNode) {
                    return TextField(
                      controller: controller,
                      focusNode: focusNode,
                      decoration: InputDecoration(
                        labelText: "${AppLocalizations.of(context).searchDrop}",
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.flag),
                      ),
                    );
                  },
                  itemBuilder: (context, suggestion) {
                    return ListTile(
                      leading: const Icon(Icons.place, size: 20),
                      title: Text(
                        "${suggestion.latitude.toStringAsFixed(5)}, ${suggestion.longitude.toStringAsFixed(5)}",
                        style: const TextStyle(fontSize: 12),
                      ),
                    );
                  },
                  onSelected: (suggestion) {
                    setState(() {
                      dropoff = suggestion;
                      _fetchRoute();
                    });
                  },
                ),
              ),
          ],

          // ======= ROUTE SELECTION =======
          if (!_isOwner() && allRoutes.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "${AppLocalizations.of(context).select} ${AppLocalizations.of(context).route}:",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      ...allRoutes.asMap().entries.map((entry) {
                        final index = entry.key;
                        final route = entry.value;
                        return ListTile(
                          leading: Radio<int>(
                            value: index,
                            groupValue: selectedRouteIndex,
                            onChanged: (value) => _handleRouteSelection(value!),
                          ),
                          title: Text("${AppLocalizations.of(context).route} ${index + 1}"),
                          subtitle: Text("${route.distanceKm.toStringAsFixed(1)} km • ${route.etaMinutes} min"),
                          onTap: () => _handleRouteSelection(index),
                        );
                      }).toList(),
                    ],
                  ),
                ),
              ),
            ),

          // ======= SELECTION STATUS =======
          if (!_isOwner()) ...[
            if (pickup != null && dropoff == null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Card(
                  color: Colors.blue[50],
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.blue[700], size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            "${AppLocalizations.of(context).reqSelBanner1}",
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 16),
                          onPressed: () => setState(() => pickup = null),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            if (pickup != null && dropoff != null && allRoutes.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Card(
                  color: Colors.orange[50],
                  child: const Padding(
                    padding: EdgeInsets.all(12.0),
                    child: Row(
                      children: [
                        Icon(Icons.schedule, color: Colors.orange, size: 20),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            "Calculating routes...",
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            if (pickup != null && dropoff != null && allRoutes.isNotEmpty && selectedRouteIndex != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Card(
                  color: Colors.green[50],
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.green[700], size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            "${AppLocalizations.of(context).reqSelBanner2}",
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],

          // ======= MAP =======
          Expanded(
            child: BaseMapWidget(
              onTap: _isOwner() ? null : _handleTap,
              overlays: [
                if (selectedRouteIndex != null && allRoutes.isNotEmpty)
                  RouteOverlay(
                    routes: allRoutes,
                    selectedRouteIndex: selectedRouteIndex,
                    onRouteSelected: _handleRouteSelection,
                  ),
                if (pickup != null)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: pickup!,
                        width: 40,
                        height: 40,
                        child: GestureDetector(
                          onTap: _isOwner() ? null : () => setState(() => pickup = null),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.green,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: const Icon(Icons.location_on, color: Colors.white, size: 20),
                          ),
                        ),
                      )
                    ],
                  ),
                if (dropoff != null)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: dropoff!,
                        width: 40,
                        height: 40,
                        child: GestureDetector(
                          onTap: _isOwner() ? null : () => setState(() => dropoff = null),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: const Icon(Icons.flag, color: Colors.white, size: 20),
                          ),
                        ),
                      )
                    ],
                  ),
                if (requestModel != null)
                  StartArrivalOverlay(
                    startPoint: requestModel!.start,
                    arrivalPoint: requestModel!.arrival,
                    onArrivalRemoved: () {},
                    onStartRemoved: () {},
                  ),
              ],
            ),
          ),

          // ======= ACTION BUTTONS =======
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Colors.grey[300]!)),
            ),
            child: _isOwner()
                ? Column(
                    children: [
                      Text(
                        "This is your request",
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        onPressed: _deleteRequest,
                        icon: const Icon(Icons.delete),
                        label: Text("${AppLocalizations.of(context).deleteRequest}"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 50),
                        ),
                      ),
                    ],
                  )
                : Column(
                    children: [
                      if (pickup != null && dropoff != null && selectedRouteIndex != null)
                        ElevatedButton.icon(
                          onPressed: _takeRequest,
                          icon: const Icon(Icons.directions_car),
                          label: Text("${AppLocalizations.of(context).acceptReq}"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(double.infinity, 50),
                          ),
                        ),
                      if (pickup == null || dropoff == null || selectedRouteIndex == null)
                        Text(
                          "${AppLocalizations.of(context).takeReqBanner}",
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontStyle: FontStyle.italic,
                            fontSize: 12,
                          ),
                          textAlign: TextAlign.center,
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

Map<String, dynamic> _latLngToJson(LatLng point) {
  return {
    'lat': point.latitude,
    'lng': point.longitude,
  };
}