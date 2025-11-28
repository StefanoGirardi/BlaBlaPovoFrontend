import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:multi_user_flutter_app/l10n/app_localizations.dart';
import 'package:multi_user_flutter_app/models/request_model.dart';
import 'package:multi_user_flutter_app/models/user_model.dart';
import 'package:multi_user_flutter_app/pages/active_Requests.dart' hide RequestModel;
import 'package:multi_user_flutter_app/routes.dart';
import 'package:multi_user_flutter_app/utils/sse_utils.dart';
import 'package:multi_user_flutter_app/widgets/drawer_menu.dart';
import 'package:url_launcher/url_launcher.dart'; // Add this import

class RideCard extends StatefulWidget {
  final RequestModel requestModel;
  final UserModel userModel;
  final bool isActive;
  final VoidCallback onTap;
  final bool isMyRequest;
  final VoidCallback? onOpenMaps; // Add this callback

  const RideCard({
    super.key,
    required this.requestModel,
    required this.userModel,
    required this.isActive,
    required this.onTap,
    this.isMyRequest = false,
    this.onOpenMaps, // Add this parameter
  });

  @override
  State<RideCard> createState() => _RideCardState();
}

class _RideCardState extends State<RideCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacityAnimation;

  late String passenger_name = "";
  late String startName = "";
  late String destinationName = "";

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..repeat(reverse: true);

    _opacityAnimation =
        Tween<double>(begin: 0.3, end: 1.0).animate(_controller);
    _loadPlaces();
    setName(widget.requestModel.passenger_id);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> setName(int id) async {
    String? name = (await getUsername(id,(await widget.userModel.jwt.getAccessToken())!));
    setState( () {
      if (name!=null) {
        passenger_name = name;
      }
      else {
        passenger_name = "Uknown"; 
      }
    });
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
        return username.isNotEmpty ? username : null;
      } else if (response.statusCode == 404) {
        return null;
      } else {
        print('Failed to get username: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('Error getting username: $e');
      return null;
    }
  }

  Future<void> _loadPlaces() async {
    final start = await getPlaceName(
      widget.requestModel.start.latitude,
      widget.requestModel.start.longitude,
    );

    final dest = await getPlaceName(
      widget.requestModel.arrival.latitude,
      widget.requestModel.arrival.longitude,
    );

    if (mounted) {
      setState(() {
        startName = start;
        destinationName = dest;
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

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 6,
              offset: Offset(0, 3),
            )
          ],
          border: widget.isMyRequest 
            ? Border.all(color: Colors.blue, width: 2)
            : null,
        ),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left column
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (widget.isMyRequest)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            "${AppLocalizations.of(context).myRequest}",
                            style: TextStyle(
                              color: Colors.blue[800],
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      const SizedBox(height: 8),
                      Text(
                        "${AppLocalizations.of(context).from}: $startName",
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        "${AppLocalizations.of(context).to}: $destinationName",
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 6),
                    ],
                  ),
                ),

                // Right column
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "${AppLocalizations.of(context).passenger}: ${passenger_name}",
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          AnimatedBuilder(
                            animation: _opacityAnimation,
                            builder: (context, child) {
                              return Opacity(
                                opacity:
                                    widget.isActive ? _opacityAnimation.value : 1,
                                child: Container(
                                  width: 16,
                                  height: 16,
                                  decoration: BoxDecoration(
                                    color: widget.isActive
                                        ? Colors.green
                                        : Colors.grey,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "${AppLocalizations.of(context).time}: ${widget.requestModel.startTime.hour.toString().padLeft(2, '0')}:${widget.requestModel.startTime.minute.toString().padLeft(2, '0')}",
                        style: const TextStyle(fontSize: 12),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "${AppLocalizations.of(context).date}: ${widget.requestModel.startTime.day}/${widget.requestModel.startTime.month}/${widget.requestModel.startTime.year}",
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            // Google Maps Button
            const SizedBox(height: 12),
            if (widget.onOpenMaps != null)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: widget.onOpenMaps,
                  icon: const Icon(Icons.directions, color: Colors.white, size: 16),
                  label: Text(
                    "Open in Google Maps",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class MyRequestsPage extends StatefulWidget {
  final UserModel userModel;

  const MyRequestsPage({
    super.key,
    required this.userModel,
  });

  @override
  State<MyRequestsPage> createState() => MyRequestsPageState(userModel: userModel);
}

class MyRequestsPageState extends State<MyRequestsPage> {
  final UserModel userModel;
  int _selectedTab = 0; // 0 for "Requests to Take", 1 for "My Requests"
  
  List<RequestModel> _myRequests = [];
  List<RequestModel> _requestsToTake = [];
  late RequestService requestService;
  StreamSubscription<BroadcastResource>? _subscription;
  MyRequestsPageState({required this.userModel});

  // Add Google Maps launch function
  Future<void> _launchGoogleMaps(RequestModel request) async {
    try {
      final String origin = "${request.start.latitude},${request.start.longitude}";
      final String destination = "${request.arrival.latitude},${request.arrival.longitude}";

      final String googleMapsUrl = "https://www.google.com/maps/dir/?api=1"
          "&origin=$origin"
          "&destination=$destination"
          "&travelmode=driving";

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

  @override
  void initState() {
    super.initState();
    // Initialize empty lists
    _myRequests = [];
    _requestsToTake = [];
    
    // Load initial data
    _loadMyRequests();
    _loadRequestsToTake();
    requestService = RequestService();
    
    // Setup SSE listener
    _setupSSEListener();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  void _setupSSEListener() async {
    _subscription = requestService.connect().listen((updatedRequest) {
      if(!mounted) return;
      setState(() {
        if (updatedRequest.type == "Modified") {
          _updateRequestInLists(updatedRequest.id);
          // Update in both lists if present
        }
        if (updatedRequest.type == "Created") {
          // Add to appropriate list based on ownership
          _addNewRequest(updatedRequest.id);
        }
        if (updatedRequest.type == "Deleted") {
          // Remove from both lists if present
          _removeRequestFromLists(updatedRequest.id);
        }
      });
    }, onError: (error) {
      print('SSE Error: $error');
    });
  }

  Future<void> _updateRequestInLists(int requestId) async {
    final updatedRequest = await getRequest(requestId);
    if (updatedRequest != null) {
      // Update in my requests
      final myRequestIndex = _myRequests.indexWhere((r) => r.session_id == requestId);
      if (myRequestIndex >= 0) {
        _myRequests[myRequestIndex] = updatedRequest;
      }
      
      // Update in requests to take
      final toTakeIndex = _requestsToTake.indexWhere((r) => r.session_id == requestId);
      if (toTakeIndex >= 0) {
        _requestsToTake[toTakeIndex] = updatedRequest;
      }
    }
  }

  Future<void> _addNewRequest(int requestId) async {
    final newRequest = await getRequest(requestId);
    if (newRequest != null) {
      // Check if this is the current user's request
      final isMyRequest = newRequest.passenger_id == userModel.currentUser!.id;
      
      if (isMyRequest) {
        // Add to my requests if not already present
        if (!_myRequests.any((r) => r.session_id == requestId)) {
          _myRequests.add(newRequest);
        }
      } else {
        // Add to requests to take if not already present
        if (!_requestsToTake.any((r) => r.session_id == requestId)) {
          _requestsToTake.add(newRequest);
        }
      }
    }
  }

  void _removeRequestFromLists(int requestId) {
    // Remove from my requests
    _myRequests.removeWhere((r) => r.session_id == requestId);
    
    // Remove from requests to take
    _requestsToTake.removeWhere((r) => r.session_id == requestId);
  }

  Future<RequestModel?> getRequest(int id) async {
    try {
      final response = await http.get(
        Uri.parse('$apiBaseUrl/api/requests/$id'),
        headers: {"Authorization": "Bearer ${await userModel.jwt.getAccessToken()}"}
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return RequestModel.fromJson(data);
      } else {
        return null;
      }
    } catch (e) {
      print('Error fetching request: $e');
      return null;
    }
  }

  Future<void> getMyRequests() async {
    try {
      final response = await http.get(
        Uri.parse('$apiBaseUrl/api/all_my_requests'),
        headers: {"Authorization": "Bearer ${await userModel.jwt.getAccessToken()}"}
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        final allMyRequests = data.map((jsonItem) => RequestModel.fromJson(jsonItem)).toList();
        setState(() {
          _myRequests = allMyRequests;
        });
      } else {
        
      }
    } catch (e) {
      print('Error fetching requests: $e');
    }
  }

  Future<void> getRequestsToTake() async {
    try {
      final response = await http.get(
        Uri.parse('$apiBaseUrl/api/all_requests_to_take'),
        headers: {"Authorization": "Bearer ${await userModel.jwt.getAccessToken()}"}
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        final allRequestsToTake = data.map((jsonItem) => RequestModel.fromJson(jsonItem)).toList();
        setState(() {
          _requestsToTake = allRequestsToTake;
        });
      } else {
        
      }
    } catch (e) {
      print('Error fetching requests: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("${AppLocalizations.of(context).myRequests}"),
      ),
      body: Column(
        children: [
          // Tab Bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(25),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedTab = 0),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: _selectedTab == 0 ? Colors.redAccent : Colors.transparent,
                          borderRadius: BorderRadius.circular(25),
                        ),
                        child: Center(
                          child: Text(
                            "${AppLocalizations.of(context).requestToTake}",
                            style: TextStyle(
                              color: _selectedTab == 0 ? Colors.white : Colors.grey[600],
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedTab = 1),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: _selectedTab == 1 ? Colors.blue : Colors.transparent,
                          borderRadius: BorderRadius.circular(25),
                        ),
                        child: Center(
                          child: Text(
                            "${AppLocalizations.of(context).myRequests}",
                            style: TextStyle(
                              color: _selectedTab == 1 ? Colors.white : Colors.grey[600],
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Content based on selected tab
          Expanded(
            child: _selectedTab == 0 
                ? _buildRequestsToTakeContent()
                : _buildMyRequestsContent(),
          ),
        ],
      ),
      endDrawer: DrawerMenu(userModel: userModel),
    );
  }

  Widget _buildRequestsToTakeContent() {
    if (_requestsToTake.isEmpty) {
      return _buildEmptyState(isMyRequests: false);
    }

    return ListView.builder(
      itemCount: _requestsToTake.length,
      itemBuilder: (context, index) {
        final request = _requestsToTake[index];
        
        return RideCard(
          requestModel: request,
          userModel: userModel,
          isActive: _isRequestActive(request),
          isMyRequest: false, // These are always other people's requests
          onTap: () {
            // Navigate to take request
            Navigator.pushNamed(
              context,
              '/request_review',
              arguments: request,
            );
          },
          onOpenMaps: () => _launchGoogleMaps(request), // Add Google Maps callback
        );
      },
    );
  }

  Widget _buildMyRequestsContent() {
    if (_myRequests.isEmpty) {
      return _buildEmptyState(isMyRequests: true);
    }

    return ListView.builder(
      itemCount: _myRequests.length,
      itemBuilder: (context, index) {
        final request = _myRequests[index];
        
        return RideCard(
          requestModel: request,
          userModel: userModel,
          isActive: _isRequestActive(request),
          isMyRequest: true, // These are always user's requests
          onTap: () {
            // Navigate to modify request
            Navigator.pushNamed(
              context,
              '/modify_request',
              arguments: request,
            );
          },
          onOpenMaps: () => _launchGoogleMaps(request), // Add Google Maps callback
        );
      },
    );
  }

  Widget _buildEmptyState({bool isMyRequests = false}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isMyRequests ? Icons.person : Icons.search,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            isMyRequests ? "${AppLocalizations.of(context).noReqCreated}" : "${AppLocalizations.of(context).noReqAvailable}",
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isMyRequests 
                ? "Create your first request to find a ride"
                : "Check back later for available ride requests",
            style: const TextStyle(
              color: Colors.grey,
            ),
            textAlign: TextAlign.center,
          ),
          if (isMyRequests) ...[
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pushNamed(context, '/create_request');
              },
              icon: const Icon(Icons.add),
              label: const Text("Create Request"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
              ),
            ),
          ] else ...[
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () {
                // Refresh requests to take
                _loadRequestsToTake();
              },
              icon: const Icon(Icons.refresh),
              label:  Text("${AppLocalizations.of(context).refresh}"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ],
      ),
    );
  }

  bool _isRequestActive(RequestModel request) {
    final now = DateTime.now();
    final requestTime = request.startTime;
    
    // Request is active if it's in the future
    return requestTime.isAfter(now);
  }

  Future<void> _loadMyRequests() async {
    try {
      final id = userModel.currentUser!.id;
      final response =
          await http.get(
            Uri.parse('$apiBaseUrl/api/all_my_requests/$id'),
            headers: {"Authorization":"Bearer ${await userModel.jwt.getAccessToken()}"}
          );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final List<dynamic> data = jsonDecode(response.body);
        setState(() {
          _myRequests = data.map((jsonItem) => RequestModel.fromJson(jsonItem)).toList();
        });
      } else {
        setState(() {
          _myRequests = [];
        });
      }
    } catch (e) {
      print('Error fetching my requests: $e');
      setState(() {
        _myRequests = [];
      });
    }
  }

  Future<void> _loadRequestsToTake() async {
    try {
      final id = userModel.currentUser!.id;
      final response =
          await http.get(
            Uri.parse('$apiBaseUrl/api/all_requests_to_take/$id'),
            headers: {"Authorization":"Bearer ${await userModel.jwt.getAccessToken()}"}
          );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final List<dynamic> data = jsonDecode(response.body);
        setState(() {
          _requestsToTake = data.map((jsonItem) => RequestModel.fromJson(jsonItem)).toList();
        });
      } else {
        setState(() {
          _requestsToTake = [];
        });
      }
    } catch (e) {
      print('Error fetching requests to take: $e');
      setState(() {
        _requestsToTake = [];
      });
    }
  }

  void _refreshCurrentTab() {
    if (_selectedTab == 0) {
      _loadRequestsToTake();
    } else {
      _loadMyRequests();
    }
  }
}