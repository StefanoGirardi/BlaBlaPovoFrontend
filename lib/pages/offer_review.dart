import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'package:multi_user_flutter_app/l10n/app_localizations.dart';
import 'package:multi_user_flutter_app/models/stop_model.dart';
import 'package:multi_user_flutter_app/models/user_model.dart';
import 'package:multi_user_flutter_app/pages/active_offers.dart';
import 'package:multi_user_flutter_app/pages/modify_offer.dart';
import 'package:multi_user_flutter_app/routes.dart';
import 'package:multi_user_flutter_app/widgets/base_map_widget.dart';
import 'package:multi_user_flutter_app/widgets/drawer_menu.dart';
import 'package:multi_user_flutter_app/widgets/map_widget.dart';
import 'package:multi_user_flutter_app/widgets/modify_stop_overlay.dart';
import 'package:multi_user_flutter_app/widgets/offer_route_overlay.dart';
import 'package:multi_user_flutter_app/widgets/start_arrival_overlay.dart';
import 'package:multi_user_flutter_app/utils/sse_utils.dart';

class OfferReview extends StatefulWidget {
  final UserModel userModel;
  const OfferReview({super.key, required this.userModel});

  @override
  State<OfferReview> createState() => _OfferReviewState(userModel: userModel);
}

class _OfferReviewState extends State<OfferReview> {
  OfferModel? offerModel;
  final UserModel userModel;
  RouteOption? route;

  String? _startName;
  String? _arrivalName;
  Map<int, String> _stopNames = {};

  // NEW: State for modify mode
  bool _isModifyMode = false;
  LatLng? _modifiedStop1;
  LatLng? _modifiedStop2;
  int? _currentlyModifyingStop; // 1 or 2

  // SSE service for real-time updates
  late OfferService _offerService;
  StreamSubscription<BroadcastResource>? _offerSubscription;

  _OfferReviewState({required this.userModel});

  @override
  void initState() {
    super.initState();
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
            _loadStopNames();
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
    _offerSubscription?.cancel();
    _offerService.disconnect();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (offerModel == null) {
      offerModel = ModalRoute.of(context)!.settings.arguments as OfferModel;
      _buildRoute();
      _loadPlaceNames();
      _loadStopNames();
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
    if (!mounted) return;
    setState(() {
      _startName = startName;
      _arrivalName = arrivalName;
    });
  }

  Future<void> _loadStopNames() async {
    final Map<int, String> stopNames = {};
    
    for (final stop in offerModel!.stops) {
      final stopName = await getPlaceName(
        stop.stop.latitude,
        stop.stop.longitude,
      );
      stopNames[stop.id] = stopName;
    }
    if (!mounted) return;
    setState(() {
      _stopNames = stopNames;
    });
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

  List<Stop> _getUserStops() {
    return offerModel!.stops.where((stop) => stop.id == userModel.currentUser!.id).toList();
  }

  List<Stop> _getOtherStops() {
    return offerModel!.stops.where((stop) => stop.id != userModel.currentUser!.id).toList();
  }

  // NEW: Enter modify mode
  void _enterModifyMode() {
    final userStops = _getUserStops();
    if (userStops.length != 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must have exactly 2 stops to modify')),
      );
      return;
    }

    setState(() {
      _isModifyMode = true;
      _modifiedStop1 = userStops[0].stop;
      _modifiedStop2 = userStops[1].stop;
      _currentlyModifyingStop = null;
    });
  }

  void _exitModifyMode() {
    setState(() {
      _isModifyMode = false;
      _modifiedStop1 = null;
      _modifiedStop2 = null;
      _currentlyModifyingStop = null;
    });
  }

  void _handleMapTapInModifyMode(TapPosition tapPosition, LatLng latLng) {
    if (!_isModifyMode || _currentlyModifyingStop == null) return;

    final routePolyline = route?.points ?? [];
    if (!_isPointNearPolyline(latLng, routePolyline, 100.0)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${AppLocalizations.of(context).tooFarFromRouteErr}'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    setState(() {
      if (_currentlyModifyingStop == 1) {
        _modifiedStop1 = latLng;
      } else {
        _modifiedStop2 = latLng;
      }
      _currentlyModifyingStop = null; // Reset after modification
    });
  }

  bool _isPointNearPolyline(LatLng tap, List<LatLng> polyline, double toleranceMeters) {
    if (polyline.isEmpty) return true;
    
    final distance = const Distance();
    for (int i = 0; i < polyline.length - 1; i++) {
      final d = _distanceToSegment(tap, polyline[i], polyline[i + 1], distance);
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

  Future<void> _saveModifiedStops() async {
    if (_modifiedStop1 == null || _modifiedStop2 == null) return;

    await _callModifyStopsAPI(_modifiedStop1!, _modifiedStop2!);
    _exitModifyMode();
  }

  void _swapStops() {
    if (!_isModifyMode) return;
    
    setState(() {
      final temp = _modifiedStop1;
      _modifiedStop1 = _modifiedStop2;
      _modifiedStop2 = temp;
    });
  }

  Future<void> _callModifyStopsAPI(LatLng stop1, LatLng stop2) async {
    final String url = "$apiBaseUrl/api/modify_stops";
    final body = {
      'session_id': offerModel!.session_id,
      'stop1': {
        'lat': stop1.latitude,
        'lng': stop1.longitude,
      },
      'stop2': {
        'lat': stop2.latitude,
        'lng': stop2.longitude,
      },
    };

    try {
      final response = await http.patch(
        Uri.parse(url),
        body: jsonEncode(body),
        headers: {
          'Content-Type': 'application/json',
          "Authorization": "Bearer ${await userModel.jwt.getAccessToken()}"
        }
      );

      if (response.statusCode == 200) {
        // Update local state
        setState(() {
          final userStops = _getUserStops();
          if (userStops.length >= 2) {
            // Update stops while preserving order
            offerModel!.stops.removeWhere((s) => s.id == userModel.currentUser!.id);
            offerModel!.stops.add(Stop(id: userModel.currentUser!.id, stop: stop1));
            offerModel!.stops.add(Stop(id: userModel.currentUser!.id, stop: stop2));
          }
        });

        // Rebuild route and reload names
        _buildRoute();
        _loadStopNames();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${AppLocalizations.of(context).modStopsSucc}')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${AppLocalizations.of(context).modStopsErr}: ${response.statusCode}')),
        );
      }
    } catch (e) {
      debugPrint('Network error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Network error: $e')),
      );
    }
  }

  Future<void> _renounceSeat() async {
    final String url = "$apiBaseUrl/api/renounce_seat/${offerModel!.session_id}";

    try {
      final response = await http.patch(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          "Authorization":"Bearer ${await userModel.jwt.getAccessToken()}"
        }
      );
      
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${AppLocalizations.of(context).seatRenSucc}')),
        );
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${AppLocalizations.of(context).seatRenErr}: ${response.statusCode}')),
        );
      }
    } catch (e) {
      debugPrint('Network error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Network error: $e')),
      );
    }
  }

  Future<void> _showRenounceConfirmation() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("${AppLocalizations.of(context).renounce} ${AppLocalizations.of(context).seat}"),
        content: const Text("Are you sure you want to renounce your seat? This action cannot be undone."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text("${AppLocalizations.of(context).cancel}"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text("${AppLocalizations.of(context).renounce}"),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      _renounceSeat();
    }
  }

  @override
  Widget build(BuildContext context) {
    final startTime = offerModel?.start_time;
    final arrivalTime = (startTime != null && route != null)
        ? startTime.add(Duration(minutes: route!.etaMinutes))
        : null;
    
    List<int> ids = []; 
    for (var stop in offerModel!.stops) {
      ids.add(stop.id);
    }
    
    final isPassenger = ids.contains(userModel.currentUser!.id);
    final userStops = _getUserStops();
    final otherStops = _getOtherStops();

    return Scaffold(
      appBar: AppBar(
        title: Text(_isModifyMode ? "${AppLocalizations.of(context).modStops}" : "${AppLocalizations.of(context).offDet}"),
        backgroundColor: _isModifyMode ? Colors.orange : Colors.redAccent,
        centerTitle: true,
        leading: _isModifyMode 
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: _exitModifyMode,
              )
            : null,
      ),
      endDrawer: _isModifyMode ? null : DrawerMenu(userModel: userModel),
      body: Column(
        children: [
          // INFO PANEL
          if (!_isModifyMode) ...[
            Expanded(
              flex: 2,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isPassenger)
                      Card(
                        elevation: 2.0,
                        color: Colors.green.shade100,
                        child: Padding(
                          padding: EdgeInsets.all(8.0),
                          child: Row(
                            children: [
                              Icon(Icons.check_circle, color: Colors.green),
                              SizedBox(width: 8),
                              Text(
                                "${AppLocalizations.of(context).gotSeat}",
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ),
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
                                "${AppLocalizations.of(context).startTime}: ${startTime.toLocal().toString()}",
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white
                                ),
                              ),
                            if (arrivalTime != null)
                              Text(
                                "${AppLocalizations.of(context).extTime}: ${arrivalTime.toLocal().toString()}",
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white
                                ),
                              ),
                          ],
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
                    
                    if (userStops.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "${AppLocalizations.of(context).yourStops}:",
                              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
                            ),
                            ...userStops.asMap().entries.map((entry) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2.0),
                              child: Row(
                                children: [
                                  Text("${entry.key + 1}. "),
                                  Expanded(child: Text(_stopNames[entry.value.id] ?? 'Loading...')),
                                ],
                              ),
                            )).toList(),
                          ],
                        ),
                      ),
                    
                    if (otherStops.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "${AppLocalizations.of(context).othersStops}:",
                              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
                            ),
                            ...otherStops.map((stop) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2.0),
                              child: Text("• ${_stopNames[stop.id] ?? 'Loading...'}"),
                            )).toList(),
                          ],
                        ),
                      ),
                    
                    if (offerModel != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2.0),
                        child: Text("${AppLocalizations.of(context).seatsAvailable}: ${offerModel!.seat_available}"),
                      ),
                    if (offerModel?.car != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2.0),
                        child: Text("${AppLocalizations.of(context).car}: ${offerModel!.car!.brand} ${offerModel!.car!.model}"),
                      ),
                  ],
                ),
              ),
            ),
          ],

          // MODIFY MODE CONTROLS
          if (_isModifyMode) ...[
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.orange.shade50,
              child: Column(
                children: [
                  Text(
                    "${AppLocalizations.of(context).modStops}",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _currentlyModifyingStop == null
                        ? "${AppLocalizations.of(context).modStopBanner1}"
                        : "${AppLocalizations.of(context).modStopBanner2} $_currentlyModifyingStop",
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 16),
                  
                  // Stop selection buttons
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _currentlyModifyingStop = 1;
                            });
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _currentlyModifyingStop == 1 
                                ? Colors.orange 
                                : Colors.grey,
                            foregroundColor: Colors.white,
                          ),
                          child: Text("${AppLocalizations.of(context).modStops} 1"),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _currentlyModifyingStop = 2;
                            });
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _currentlyModifyingStop == 2 
                                ? Colors.orange 
                                : Colors.grey,
                            foregroundColor: Colors.white,
                          ),
                          child: Text("${AppLocalizations.of(context).modStops} 2"),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  
                  // Action buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _swapStops,
                          child: Text("${AppLocalizations.of(context).swapStops}"),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _saveModifiedStops,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                          ),
                          child: Text("${AppLocalizations.of(context).save}"),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],

          // MAP
          Expanded(
            flex: _isModifyMode ? 4 : 3,
            child: BaseMapWidget(
              onTap: _isModifyMode ? _handleMapTapInModifyMode : null,
              overlays: [
                if (route != null) OfferRouteOverlay(routes: route!),
                StartArrivalOverlay(
                  startPoint: route?.points.first,
                  arrivalPoint: route?.points.last,
                  onArrivalRemoved: () {},
                  onStartRemoved: () {},
                ),
                
                // Show stops based on mode
                if (_isModifyMode && _modifiedStop1 != null && _modifiedStop2 != null)
                  MarkerLayer(
                    markers: [
                      // Stop 1 in modify mode
                      Marker(
                        point: _modifiedStop1!,
                        width: 50,
                        height: 50,
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _currentlyModifyingStop = 1;
                            });
                          },
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: _currentlyModifyingStop == 1 ? Colors.orange : Colors.blue,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 3,
                                  ),
                                ),
                                child: Text(
                                  '1',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              Icon(
                                Icons.location_pin,
                                color: _currentlyModifyingStop == 1 ? Colors.orange : Colors.blue,
                                size: 35,
                              ),
                            ],
                          ),
                        ),
                      ),
                      // Stop 2 in modify mode
                      Marker(
                        point: _modifiedStop2!,
                        width: 50,
                        height: 50,
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _currentlyModifyingStop = 2;
                            });
                          },
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: _currentlyModifyingStop == 2 ? Colors.orange : Colors.green,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 3,
                                  ),
                                ),
                                child: Text(
                                  '2',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              Icon(
                                Icons.location_pin,
                                color: _currentlyModifyingStop == 2 ? Colors.orange : Colors.green,
                                size: 35,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  )
                else if (!_isModifyMode && userStops.isNotEmpty)
                  ModifyStopOverlay(
                    currentUserId: userModel.currentUser!.id,
                    stops: userStops,
                    onStopModified: (_) {},
                  ),
              ],
            ),
          ),

          // ACTION BUTTONS (only show in normal mode)
          if (!_isModifyMode)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Colors.grey[300]!)),
              ),
              child: isPassenger
                  ? Column(
                      children: [
                        Card(
                          elevation: 2.0,
                          color: Colors.blue.shade50,
                          child: Padding(
                            padding: EdgeInsets.all(8.0),
                            child: Row(
                              children: [
                                Icon(Icons.edit, color: Colors.blue),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    "${AppLocalizations.of(context).modStopBanner3}",
                                    style: TextStyle(fontSize: 12),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton.icon(
                          onPressed: _enterModifyMode,
                          icon: const Icon(Icons.edit_location),
                          label: Text("${AppLocalizations.of(context).modStops}"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(double.infinity, 50),
                          ),
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton.icon(
                          onPressed: _showRenounceConfirmation,
                          icon: const Icon(Icons.exit_to_app),
                          label: Text("${AppLocalizations.of(context).renounce} ${AppLocalizations.of(context).seat}"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(double.infinity, 50),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "${AppLocalizations.of(context).renounceSeatBanner}",
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    )
                  : Column(
                      children: [
                        Text(
                          "${AppLocalizations.of(context).notGotSeat}",
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                          },
                          child: Text("${AppLocalizations.of(context).backToOff}"),
                        ),
                      ],
                    ),
            ),
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
