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
import 'package:multi_user_flutter_app/pages/create_offer.dart'
    hide buildRouteOptionFromOsrm, RouteOption;
import 'package:multi_user_flutter_app/routes.dart';
import 'package:multi_user_flutter_app/utils/sse_utils.dart'; // Import SSE utils
import 'package:multi_user_flutter_app/widgets/base_map_widget.dart';
import 'package:multi_user_flutter_app/widgets/drawer_menu.dart';
import 'package:multi_user_flutter_app/widgets/map_widget.dart';
import 'package:multi_user_flutter_app/widgets/offer_route_overlay.dart';
import 'package:multi_user_flutter_app/widgets/start_arrival_overlay.dart';

class OfferDetail extends StatefulWidget {
  final UserModel userModel;
  const OfferDetail({super.key, required this.userModel});

  @override
  State<OfferDetail> createState() => _OfferDetailState(userModel: userModel);
}

class _OfferDetailState extends State<OfferDetail> {
  LatLng? pickup;
  LatLng? dismount;
  OfferModel? offerModel;

  final UserModel userModel;
  RouteOption? route;

  String? _startName;
  String? _arrivalName;

  Timer? _reservationTimer;
  bool _offerTaken = false;

  // SSE service for real-time updates
  late OfferService _offerService;
  StreamSubscription<BroadcastResource>? _offerSubscription;

  _OfferDetailState({required this.userModel});

  @override
  void initState() {
    super.initState();

    // Start countdown immediately when page opens
    _reservationTimer = Timer(const Duration(minutes: 2), () async {
      if (!_offerTaken && mounted) {
        await increaseSeats(offerModel);
        if (mounted) {
          Navigator.pop(context);
          Navigator.pushNamed(context, '\home_page');
        }
      }
    });

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
            
            // Rebuild route and reload names
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
      // Cancel the reservation timer since offer is deleted
      _reservationTimer?.cancel();
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("This offer has been deleted by the driver"),
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
    _reservationTimer?.cancel();
    _offerSubscription?.cancel();
    _offerService.disconnect();

    // If user leaves the page without taking offer, increase seat
    if (!_offerTaken) {
      increaseSeats(offerModel);
    }

    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (offerModel == null) {
      offerModel = ModalRoute.of(context)!.settings.arguments as OfferModel;
      _buildRoute();
      _loadPlaceNames();
    }
  }

  Future<void> _buildRoute() async {
    if (offerModel != null) {
      final r = await buildRouteOptionFromOsrm(offerModel!.route);
      setState(() {
        route = r;
      });
    }
  }

  Future<void> _loadPlaceNames() async {
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

      final response =
          await http.get(url).timeout(const Duration(seconds: 10));

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
    final url =
        Uri.parse("https://photon.komoot.io/api/?q=$query&lang=it&limit=5");

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
    if (offerModel == null) return;
    if (_isPointNearPolyline(point, offerModel!.route, 5.0)) {
      setState(() {
        if (pickup == null) {
          pickup = point;
        } else if (dismount == null) {
          dismount = point;
        }
      });
    }
  }

  Future<void> _takeOffer() async {
    final String url = "$apiBaseUrl/api/take_offer";
    final body = {
      'session_id': offerModel!.session_id,
      'passenger_id': userModel.currentUser!.id,
      'pickup_spot': _latLngToJson(pickup!),
      'dismount_spot': _latLngToJson(dismount!),
      'n_seat_req': 1
    };

    if (pickup != null && dismount != null) {
      try {
        final response = await http.patch(Uri.parse(url),
            body: jsonEncode(body),
            headers: {
              'Content-Type': 'application/json',
              "Authorization":"Bearer ${await userModel.jwt.getAccessToken()}"
            });
        if (response.statusCode == 200) {
          setState(() {
            _offerTaken = true;
          });
          _reservationTimer?.cancel();

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${AppLocalizations.of(context).offTakenSucc}')),
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
    final startTime = offerModel?.start_time;
    final arrivalTime = (startTime != null && route != null)
        ? startTime.add(Duration(minutes: route!.etaMinutes))
        : null;

    return Scaffold(
      appBar: AppBar(
        title: Text("${AppLocalizations.of(context).reviewOff}"),
        backgroundColor: Colors.redAccent,
        centerTitle: true,
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
                    child: Text(
                      "${AppLocalizations.of(context).startTime}: ${startTime.toLocal().toString()}",
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                if (arrivalTime != null)
                  Text(
                    "${AppLocalizations.of(context).extTime}: ${arrivalTime.toLocal().toString()}",
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                if (_startName != null) Text("${AppLocalizations.of(context).from}: $_startName"),
                if (_arrivalName != null) Text("${AppLocalizations.of(context).to}: $_arrivalName"),
              ],
            ),
          ),

          // ======= SEARCH BARS =======
          if (pickup == null)
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: TypeAheadField<LatLng>(
                suggestionsCallback: searchPlaces,
                builder: (context, controller, focusNode) {
                  return TextField(
                    controller: controller,
                    focusNode: focusNode,
                    decoration: InputDecoration(
                      labelText: "${AppLocalizations.of(context).searchPick}",
                      border: OutlineInputBorder(),
                    ),
                  );
                },
                itemBuilder: (context, suggestion) {
                  return ListTile(
                    title: Text(
                        "${suggestion.latitude.toStringAsFixed(5)}, ${suggestion.longitude.toStringAsFixed(5)}"),
                  );
                },
                onSelected: (suggestion) {
                  setState(() {
                    pickup = suggestion;
                  });
                },
              ),
            ),
          if (dismount == null)
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: TypeAheadField<LatLng>(
                suggestionsCallback: searchPlaces,
                builder: (context, controller, focusNode) {
                  return TextField(
                    controller: controller,
                    focusNode: focusNode,
                    decoration: InputDecoration(
                      labelText: "${AppLocalizations.of(context).searchDrop}",
                      border: OutlineInputBorder(),
                    ),
                  );
                },
                itemBuilder: (context, suggestion) {
                  return ListTile(
                    title: Text(
                        "${suggestion.latitude.toStringAsFixed(5)}, ${suggestion.longitude.toStringAsFixed(5)}"),
                  );
                },
                onSelected: (suggestion) {
                  setState(() {
                    dismount = suggestion;
                  });
                },
              ),
            ),

          // ======= MAP =======
          Expanded(
            child: BaseMapWidget(
              onTap: _handleTap,
              overlays: [
                if (route != null) OfferRouteOverlay(routes: route!),
                if (pickup != null)
                  MarkerLayer(markers: [
                    Marker(
                      point: pickup!,
                      width: 60,
                      height: 60,
                      child: const Icon(Icons.circle, color: Colors.green),
                    )
                  ]),
                if (dismount != null)
                  MarkerLayer(markers: [
                    Marker(
                      point: dismount!,
                      width: 60,
                      height: 60,
                      child:
                          const Icon(Icons.flag_circle, color: Colors.red),
                    )
                  ]),
                if (route != null)
                  StartArrivalOverlay(
                    startPoint: route?.points.first,
                    arrivalPoint: route?.points.last,
                    onArrivalRemoved: () {},
                    onStartRemoved: () {},
                  ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: _takeOffer,
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child:  Text("${AppLocalizations.of(context).take} ${AppLocalizations.of(context).offer}"),
          ),
        ],
      ),
    );
  }

  bool _isPointNearPolyline(
      LatLng tap, List<LatLng> polyline, double toleranceMeters) {
    final distance = const Distance();
    for (int i = 0; i < polyline.length - 1; i++) {
      final d =
          _distanceToSegment(tap, polyline[i], polyline[i + 1], distance);
      if (d <= toleranceMeters) return true;
    }
    return false;
  }

  double _distanceToSegment(LatLng p, LatLng v, LatLng w, Distance distance) {
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

  Future<bool> increaseSeats(OfferModel? offerModel) async {
    final String url =
        "$apiBaseUrl/api/increase_seat/${offerModel!.session_id}";
    try {
      final response =
          await http.patch(
            Uri.parse(url),
            headers: {
              'Content-Type': 'application/json',
              "Authorization":"Bearer ${await userModel.jwt.getAccessToken()}"
            }
          );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}