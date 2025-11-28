import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:multi_user_flutter_app/l10n/app_localizations.dart';
import 'package:multi_user_flutter_app/models/request_model.dart';
import 'package:multi_user_flutter_app/models/user_model.dart';
import 'package:multi_user_flutter_app/pages/active_offers.dart';
import 'package:multi_user_flutter_app/pages/create_offer.dart';
import 'package:multi_user_flutter_app/pages/modify_offer.dart';
import 'package:multi_user_flutter_app/routes.dart';
import 'package:multi_user_flutter_app/utils/sse_utils.dart';
import 'package:multi_user_flutter_app/widgets/base_map_widget.dart';
import 'package:multi_user_flutter_app/widgets/drawer_menu.dart';
import 'package:multi_user_flutter_app/widgets/map_widget.dart';
import 'package:multi_user_flutter_app/widgets/offer_route_overlay.dart';
import 'package:multi_user_flutter_app/widgets/route_overlay.dart';
import 'package:multi_user_flutter_app/widgets/start_arrival_overlay.dart';
import 'package:multi_user_flutter_app/widgets/stops_overlay.dart';

class ModifyRequest extends StatefulWidget {
  final UserModel userModel;
  const ModifyRequest({super.key, required this.userModel});

  @override
  State<ModifyRequest> createState() => _ModifyRequestState(userModel: userModel);
}

class _ModifyRequestState extends State<ModifyRequest> {
  RequestModel? requestModel;

  final UserModel userModel;
  LatLng? startPoint;
  LatLng? arrivalPoint;
  String? _startName;
  String? _arrivalName;  
  String? _startDriver;
  String? _arrivalDriver;
  RouteOption? routeOption;

  /// new_time is stored as UTC (so we can send it to backend easily).
  DateTime? new_time;
  int? seats_available;

  // SSE service for real-time updates
  late RequestService _requestService;
  StreamSubscription<BroadcastResource>? _requestSubscription;

  _ModifyRequestState({required this.userModel});

  @override
  void initState() {
    super.initState();
    _initializeSSE();
    _loadRoute();
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
            
            // Update points and reload data
            startPoint = requestModel!.start;
            arrivalPoint = requestModel!.arrival;
            
            // Reload route and place names
            _loadRoute();
            _loadPlaceNames();
            _loadDriverPlaceNames();
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
          content: Text("This request has been deleted"),
          duration: Duration(seconds: 3),
        ),
      );
      
      // Navigate back after a short delay
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/active_requests');
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
      final args = ModalRoute.of(context)!.settings.arguments;
      if (args is RequestModel) {
        requestModel = args;
        startPoint = requestModel!.start;
        arrivalPoint = requestModel!.arrival;
        _loadRoute();
        _loadPlaceNames();
        _loadDriverPlaceNames();
      }
    }
  }

  
  void _loadRoute() {
    if (requestModel?.route != null && requestModel!.route!.isNotEmpty) {
      _getRequestRouteOption();
    }
  }

  /// Delete request
  Future<void> _deleteRequest() async {
    if (requestModel == null) return;

    // Show confirmation dialog
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("${AppLocalizations.of(context).deleteRequest}"),
        content: const Text("Are you sure you want to delete this request? This action cannot be undone."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text("${AppLocalizations.of(context).cancel}"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text("Delete", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (shouldDelete != true) return;

    try {
      final deleteUrl = "$apiBaseUrl/api/delete_request/${requestModel!.session_id}";
      final response = await http.delete(
        Uri.parse(deleteUrl),
        headers: {
          'Content-Type': 'application/json',
          "Authorization": "Bearer ${await userModel.jwt.getAccessToken()}"
        },
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("✅ Request Deleted Successfully")),
        );

        // Navigate back to active requests page
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/active_requests');
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Error deleting the request: ${response.statusCode} ${response.body}",
            ),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error deleting your Request, due to:\n${e.toString()}"),
        ),
      );
    }
  }

  Future<void> _loadPlaceNames() async {
    if (requestModel == null) return;
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

  Future<void> _loadDriverPlaceNames() async {
    if (requestModel == null ||
        requestModel!.driver_start == null ||
        requestModel!.driver_arrival == null) return;
    
    final startName = await getPlaceName(
      requestModel!.driver_start!.latitude,
      requestModel!.driver_start!.longitude,
    );
    final arrivalName = await getPlaceName(
      requestModel!.driver_arrival!.latitude,
      requestModel!.driver_arrival!.longitude,
    );
    setState(() {
      _startDriver = startName;
      _arrivalDriver = arrivalName;
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
          return LatLng(coords[1], coords[0]); // lat, lon
        }).toList();
      }
    }
    return [];
  }

  void _handleTap(TapPosition tap, LatLng point) {
    setState(() {
      if (startPoint == null) {
        startPoint = point;
      } else if (arrivalPoint == null) {
        arrivalPoint = point;
      } else {
        // both set, do nothing — user must remove one by tapping its marker (callbacks provided)
      }
    });
  }

  /// Pick new start time (pre-fills with current offer start time)
  Future<void> _pickNewStartTime() async {
    final baseLocal =
        (new_time ?? requestModel?.startTime ?? DateTime.now()).toLocal();
    final initial = TimeOfDay.fromDateTime(baseLocal);

    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
    );

    if (picked == null) return;

    // keep the same date as existing start_time (or today if unavailable)
    final baseDate =
        (requestModel?.startTime ?? DateTime.now()).toLocal(); // local date
    final selectedLocal = DateTime(
        baseDate.year, baseDate.month, baseDate.day, picked.hour, picked.minute);

    setState(() {
      // store as UTC for transmission to backend
      new_time = selectedLocal.toUtc();
    });
  }

  Future<void> _ModifyRequestTime() async {
    if (requestModel == null) return;
    if (new_time == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please pick a new start time first.")),
      );
      return;
    }

    try {
      final patchUrl = "$apiBaseUrl/api/modify_request_time";
      final body = jsonEncode({
        'session_id': requestModel!.session_id,
        'passenger_id': userModel.currentUser!.id,
        'start_time': new_time!.toIso8601String(), // ISO UTC string
      });

      final response = await http.patch(
        Uri.parse(patchUrl),
        headers: {
          'Content-Type': 'application/json',
          "Authorization":"Bearer ${await userModel.jwt.getAccessToken()}"
        },
        body: body,
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("⭐ Request Time Modified Successfully")),
        );

        // re-fetch updated offer
        final getUrl = "$apiBaseUrl/api/get_request/${requestModel!.session_id}";
        final getRes = await http.get(
          Uri.parse(getUrl),
          headers: {
            'Content-Type': 'application/json',
            "Authorization":"Bearer ${await userModel.jwt.getAccessToken()}"
          },
        );

        if (getRes.statusCode == 200 || getRes.statusCode == 201) {
          final Map<String, dynamic> data = jsonDecode(getRes.body);

          if (!mounted) return;
          setState(() {
            requestModel = RequestModel.fromJson(data);
          });
        } else {
          print("⚠️ Could not refetch request: ${getRes.statusCode}");
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Error modifying the request: ${response.statusCode} ${response.body}",
            ),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error modifying your Request, due to:\n${e.toString()}"),
        ),
      );
    }
  }

  Future<void> _ModifyRequestStartPoint() async {
    if (requestModel == null) return;
    if (startPoint == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select a start first.")),
      );
      return;
    }

    try {
      final start = {'lat': startPoint!.latitude, 'lng': startPoint!.longitude};
      final body = {
        'session_id': requestModel!.session_id,
        'passenger_id': userModel.currentUser!.id,
        // depending on API shape, keep nested map or send flat list.
        'stop': start
      };
      final url =
          "$apiBaseUrl/api/modify_request_start";
      final response = await http.patch(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          "Authorization":"Bearer ${await userModel.jwt.getAccessToken()}"
        },
        body: jsonEncode(body),
      );
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("⭐ Request Start Modified Successfully")),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Error modifying the start: ${response.statusCode} ${response.body}"
              )
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
            Text("Error in modifying your Request Start, due to:\n${e.toString()}"
            )
          ),
      );
    }
  }

  Future<void> _ModifyRequestArrivalPoint() async {
    if (requestModel == null) return;
    if (arrivalPoint == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select a destination first.")),
      );
      return;
    }

    try {
      final arrival = {'lat': arrivalPoint!.latitude, 'lng': arrivalPoint!.longitude};
      final body = {
        'session_id': requestModel!.session_id,
        'passenger_id': userModel.currentUser!.id,
        // depending on API shape, keep nested map or send flat list.
        'stop': arrival
      };
      final url =
          "$apiBaseUrl/api/modify_request_arrival";
      final response = await http.patch(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          "Authorization":"Bearer ${await userModel.jwt.getAccessToken()}"
        },
        body: jsonEncode(body),
      );
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("⭐ Request Destination Modified Successfully")),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Error modifying the destination: ${response.statusCode} ${response.body}"
              )
            ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
            Text("Error in modifying your Request Destination, due to:\n${e.toString()}"
          )
        ),
      );
    }
  }

  // Create a RouteOption from the request model data
  void _getRequestRouteOption() async  {
    if (requestModel?.route == null || requestModel!.route!.isEmpty) {
      return;
    }
    if (!mounted) return;
    final routeOp=await buildRouteOptionFromOsrm(requestModel!.route!);
    setState(() {
      routeOption = routeOp;
    });
  }

  @override
  Widget build(BuildContext context) {
    final startTime = requestModel?.startTime;
    return Scaffold(
      appBar: AppBar(
        title: Text("Review Request"),
        backgroundColor: Colors.redAccent,
        centerTitle: true,
        actions: [
          // Delete button in app bar
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.white),
            onPressed: _deleteRequest,
            tooltip: '${AppLocalizations.of(context).deleteRequest}',
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
                if (startTime != null)
                  Card(
                    elevation: 2.0,
                    color: Colors.redAccent.shade200,
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        "Start time: ${startTime.toLocal().toString()}",
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                if (_startName != null) Text("${AppLocalizations.of(context).from}: $_startName"),
                if (_arrivalName != null) Text("${AppLocalizations.of(context).to}: $_arrivalName"),
                
                // Show driver route info if available
                if (requestModel?.driver_start != null && requestModel?.driver_arrival != null)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),
                      const Text(
                        "Driver Route:",
                        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
                      ),
                      if (_startDriver != null) Text("Driver Start: $_startDriver"),
                      if (_arrivalDriver != null) Text("Driver Arrival: $_arrivalDriver"),
                    ],
                  ),
                
                const SizedBox(height: 12),

                // --- Time picker UI ---
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        "Selected start time: ${((new_time ?? startTime)?.toLocal().toString() ?? 'Not set')}",
                      ),
                    ),
                    ElevatedButton(
                      onPressed: _pickNewStartTime,
                      child: Text("${AppLocalizations.of(context).pickTime}"),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: (new_time != null) ? _ModifyRequestTime : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            (new_time != null) ? Colors.green : Colors.grey,
                      ),
                      child: const Text("Save time"),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ======= MAP =======
          Expanded(
            child: BaseMapWidget(
              onTap: _handleTap,
              overlays: [
                // Show request route if available
                if (routeOption != null)
                  RouteOverlay(
                    routes: [routeOption!],
                    selectedRouteIndex: 0,
                  ),
                
                // Show driver start and arrival markers if available
                if (requestModel?.driver_start != null || requestModel?.driver_arrival != null)
                  MarkerLayer(
                    markers: [
                      if (requestModel?.driver_start != null)
                        Marker(
                          point: requestModel!.driver_start!,
                          width: 40,
                          height: 40,
                          child: const Icon(
                            Icons.directions_car,
                            color: Colors.blue,
                            size: 30,
                          ),
                        ),
                      if (requestModel?.driver_arrival != null)
                        Marker(
                          point: requestModel!.driver_arrival!,
                          width: 40,
                          height: 40,
                          child: const Icon(
                            Icons.flag,
                            color: Colors.blue,
                            size: 30,
                          ),
                        ),
                    ],
                  ),
                
                // User's start and arrival points (editable)
                if (startPoint != null || arrivalPoint != null)
                  StartArrivalOverlay(
                    startPoint: startPoint,
                    arrivalPoint: arrivalPoint,
                    onArrivalRemoved: () {
                      setState(() {
                        arrivalPoint = null;
                      });
                    },
                    onStartRemoved: () {
                      setState(() {
                        startPoint = null;
                      });
                    },
                  ),
              ],
            ),
          ),
          
          // ======= ACTION BUTTONS =======
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              children: [
                Row(
                  children: [
                    // Modify Start Button
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _ModifyRequestStartPoint,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text(
                          "Modify Start",
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Modify Arrival Button
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _ModifyRequestArrivalPoint,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text(
                          "Modify Arrival",
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Delete Button - Full width
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _deleteRequest,
                    icon: const Icon(Icons.delete, color: Colors.white),
                    label: Text(
                      "${AppLocalizations.of(context).deleteRequest}",
                      style: TextStyle(color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// SSE Service Classes
class SSEService<T> {
  final String url;
  StreamController<T>? _controller;
  http.Client? _client;
  bool _isConnected = false;

  SSEService(this.url);

  Stream<T> connect(T Function(Map<String, dynamic>) fromJson) {
    _controller = StreamController<T>();
    _client = http.Client();
    _isConnected = true;

    _listen(fromJson);
    return _controller!.stream;
  }

  void _listen(T Function(Map<String, dynamic>) fromJson) async {
    try {
      final request = http.Request('GET', Uri.parse(url));
      request.headers['Accept'] = 'text/event-stream';
      request.headers['Cache-Control'] = 'no-cache';

      final response = await _client!.send(request);
      final stream = response.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter());

      await for (final line in stream) {
        if (!_isConnected) break;
        
        if (line.startsWith('data: ')) {
          final jsonStr = line.substring(6);
          if (jsonStr.trim().isNotEmpty && !jsonStr.contains('"status"')) {
            try {
              final jsonMap = jsonDecode(jsonStr) as Map<String, dynamic>;
              final item = fromJson(jsonMap);
              _controller!.add(item);
            } catch (e) {
              print('Error parsing SSE data: $e, data: $jsonStr');
            }
          }
        }
      }
    } catch (e) {
      if (_isConnected) {
        print('SSE connection error: $e');
        _controller!.addError(e);
      }
    } finally {
      if (_isConnected) {
        disconnect();
      }
    }
  }

  void disconnect() {
    _isConnected = false;
    _client?.close();
    _controller?.close();
    _client = null;
    _controller = null;
  }
}