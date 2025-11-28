import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'package:multi_user_flutter_app/l10n/app_localizations.dart';
import 'package:multi_user_flutter_app/models/request_model.dart';
import 'package:multi_user_flutter_app/models/user_model.dart';
import 'package:multi_user_flutter_app/routes.dart';
import 'package:multi_user_flutter_app/utils/sse_utils.dart'; // Import SSE utils
import 'package:multi_user_flutter_app/widgets/base_map_widget.dart';
import 'package:multi_user_flutter_app/widgets/drawer_menu.dart';
import 'package:multi_user_flutter_app/widgets/map_widget.dart';
import 'package:multi_user_flutter_app/widgets/offer_route_overlay.dart';
import 'package:multi_user_flutter_app/widgets/start_arrival_overlay.dart';

class RequestReview extends StatefulWidget {
  final UserModel userModel;
  const RequestReview({super.key, required this.userModel});

  @override
  State<RequestReview> createState() => _RequestReviewState();
}

class _RequestReviewState extends State<RequestReview> {
  RequestModel? requestModel;
  RouteOption? route;

  String? _startName;
  String? _arrivalName;
  String? _driverStartName;
  String? _driverArrivalName;
  String? _driverName;
  String? _passengerName;

  bool _isLoading = true;
  bool _isModifying = false;
  LatLng? _tempDriverStart;
  LatLng? _tempDriverArrival;
  String? _modifyingStop; // 'start' or 'arrival'

  // SSE service for real-time updates
  late RequestService _requestService;
  StreamSubscription<BroadcastResource>? _requestSubscription;

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
          "Authorization": "Bearer ${await widget.userModel.jwt.getAccessToken()}"
        },
      );

      if (getRes.statusCode == 200 || getRes.statusCode == 201) {
        final Map<String, dynamic> data = jsonDecode(getRes.body);
        
        if (mounted) {
          setState(() {
            // Update the request model with fresh data
            requestModel = RequestModel.fromJson(data);
            
            // Reload route and names
            _loadRoute();
            _loadPlaceNames();
            _loadUserInfo();
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
      print('DEBUG: RequestModel loaded: ${requestModel!.toJson()}');
      _loadRoute();
      _loadPlaceNames();
      _loadUserInfo();
    }
  }

  // Show debug message as SnackBar
  void _showDebugMessage(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 5),
          backgroundColor: Colors.blue,
        ),
      );
    }
    print('DEBUG: $message');
  }

  bool get isPassenger => widget.userModel.currentUser!.id == requestModel?.passenger_id;
  bool get isDriver => widget.userModel.currentUser!.id == requestModel?.driver_id;

  // Start modification mode for a specific stop
  void _startModification(String stopType) {
    setState(() {
      _isModifying = true;
      _modifyingStop = stopType;
      _tempDriverStart = requestModel!.driver_start;
      _tempDriverArrival = requestModel!.driver_arrival;
    });
    _showDebugMessage('${AppLocalizations.of(context).tapMap} ${stopType == 'start' ? '${AppLocalizations.of(context).startPoint}' : '${AppLocalizations.of(context).arrivalPoint}'}');
  }

  // Cancel modification
  void _cancelModification() {
    setState(() {
      _isModifying = false;
      _modifyingStop = null;
      _tempDriverStart = null;
      _tempDriverArrival = null;
    });
  }

  // Update driver start point via API
  Future<bool> _updateDriverStart(LatLng newStart) async {
    try {
      final url = "$apiBaseUrl/api/modify_driver_start";
      final response = await http.patch(
        Uri.parse(url),
        headers: {
          "Authorization": "Bearer ${await widget.userModel.jwt.getAccessToken()}",
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          "session_id": requestModel!.session_id,
          "passenger_id": widget.userModel.currentUser!.id,
          "stop":{
            "lat": newStart.latitude,
            "lng": newStart.longitude,
          }
        }),
      );

      if (response.statusCode == 200) {
        print('DEBUG: Driver start updated successfully');
        return true;
      } else {
        print('DEBUG: Failed to update driver start: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('DEBUG: Error updating driver start: $e');
      return false;
    }
  }

  // Update driver arrival point via API
  Future<bool> _updateDriverArrival(LatLng newArrival) async {
    try {
      final url = "$apiBaseUrl/api/modify_driver_arrival";
      final response = await http.patch(
        Uri.parse(url),
        headers: {
          "Authorization": "Bearer ${await widget.userModel.jwt.getAccessToken()}",
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          "session_id": requestModel!.session_id,
          "passenger_id": widget.userModel.currentUser!.id,
          "stop":{
            "lat": newArrival.latitude,
            "lng": newArrival.longitude,
          }
        }),
      );

      if (response.statusCode == 200) {
        print('DEBUG: Driver arrival updated successfully');
        return true;
      } else {
        print('DEBUG: Failed to update driver arrival: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('DEBUG: Error updating driver arrival: $e');
      return false;
    }
  }

  // Confirm modification and update route
  void _confirmModification() async {
    if (_modifyingStop == null) {
      _showDebugMessage('${AppLocalizations.of(context).noStopSel}');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      bool apiSuccess = false;
      
      // Update the specific stop via API
      if (_modifyingStop == 'start' && _tempDriverStart != null) {
        apiSuccess = await _updateDriverStart(_tempDriverStart!);
      } else if (_modifyingStop == 'arrival' && _tempDriverArrival != null) {
        apiSuccess = await _updateDriverArrival(_tempDriverArrival!);
      }

      if (!apiSuccess) {
        _showDebugMessage('${AppLocalizations.of(context).failedUpd} ${_modifyingStop == 'start' ? AppLocalizations.of(context).startPoint : AppLocalizations.of(context).arrivalPoint}.');
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // Build new route with updated points
      final updatedStart = _modifyingStop == 'start' ? _tempDriverStart : requestModel!.driver_start;
      final updatedArrival = _modifyingStop == 'arrival' ? _tempDriverArrival : requestModel!.driver_arrival;

      if (updatedStart != null && updatedArrival != null) {
        final waypoints = [
          updatedStart,
          requestModel!.start, // Passenger pickup
          requestModel!.arrival, // Passenger dropoff
          updatedArrival,
        ];

        print('DEBUG: Building route with waypoints: $waypoints');
        // final newRoute = await buildRouteOptionFromOsrm(waypoints);
        final newRoute = await _fetchRoute(waypoints);
        print('DEBUG: New route built: ${newRoute!.points.length} points, ETA: ${newRoute.etaMinutes} min');

        // Update the request model with new driver points and route
        final updatedRequestModel = RequestModel(
          session_id: requestModel!.session_id,
          passenger_id: requestModel!.passenger_id,
          driver_id: requestModel!.driver_id,
          start: requestModel!.start,
          arrival: requestModel!.arrival,
          driver_start: updatedStart,
          driver_arrival: updatedArrival,
          startTime: requestModel!.startTime,
          route: newRoute.points,
        );

        setState(() {
          requestModel = updatedRequestModel;
          route = newRoute;
        });
      }

      setState(() {
        _isModifying = false;
        _modifyingStop = null;
        _tempDriverStart = null;
        _tempDriverArrival = null;
      });

      // Reload place names for the updated driver points
      await _loadDriverPlaceNames();
      
      _showDebugMessage('${_modifyingStop == 'start' ? '${AppLocalizations.of(context).startPoint}' : '${AppLocalizations.of(context).arrivalPoint}'} ${AppLocalizations.of(context).succUpd}!');
    } catch (e) {
      print('DEBUG: Error updating route: $e');
      _showDebugMessage('Error updating route: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<RouteOption?> _fetchRoute(List<LatLng> points) async {
    final coordsFinal = points.map((p) => "${p.longitude},${p.latitude}").join(";");
  
    final url = "https://router.project-osrm.org/route/v1/driving/"
        "$coordsFinal"
        "?overview=full&geometries=geojson&alternatives=false";
  
    final res = await http.get(Uri.parse(url));
    if (res.statusCode == 200) {
      final data = json.decode(res.body);
      final routes = data["routes"] as List;
      
      if (routes.isEmpty) {
        print('DEBUG: No routes found in OSRM response');
        return null;
      }
      
      // Get the first route from the list
      final route = routes[0];
      final coords = route["geometry"]["coordinates"] as List;
      final points = coords
          .map<LatLng>((c) => LatLng(c[1].toDouble(), c[0].toDouble()))
          .toList();
      final durationSec = route["duration"] as num;
      final minutes = (durationSec / 60).round();
      final distanceMeters = route["distance"] as num;
      final distanceKm = (distanceMeters / 1000).toDouble();
      
      return RouteOption(
        points: points,
        etaMinutes: minutes,
        distanceKm: distanceKm,
      );
    } else {
      print('DEBUG: OSRM API error: ${res.statusCode} - ${res.body}');
      return null;
    }
  }

  void _handleMapTap(TapPosition tapPosition, LatLng point) {
    if (!_isModifying || _modifyingStop == null) return;

    setState(() {
      if (_modifyingStop == 'start') {
        _tempDriverStart = point;
        _showDebugMessage('${AppLocalizations.of(context).reqRevBanner1}');
      } else if (_modifyingStop == 'arrival') {
        _tempDriverArrival = point;
        _showDebugMessage('${AppLocalizations.of(context).reqRevBanner2}');
      }
    });
  }

  Future<void> _loadRoute() async {
    if (requestModel != null) {
      print('DEBUG: Route data in requestModel: ${requestModel!.route}');
      
      // Check if we have route points in requestModel
      if (requestModel!.route != null && requestModel!.route!.isNotEmpty) {
        print('DEBUG: Found ${requestModel!.route!.length} route points in requestModel');
        try {
          // Build route from the existing route points in requestModel
          final r = await buildRouteOptionFromOsrm(requestModel!.route!);
          print('DEBUG: Route built successfully: ${r.points.length} points, ETA: ${r.etaMinutes} min');
          
          if (mounted) {
            setState(() {
              route = r;
            });
          }
        } catch (e) {
          print('DEBUG: Error building route: $e');
          // Fallback: Create basic route option
          if (mounted) {
            setState(() {
              route = RouteOption(
                points: requestModel!.route!,
                etaMinutes: 0,
                distanceKm: 0.0,
              );
            });
          }
        }
      } else {
        print('DEBUG: No route data available in requestModel');
        // Create a route that includes passenger points
        if (requestModel!.driver_start != null && requestModel!.driver_arrival != null) {
          final waypoints = [
            requestModel!.driver_start!,
            requestModel!.start,
            requestModel!.arrival,
            requestModel!.driver_arrival!,
          ];
          try {
            final newRoute = await buildRouteOptionFromOsrm(waypoints);
            if (mounted) {
              setState(() {
                route = newRoute;
              });
            }
          } catch (e) {
            print('DEBUG: Error building fallback route: $e');
          }
        }
      }
    }
  }

  Future<void> _loadUserInfo() async {
    try {
      // Load passenger's name using the passenger_id from requestModel
      final passengerName = await getUsername(requestModel!.passenger_id, (await widget.userModel.jwt.getAccessToken())!);
      print('DEBUG: Loaded passenger name: $passengerName for ID: ${requestModel!.passenger_id}');
      
      if (mounted) {
        setState(() {
          _passengerName = passengerName;
        });
      }

      // Load driver's info - SHOULD ALWAYS EXIST in RequestReview page
      if (requestModel!.driver_id != null) {
        final driverName = await getUsername(requestModel!.driver_id!, (await widget.userModel.jwt.getAccessToken())!);
        print('DEBUG: Loaded driver name: $driverName for ID: ${requestModel!.driver_id}');
        
        if (mounted) {
          setState(() {
            _driverName = driverName;
          });
        }

        // Load driver's start and arrival place names
        await _loadDriverPlaceNames();
      } else {
        print('WARNING: driver_id is null in requestModel - this should not happen in RequestReview');
      }
    } catch (e) {
      print('DEBUG: Error loading user info: $e');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _showDebugMessage('${AppLocalizations.of(context).reqRevBanner3}: $e');
        }
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadDriverPlaceNames() async {
    if (requestModel!.driver_start != null) {
      final driverStartName = await getPlaceName(
        requestModel!.driver_start!.latitude,
        requestModel!.driver_start!.longitude,
      );
      print('DEBUG: Loaded driver start name: $driverStartName');
      if (mounted) {
        setState(() {
          _driverStartName = driverStartName;
        });
      }
    }

    if (requestModel!.driver_arrival != null) {
      final driverArrivalName = await getPlaceName(
        requestModel!.driver_arrival!.latitude,
        requestModel!.driver_arrival!.longitude,
      );
      print('DEBUG: Loaded driver arrival name: $driverArrivalName');
      if (mounted) {
        setState(() {
          _driverArrivalName = driverArrivalName;
        });
      }
    }
  }

  Future<void> _loadPlaceNames() async {
    try {
      final startName = await getPlaceName(
        requestModel!.start.latitude,
        requestModel!.start.longitude,
      );
      final arrivalName = await getPlaceName(
        requestModel!.arrival.latitude,
        requestModel!.arrival.longitude,
      );
      if (mounted) {
        setState(() {
          _startName = startName;
          _arrivalName = arrivalName;
        });
      }
    } catch (e) {
      print('DEBUG: Error loading place names: $e');
    }
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

  Future<String?> getUsername(int id, String token) async {
    try {
      final response = await http.get(
        Uri.parse("$apiBaseUrl/api/get_user_full_name/$id"),
        headers: {
          "Authorization": "Bearer $token"
        },
      );
      
      if (response.statusCode == 200) {
        final username = response.body.trim();
        return username.isNotEmpty ? username : 'Unknown User';
      } else if (response.statusCode == 404) {
        return 'User Not Found';
      } else {
        print('DEBUG: Failed to get username: ${response.statusCode}');
        return 'Unknown User';
      }
    } catch (e) {
      print('DEBUG: Error getting username: $e');
      return 'Unknown User';
    }
  }

  Future<void> _renounceSeat() async {
    final String url = "$apiBaseUrl/api/renounce_driver/${requestModel!.session_id}";
    try {
      final response = await http.patch(
        Uri.parse(url),
        headers: {
          "Authorization":"Bearer ${await widget.userModel.jwt.getAccessToken()}"
        }
      );
      
      if (response.statusCode == 200 && mounted) {
        _showDebugMessage('${AppLocalizations.of(context).reqRevBanner4}');
        Navigator.pop(context);
      } else if (mounted) {
        _showDebugMessage('${AppLocalizations.of(context).reqRevBanner5}: ${response.statusCode}');
      }
    } catch (e) {
      print('DEBUG: Network error: $e');
      if (mounted) {
        _showDebugMessage('Network error: $e');
      }
    }
  }

  Future<void> _showRenounceConfirmation() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("${AppLocalizations.of(context).reqRevBanner6}"),
        content: Text("${AppLocalizations.of(context).reqRevBanner6}"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text("${AppLocalizations.of(context).cancel}"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text("${AppLocalizations.of(context).resign}"),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      _renounceSeat();
    }
  }

  // Helper method to create marker widget
  Widget _createMarkerWidget(IconData icon, Color color, double size) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: Icon(icon, color: Colors.white, size: size * 0.6),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text("Loading..."),
          backgroundColor: Colors.grey, 
          centerTitle: true,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final startTime = requestModel?.startTime;
    final arrivalTime = (startTime != null && route != null)
        ? startTime.add(Duration(minutes: route!.etaMinutes))
        : null;

    return Scaffold(
      appBar: AppBar(
        title: _isModifying 
            ? Text("Modify Your ${_modifyingStop == 'start' ? '${AppLocalizations.of(context).startPoint}' : '${AppLocalizations.of(context).arrivalPoint}'}")
            : Text("${AppLocalizations.of(context).reqRevBanner8}"),
        backgroundColor: _isModifying ? Colors.orange : Colors.redAccent,
        centerTitle: true,
      ),
      endDrawer: DrawerMenu(userModel: widget.userModel),
      body: Column(
        children: [
          // INFO PANEL
          Expanded(
            flex: 2,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_isModifying) 
                    Card(
                      color: Colors.orange.shade100,
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Row(
                          children: [
                            Icon(Icons.edit, color: Colors.orange),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                "${AppLocalizations.of(context).tapMap} ${_modifyingStop == 'start' ? '${AppLocalizations.of(context).startPoint}' : '${AppLocalizations.of(context).arrivalPoint}'}",
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Driver info card
                  Card(
                    elevation: 2.0,
                    color: Colors.green.shade100,
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Row(
                        children: [
                          Icon(Icons.directions_car, color: Colors.green),
                          SizedBox(width: 8),
                          Text(
                            "${AppLocalizations.of(context).driver}: ${_driverName ?? 'Loading...'}",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  // Passenger info card
                  Card(
                    elevation: 2.0,
                    color: Colors.blue.shade100,
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Row(
                        children: [
                          Icon(Icons.person, color: Colors.blue),
                          SizedBox(width: 8),
                          Text(
                            "${AppLocalizations.of(context).passenger}: ${_passengerName ?? 'Loading...'}",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  // Time info card
                  Card(
                    elevation: 2.0,
                    color: Colors.redAccent.shade200,
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (startTime != null)
                            Text(
                              "${AppLocalizations.of(context).requestedTime}: ${startTime.toLocal().toString()}",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.white
                              ),
                            ),
                          if (arrivalTime != null)
                            Text(
                              "${AppLocalizations.of(context).extTime}: ${arrivalTime.toLocal().toString()}",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.white
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 8),
                  
                  // PASSENGER'S ROUTE SECTION
                  Text(
                    "Passenger's Pickup/Dropoff:",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blue),
                  ),
                  SizedBox(height: 8),
                  if (_startName != null) 
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 2.0),
                      child: Row(
                        children: [
                          Icon(Icons.location_on, color: Colors.blue, size: 16),
                          SizedBox(width: 8),
                          Expanded(child: Text("Pickup: $_startName")),
                        ],
                      ),
                    ),
                  if (_arrivalName != null) 
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 2.0),
                      child: Row(
                        children: [
                          Icon(Icons.flag, color: Colors.purple, size: 16),
                          SizedBox(width: 8),
                          Expanded(child: Text("Dropoff: $_arrivalName")),
                        ],
                      ),
                    ),
                  
                  SizedBox(height: 16),
                  
                  // DRIVER'S ROUTE SECTION
                  Text(
                    "My Route:",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green),
                  ),
                  SizedBox(height: 8),
                  if (_driverStartName != null)
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 2.0),
                      child: Row(
                        children: [
                          Icon(Icons.location_on, color: Colors.green, size: 16),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _isModifying && _modifyingStop == 'start' && _tempDriverStart != null
                                  ? "New start: Setting..."
                                  : "My start: $_driverStartName"
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 2.0),
                      child: Text("My start: Not specified", style: TextStyle(color: Colors.red)),
                    ),
                  
                  if (_driverArrivalName != null)
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 2.0),
                      child: Row(
                        children: [
                          Icon(Icons.flag, color: Colors.orange, size: 16),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _isModifying && _modifyingStop == 'arrival' && _tempDriverArrival != null
                                  ? "New destination: Setting..."
                                  : "My destination: $_driverArrivalName"
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 2.0),
                      child: Text("My destination: Not specified", style: TextStyle(color: Colors.red)),
                    ),
                  
                  SizedBox(height: 16),
                  
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 2.0),
                    child: Text("Passenger requested: 1 seat"),
                  ),

                  // Route info
                  if (route != null)
                    Card(
                      color: Colors.green[50],
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(
                          "${AppLocalizations.of(context).route}: ${route!.distanceKm.toStringAsFixed(1)} km • ${route!.etaMinutes} min",
                          style: TextStyle(fontSize: 14, color: Colors.green[800], fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // MAP
          Expanded(
            flex: 3,
            child: _buildMap(),
          ),

          // ACTION BUTTONS
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Colors.grey[300]!)),
            ),
            child: Column(
              children: [
                if (_isModifying) ...[
                  if ((_modifyingStop == 'start' && _tempDriverStart != null) || 
                      (_modifyingStop == 'arrival' && _tempDriverArrival != null)) ...[
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _confirmModification,
                            icon: Icon(Icons.check),
                            label: Text("Confirm ${_modifyingStop == 'start' ? 'Start' : 'Arrival'} Change"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              minimumSize: Size(double.infinity, 50),
                            ),
                          ),
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _cancelModification,
                            icon: Icon(Icons.cancel),
                            label: Text("${AppLocalizations.of(context).cancel}"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.grey,
                              foregroundColor: Colors.white,
                              minimumSize: Size(double.infinity, 50),
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Text(
                      "Route will be recalculated to include passenger's pickup and dropoff points",
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ] else ...[
                    Text(
                      "${AppLocalizations.of(context).tapMap} ${_modifyingStop == 'start' ? '${AppLocalizations.of(context).startPoint}' : '${AppLocalizations.of(context).arrivalPoint}'}",
                      style: TextStyle(
                        color: Colors.orange[800],
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: _cancelModification,
                      child: Text("${AppLocalizations.of(context).cancel}"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey,
                        foregroundColor: Colors.white,
                        minimumSize: Size(double.infinity, 50),
                      ),
                    ),
                  ]
                ] else ...[
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _startModification('start'),
                          icon: Icon(Icons.location_on),
                          label: Text("${AppLocalizations.of(context).modify} ${AppLocalizations.of(context).startPoint}"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            minimumSize: Size(double.infinity, 50),
                          ),
                        ),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _startModification('arrival'),
                          icon: Icon(Icons.flag),
                          label: Text("${AppLocalizations.of(context).modify} ${AppLocalizations.of(context).arrivalPoint}"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            foregroundColor: Colors.white,
                            minimumSize: Size(double.infinity, 50),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: _showRenounceConfirmation,
                    icon: Icon(Icons.exit_to_app),
                    label: Text("${AppLocalizations.of(context).resign} ${AppLocalizations.of(context).from} ${AppLocalizations.of(context).request}"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      minimumSize: Size(double.infinity, 50),
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    "You can modify your start or arrival point, or resign from this request",
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    child: Text("${AppLocalizations.of(context).backToReq}"),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMap() {
    final markers = <Marker>[
      // Passenger start marker (BLUE) - ALWAYS EXISTS
      Marker(
        point: requestModel!.start,
        width: 40,
        height: 40,
        child: _createMarkerWidget(Icons.location_on, Colors.blue, 40),
      ),
      // Passenger destination marker (PURPLE) - ALWAYS EXISTS
      Marker(
        point: requestModel!.arrival,
        width: 40,
        height: 40,
        child: _createMarkerWidget(Icons.flag, Colors.purple, 40),
      ),
    ];

    // Add driver markers - use temporary markers if in modification mode
    if (_isModifying) {
      // Show temporary marker for the point being modified
      if (_modifyingStop == 'start' && _tempDriverStart != null) {
        markers.add(
          Marker(
            point: _tempDriverStart!,
            width: 50,
            height: 50,
            child: _createMarkerWidget(Icons.location_on, Colors.green, 50),
          ),
        );
      } else if (_modifyingStop == 'arrival' && _tempDriverArrival != null) {
        markers.add(
          Marker(
            point: _tempDriverArrival!,
            width: 50,
            height: 50,
            child: _createMarkerWidget(Icons.flag, Colors.orange, 50),
          ),
        );
      }
    } else {
      // Regular driver markers
      if (requestModel!.driver_start != null) {
        markers.add(
          Marker(
            point: requestModel!.driver_start!,
            width: 40,
            height: 40,
            child: _createMarkerWidget(Icons.location_on, Colors.green, 40),
          ),
        );
      }
      if (requestModel!.driver_arrival != null) {
        markers.add(
          Marker(
            point: requestModel!.driver_arrival!,
            width: 40,
            height: 40,
            child: _createMarkerWidget(Icons.flag, Colors.orange, 40),
          ),
        );
      }
    }

    // Create overlays list
    final overlays = <Widget>[
      // Always show passenger start/arrival
      StartArrivalOverlay(
        startPoint: requestModel!.start,
        arrivalPoint: requestModel!.arrival,
        onArrivalRemoved: () {},
        onStartRemoved: () {},
      ),
      MarkerLayer(markers: markers),
    ];
    
    if (!_isModifying && requestModel!.driver_start != null && requestModel!.driver_arrival != null) {
      overlays.add(
        StartArrivalOverlay(
          startPoint: requestModel!.driver_start!,
          arrivalPoint: requestModel!.driver_arrival!,
          onArrivalRemoved: () {},
          onStartRemoved: () {},
        ),
      );
    }

    // Add route overlay if available
    if (requestModel!.route != null && requestModel!.route!.isNotEmpty) {
      overlays.add(
        OfferRouteOverlay(routes: RouteOption(
          points: requestModel!.route!,
          etaMinutes: route?.etaMinutes ?? 0,
          distanceKm: route?.distanceKm ?? 0.0,
        )),
      );
    }

    return BaseMapWidget(
      onTap: _isModifying ? _handleMapTap : null,
      overlays: overlays,
    );
  }
}