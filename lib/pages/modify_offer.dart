// pages/modify_offer.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:multi_user_flutter_app/l10n/app_localizations.dart';
import 'package:multi_user_flutter_app/models/user_model.dart';
import 'package:multi_user_flutter_app/pages/active_offers.dart';
import 'package:multi_user_flutter_app/pages/create_offer.dart'  hide buildRouteOptionFromOsrm, RouteOption;
import 'package:multi_user_flutter_app/routes.dart';
import 'package:multi_user_flutter_app/utils/sse_utils.dart';
import 'package:multi_user_flutter_app/widgets/base_map_widget.dart';
import 'package:multi_user_flutter_app/widgets/drawer_menu.dart';
import 'package:multi_user_flutter_app/widgets/map_widget.dart';
import 'package:multi_user_flutter_app/widgets/offer_route_overlay.dart';
import 'package:multi_user_flutter_app/widgets/start_arrival_overlay.dart';
import 'package:multi_user_flutter_app/widgets/stops_overlay.dart';
import 'package:url_launcher/url_launcher.dart';

class ModifyOffer extends StatefulWidget {
  final UserModel userModel;
  const ModifyOffer({super.key, required this.userModel});

  @override
  State<ModifyOffer> createState() => _ModifyOfferState(userModel: userModel);
}

class _ModifyOfferState extends State<ModifyOffer> {
  OfferModel? offerModel;
  final UserModel userModel;
  RouteOption? route;
  LatLng? startPoint;
  LatLng? arrivalPoint;
  String? _startName;
  String? _arrivalName;
  String? _token;

  /// new_time is stored as UTC (so we can send it to backend easily).
  DateTime? new_time;
  int? seats_available;

  // SSE service for real-time updates
  late OfferService _offerService;
  StreamSubscription<BroadcastResource>? _offerSubscription;

  _ModifyOfferState({required this.userModel});

  @override
  void initState() {
    super.initState();
    _loadToken();
    _initializeSSE();
  }

  void _initializeSSE() {
    _offerService = OfferService();
    _offerSubscription = _offerService.connect().listen(
      (BroadcastResource resource) {
        _handleSSEEvent(resource);
      },
      onError: (error) {
        print('SSE error: $error');
      },
    );
  }

  void _handleSSEEvent(BroadcastResource resource) {
    if (resource.type == 'modified' && offerModel != null) {
      // Check if the modified offer is the current one
      if (resource.id == offerModel!.session_id) {
        _refreshOfferData();
      }
    } else if (resource.type == 'deleted' && offerModel != null) {
      // Check if the deleted offer is the current one
      if (resource.id == offerModel!.session_id) {
        _handleOfferDeleted();
      }
    }
  }

  Future<void> _refreshOfferData() async {
    if (offerModel == null) return;

    try {
      final getUrl = "$apiBaseUrl/api/get_offer/${offerModel!.session_id}";
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
            // Update the offer model with fresh data
            offerModel = OfferModel.fromJson(data);
            
            // Rebuild route with updated data
            _buildRoute();
            _loadPlaceNames();
          });
          
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Offer updated with latest changes"),
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else {
        print("⚠️ Could not refetch offer: ${getRes.statusCode}");
      }
    } catch (e) {
      print("Error refreshing offer data: $e");
    }
  }

  void _handleOfferDeleted() {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("This offer has been deleted"),
          duration: Duration(seconds: 3),
        ),
      );
      
      // Navigate back after a short delay
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/active_offers');
        }
      });
    }
  }

  @override
  void dispose() {
    _offerSubscription?.cancel();
    _offerService.disconnect();
    super.dispose();
  }

  Future<void> _loadToken() async {
    final token = await userModel.jwt.getAccessToken();
    setState(() {
      _token = token;
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (offerModel == null) {
      final args = ModalRoute.of(context)!.settings.arguments;
      if (args is OfferModel) {
        offerModel = args;
        _buildRoute();
        _loadPlaceNames();
      }
    }
  }

  Future<void> _buildRoute() async {
    if (offerModel != null) {
      final r = await buildRouteOptionFromOsrm(offerModel!.route);
      setState(() {
        route = r;
        startPoint = offerModel!.route.first;
        arrivalPoint = offerModel!.route.last;
      });
    }
  }

  Future<void> _loadPlaceNames() async {
    if (offerModel == null) return;
    final startName = await getPlaceName(
      offerModel!.start.latitude,
      offerModel!.start.longitude,
    );
    final arrivalName = await getPlaceName(
      offerModel!.destination.latitude,
      offerModel!.destination.longitude,
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
          return LatLng(coords[1], coords[0]); // lat, lon
        }).toList();
      }
    }
    return [];
  }

  /// Launch Google Maps with the route and stops
  Future<void> _launchGoogleMaps() async {
    if (offerModel == null || route == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please build/select a route first.")),
      );
      return;
    }

    try {
      // Get all waypoints: start + stops + destination
      final List<LatLng> waypoints = [];
      waypoints.add(startPoint ?? offerModel!.start);

      // Add intermediate stops
      if (offerModel!.stops.isNotEmpty) {
        for (var stop in offerModel!.stops) {
          waypoints.add(stop.stop);
        }
      }

      waypoints.add(arrivalPoint ?? offerModel!.destination);

      // Build Google Maps URL
      final String origin = "${waypoints.first.latitude},${waypoints.first.longitude}";
      final String destination = "${waypoints.last.latitude},${waypoints.last.longitude}";

      // Build waypoints parameter (all points except first and last)
      final String waypointsParam = waypoints
          .sublist(1, waypoints.length - 1)
          .map((point) => "${point.latitude},${point.longitude}")
          .join("|");

      String googleMapsUrl;
      if (waypointsParam.isNotEmpty) {
        googleMapsUrl = "https://www.google.com/maps/dir/?api=1"
            "&origin=$origin"
            "&destination=$destination"
            "&waypoints=$waypointsParam"
            "&travelmode=driving";
      } else {
        googleMapsUrl = "https://www.google.com/maps/dir/?api=1"
            "&origin=$origin"
            "&destination=$destination"
            "&travelmode=driving";
      }

      if (await canLaunchUrl(Uri.parse(googleMapsUrl))) {
        await launchUrl(
          Uri.parse(googleMapsUrl),
          mode: LaunchMode.externalApplication,
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Could not launch Google Maps")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error launching Google Maps: $e")),
      );
    }
  }

  /// Delete offer
  Future<void> _deleteOffer() async {
    if (offerModel == null) return;

    // Show confirmation dialog
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title:  Text("${AppLocalizations.of(context).deleteOffer}"),
        content: const Text("Are you sure you want to delete this offer? This action cannot be undone."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text("${AppLocalizations.of(context).cancel}"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("Delete", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (shouldDelete != true) return;

    try {
      final deleteUrl = "$apiBaseUrl/api/delete_offer/${offerModel!.session_id}";
      final response = await http.delete(
        Uri.parse(deleteUrl),
        headers: {
          'Content-Type': 'application/json',
          "Authorization": "Bearer ${await userModel.jwt.getAccessToken()}"
        },
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("✅ Offer Deleted Successfully")),
        );

        // Navigate back to active offers page
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/active_offers');
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Error deleting the offer: ${response.statusCode} ${response.body}",
            ),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error deleting your Offer, due to:\n${e.toString()}"),
        ),
      );
    }
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

      if ((startPoint != null || offerModel != null) &&
          (arrivalPoint != null || offerModel != null)) {
        _fetchRoute();
      }
    });
  }

  Future<void> _fetchRoute() async {
    // Construct coordinate list for OSRM: prefer tapped start/arrival if present,
    // otherwise fall back to what's in offerModel.
    if (offerModel == null) return;

    final List<LatLng> coords = [];
    coords.add(startPoint ?? offerModel!.start);
    // add intermediate stops (offerModel.stops is expected to be a List<LatLng>)
    if (offerModel!.stops.isNotEmpty) {
      for (var s in offerModel!.stops) {
        coords.add(s.stop);
      }
    }
    coords.add(arrivalPoint ?? offerModel!.destination);

    final coordsFinal =
        coords.map((p) => "${p.longitude},${p.latitude}").join(";");

    final url = "https://router.project-osrm.org/route/v1/driving/"
        "$coordsFinal"
        "?overview=full&geometries=geojson";

    final res = await http.get(Uri.parse(url));
    if (res.statusCode != 200) {
      // debug
      print("OSRM error: ${res.statusCode} ${res.body}");
      return;
    }

    final data = json.decode(res.body);
    final routesList = data["routes"] as List?;
    if (routesList == null || routesList.isEmpty) {
      print("No routes returned from OSRM");
      return;
    }

    // take the first route (no variable shadowing)
    final firstRoute = routesList.first as Map<String, dynamic>;

    final coordsArr = firstRoute["geometry"]["coordinates"] as List;
    final points = coordsArr
        .map<LatLng>((c) => LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()))
        .toList();

    final durationSec = (firstRoute["duration"] as num?) ?? 0;
    final minutes = (durationSec / 60).round();

    final distanceMeters = (firstRoute["distance"] as num?) ?? 0;
    final distanceKm = (distanceMeters / 1000.0);

    if (distanceKm.isNaN || distanceKm.isInfinite) {
      print("⚠️ Skipping invalid route (NaN/Infinity distance)");
      return;
    }

    setState(() {
      route = RouteOption(
        points: points,
        etaMinutes: minutes,
        distanceKm: distanceKm,
      );
    });
  }

  /// Pick new start time (pre-fills with current offer start time)
  Future<void> _pickNewStartTime() async {
    final baseLocal =
        (new_time ?? offerModel?.start_time ?? DateTime.now()).toLocal();
    final initial = TimeOfDay.fromDateTime(baseLocal);

    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
    );

    if (picked == null) return;

    // keep the same date as existing start_time (or today if unavailable)
    final baseDate =
        (offerModel?.start_time ?? DateTime.now()).toLocal(); // local date
    final selectedLocal = DateTime(
        baseDate.year, baseDate.month, baseDate.day, picked.hour, picked.minute);

    setState(() {
      // store as UTC for transmission to backend
      new_time = selectedLocal.toUtc();
    });
  }

  Future<void> _modifyOfferTime() async {
    if (offerModel == null) return;
    if (new_time == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please pick a new start time first.")),
      );
      return;
    }

    try {
      final patchUrl = "$apiBaseUrl/api/modify_offer_time";
      final body = jsonEncode({
        'session_id': offerModel!.session_id,
        'driver_id': userModel.currentUser!.id,
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
          const SnackBar(content: Text("⭐ Offer Time Modified Successfully")),
        );

        // re-fetch updated offer
        final getUrl = "$apiBaseUrl/api/get_offer/${offerModel!.session_id}";
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
            offerModel = OfferModel.fromJson(data);
          });
        } else {
          print("⚠️ Could not refetch offer: ${getRes.statusCode}");
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Error modifying the offer: ${response.statusCode} ${response.body}",
            ),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error modifying your Offer, due to:\n${e.toString()}"),
        ),
      );
    }
  }


  Future<void> _modifyOfferRoute() async {
    if (offerModel == null) return;
    if (route == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please build/select a route first.")),
      );
      return;
    }

    try {
      final routeList = route!.points.map((p) => _latLngToJson(p)).toList();
      final body = {
        'session_id': offerModel!.session_id,
        'driver_id': userModel.currentUser!.id,
        // depending on API shape, keep nested map or send flat list.
        'route': {
          'route': routeList,
        },
      };
      final url =
          "$apiBaseUrl/api/modify_offer_route";
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
          const SnackBar(content: Text("⭐ Offer Route Modified Successfully")),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  "Error modifying the route: ${response.statusCode} ${response.body}")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text("Error in modifying your Offer route, due to:\n${e.toString()}")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final startTime = offerModel?.start_time;
    final arrivalTime = (startTime != null && route != null)
        ? startTime.add(Duration(minutes: route!.etaMinutes))
        : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Review Offer"),
        backgroundColor: Colors.redAccent,
        centerTitle: true,
        actions: [
          // Delete button in app bar
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.white),
            onPressed: _deleteOffer,
            tooltip: '${AppLocalizations.of(context).deleteOffer}',
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
                if (arrivalTime != null)
                  Text(
                    "Suggested arrival: ${arrivalTime.toLocal().toString()}",
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                if (_startName != null) Text("From: $_startName"),
                if (_arrivalName != null) Text("To: $_arrivalName"),
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
                      child: const Text("Pick time"),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: (new_time != null) ? _modifyOfferTime : null,
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
                if (route != null) OfferRouteOverlay(routes: route!),
                if (route != null)
                  StartArrivalOverlay(
                    startPoint: startPoint,
                    arrivalPoint: arrivalPoint,
                    onArrivalRemoved: () {
                      setState(() {
                        arrivalPoint = null;
                      });
                      _fetchRoute();
                    },
                    onStartRemoved: () {
                      setState(() {
                        startPoint = null;
                      });
                      _fetchRoute();
                    },
                  ),
                if (offerModel != null && _token!=null) StopsOverlay(stops: offerModel!.stops, token: _token!),
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
                    // Google Maps Button
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _launchGoogleMaps,
                        icon: const Icon(Icons.directions, color: Colors.white),
                        label: const Text(
                          "Open in Google Maps",
                          style: TextStyle(color: Colors.white),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Modify Route Button
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _modifyOfferRoute,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: Text(
                          "${AppLocalizations.of(context).modifyRoute}",
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
                    onPressed: _deleteOffer,
                    icon: const Icon(Icons.delete, color: Colors.white),
                    label: Text(
                      "${AppLocalizations.of(context).deleteOffer}",
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

bool _isPointNearPolyline(
    LatLng tap, List<LatLng> polyline, double toleranceMeters) {
  final distance = const Distance();
  for (int i = 0; i < polyline.length - 1; i++) {
    final d = _distanceToSegment(tap, polyline[i], polyline[i + 1], distance);
    if (d <= toleranceMeters) return true;
  }
  return false;
}

double _distanceToSegment(LatLng p, LatLng v, LatLng w, Distance distance) {
  // Note: this is a reasonable heuristic but mixes lat/lon and meters;
  // for production, project to meters first (e.g., using a proper projection).
  final l2 = distance(v, w) * distance(v, w);
  if (l2 == 0) return distance(p, v);

  final t = ((p.latitude - v.latitude) * (w.latitude - v.latitude) +
          (p.longitude - v.longitude) * (w.longitude - v.longitude)) /
      l2;

  if (t < 0) return distance(p, v);
  if (t > 1) return distance(p, w);

  final projection = LatLng(
    v.latitude + t * (w.latitude - v.latitude),
    v.longitude + t * (w.longitude - v.longitude),
  );

  return distance(p, projection);
}

Map<String, dynamic> _latLngToJson(LatLng point) {
  return {
    'lat': point.latitude,
    'lng': point.longitude,
  };
}