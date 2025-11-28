import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:multi_user_flutter_app/l10n/app_localizations.dart';
import 'package:multi_user_flutter_app/models/user_model.dart';
import 'package:multi_user_flutter_app/pages/active_offers.dart';
import 'package:multi_user_flutter_app/routes.dart';
import 'package:multi_user_flutter_app/utils/sse_utils.dart';
import 'package:multi_user_flutter_app/widgets/drawer_menu.dart';

class RideCard extends StatefulWidget {
  final OfferModel offerModel;
  final bool isActive;
  final VoidCallback onTap;
  final bool isMyOffer;
  final UserModel userModel;

  const RideCard({
    super.key,
    required this.offerModel,
    required this.isActive,
    required this.onTap,
    this.isMyOffer = false,
    required this.userModel,
  });

  @override
  State<RideCard> createState() => _RideCardState();
}

class _RideCardState extends State<RideCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacityAnimation;
  
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
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadPlaces() async {
    final start = await getPlaceName(
      widget.offerModel.start.latitude,
      widget.offerModel.start.longitude,
    );

    final dest = await getPlaceName(
      widget.offerModel.destination.latitude,
      widget.offerModel.destination.longitude,
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

  Future<String?> _getDriverName(int id) async {
    try {
      final token = await widget.userModel.jwt.getAccessToken();
      if (token == null) {
        print('Token is null');
        return "Unknown";
      }
      
      final name = await getUsername(id, token);
      return name ?? "Unknown";
    } catch (e) {
      print('Error getting driver name: $e');
      return "Unknown";
    }
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
          border: widget.isMyOffer 
            ? Border.all(color: Colors.blue, width: 2)
            : null,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left column
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.isMyOffer)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        "${AppLocalizations.of(context)!.myOffers}",
                        style: TextStyle(
                          color: Colors.blue[800],
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),
                  Text(
                    "${AppLocalizations.of(context)!.from}: $startName",
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "${AppLocalizations.of(context)!.to}: $destinationName",
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "${AppLocalizations.of(context)!.seatsAvailable}: ${widget.offerModel.seat_available}",
                    style: TextStyle(
                      color: widget.offerModel.seat_available > 0 
                          ? Colors.green 
                          : Colors.red,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
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
                      FutureBuilder<String?>(
                        future: _getDriverName(widget.offerModel.driver_id),
                        builder: (context, snapshot) {
                          final driverName = snapshot.data ?? "Loading...";
                          return Text(
                            "${AppLocalizations.of(context)!.driver}: $driverName",
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          );
                        },
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
                    "${AppLocalizations.of(context)!.car}: ${widget.offerModel.car?.brand ?? 'Unknown'} ${widget.offerModel.car?.model ?? ''}",
                    style: const TextStyle(fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "${AppLocalizations.of(context)!.time}: ${widget.offerModel.start_time.hour.toString().padLeft(2, '0')}:${widget.offerModel.start_time.minute.toString().padLeft(2, '0')}",
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Future<String?> getUsername(int id, String token) async {
    try {
      final response = await http.get(
        Uri.parse("$apiBaseUrl/api/get_user_full_name/$id"),
        headers: {
          "Authorization": "Bearer $token"
        },
      );
      
      print('Username API response: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final username = response.body.trim();
        print('Username received: $username');
        return username.isNotEmpty ? username : null;
      } else if (response.statusCode == 404) {
        print('Username not found for ID: $id');
        return null;
      } else {
        print('Failed to get username: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      print('Error getting username: $e');
      return null;
    }
  }
}

class MyOffersPage extends StatefulWidget {
  final UserModel userModel;

  const MyOffersPage({
    super.key,
    required this.userModel,
  });

  @override
  State<MyOffersPage> createState() => _MyOffersPageState();
}

class _MyOffersPageState extends State<MyOffersPage> {
  int _selectedTab = 0; // 0 for "To Take", 1 for "My Offers"
  
  List<OfferModel> _myOffers = [];
  List<OfferModel> _offersToTake = [];
  late OfferService offerService;
  StreamSubscription<BroadcastResource>? _subscription;

  @override
  void initState() {
    super.initState();
    // Initialize empty lists
    _myOffers = [];
    _offersToTake = [];
    
    // Load initial data
    _loadMyOffers();
    _loadOffersToTake();
    offerService = OfferService();
    
    // Setup SSE listener
    _setupSSEListener();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  void _setupSSEListener() {
    _subscription = offerService.connect().listen((updatedOffer) {
      if(!mounted) return;
      setState(() {
        if (updatedOffer.type == "Modified") {
          // Update in both lists if present
          _updateOfferInLists(updatedOffer.id);
        }
        if (updatedOffer.type == "Created") {
          // Add to appropriate list based on ownership
          _addNewOffer(updatedOffer.id);
        }
        if (updatedOffer.type == "Deleted") {
          // Remove from both lists if present
          _removeOfferFromLists(updatedOffer.id);
        }
      });
    }, onError: (error) {
      print('SSE Error: $error');
    });
  }

  void _updateOfferInLists(int offerId) async {
    final updatedOffer = await getOffer(offerId);
    if (updatedOffer != null) {
      // Update in my offers
      final myOfferIndex = _myOffers.indexWhere((o) => o.session_id == offerId);
      if (myOfferIndex >= 0) {
        _myOffers[myOfferIndex] = updatedOffer;
      }
      
      // Update in offers to take
      final toTakeIndex = _offersToTake.indexWhere((o) => o.session_id == offerId);
      if (toTakeIndex >= 0) {
        _offersToTake[toTakeIndex] = updatedOffer;
      }
    }
  }

  void _addNewOffer(int offerId) async {
    final newOffer = await getOffer(offerId);
    if (newOffer != null) {
      // Check if this is the current user's offer
      final isMyOffer = newOffer.driver_id == widget.userModel.currentUser!.id;
      
      if (isMyOffer) {
        // Add to my offers if not already present
        if (!_myOffers.any((o) => o.session_id == offerId)) {
          _myOffers.add(newOffer);
        }
      } else {
        // Add to offers to take if not already present
        if (!_offersToTake.any((o) => o.session_id == offerId)) {
          _offersToTake.add(newOffer);
        }
      }
    }
  }

  void _removeOfferFromLists(int offerId) {
    // Remove from my offers
    _myOffers.removeWhere((o) => o.session_id == offerId);
    
    // Remove from offers to take
    _offersToTake.removeWhere((o) => o.session_id == offerId);
  }

  Future<OfferModel?> getOffer(int id) async {
    try {
      final response = await http.get(
        Uri.parse('$apiBaseUrl/api/offers/$id'),
        headers: {"Authorization": "Bearer ${await widget.userModel.jwt.getAccessToken()}"}
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return OfferModel.fromJson(data);
      } else {
        return null;
      }
    } catch (e) {
      print('Error fetching offer: $e');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("${AppLocalizations.of(context)!.myOffers}"),
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
                            "${AppLocalizations.of(context)!.offersToTake}",
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
                            "${AppLocalizations.of(context)!.myOffers}",
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
                ? _buildOffersToTakeContent()
                : _buildMyOffersContent(),
          ),
        ],
      ),
      endDrawer: DrawerMenu(userModel: widget.userModel),
    );
  }

  Widget _buildOffersToTakeContent() {
    if (_offersToTake.isEmpty) {
      return _buildEmptyState(isMyOffers: false);
    }

    return ListView.builder(
      itemCount: _offersToTake.length,
      itemBuilder: (context, index) {
        final offer = _offersToTake[index];
        
        return RideCard(
          offerModel: offer,
          isActive: _isOfferActive(offer),
          isMyOffer: false, // These are always other people's offers
          onTap: () {
            // Navigate to take offer
            Navigator.pushNamed(
              context,
              '/offer_review',
              arguments: offer,
            );
          },
          userModel: widget.userModel,
        );
      },
    );
  }

  Widget _buildMyOffersContent() {
    if (_myOffers.isEmpty) {
      return _buildEmptyState(isMyOffers: true);
    }

    return ListView.builder(
      itemCount: _myOffers.length,
      itemBuilder: (context, index) {
        final offer = _myOffers[index];
        
        return RideCard(
          offerModel: offer,
          isActive: _isOfferActive(offer),
          isMyOffer: true, // These are always user's offers
          onTap: () {
            // Navigate to modify offer
            Navigator.pushNamed(
              context,
              '/modify_offer',
              arguments: offer,
            );
          },
          userModel: widget.userModel,
        );
      },
    );
  }

  Widget _buildEmptyState({bool isMyOffers = false}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isMyOffers ? Icons.directions_car : Icons.search,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            isMyOffers ? "No Offers Created" : "No Offers Available",
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isMyOffers 
                ? "Create your first offer to start giving rides"
                : "Check back later for available rides",
            style: const TextStyle(
              color: Colors.grey,
            ),
            textAlign: TextAlign.center,
          ),
          if (isMyOffers) ...[
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pushNamed(context, '/create_offer');
              },
              icon: const Icon(Icons.add),
              label: Text("${AppLocalizations.of(context)!.createOffer}"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
              ),
            ),
          ] else ...[
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () {
                // Refresh offers to take
                _loadOffersToTake();
              },
              icon: const Icon(Icons.refresh),
              label: Text("${AppLocalizations.of(context)!.refresh}"),
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

  bool _isOfferActive(OfferModel offer) {
    final now = DateTime.now();
    final offerTime = offer.start_time;
    
    // Offer is active if it's in the future and has available seats
    return offer.seat_available > 0 && offerTime.isAfter(now);
  }

  Future<void> _loadMyOffers() async {
    try {
      final id = widget.userModel.currentUser!.id;
      final response =
          await http.get(
            Uri.parse('$apiBaseUrl/api/all_my_offers/$id'),
            headers: {"Authorization":"Bearer ${await widget.userModel.jwt.getAccessToken()}"}  
          );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final List<dynamic> data = jsonDecode(response.body);
        setState(() {
          _myOffers = data.map((jsonItem) => OfferModel.fromJson(jsonItem)).toList();
        });
      } else {
        setState(() {
          _myOffers = [];
        });
      }
    } catch (e) {
      print('Error fetching my offers: $e');
      setState(() {
        _myOffers = [];
      });
    }
  }

  Future<void> _loadOffersToTake() async {
    try {
      final id = widget.userModel.currentUser!.id;
      final response =
          await http.get(
            Uri.parse('$apiBaseUrl/api/all_offers_to_take/$id'),
            headers: {"Authorization":"Bearer ${await widget.userModel.jwt.getAccessToken()}"}
          );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final List<dynamic> data = jsonDecode(response.body);
        setState(() {
          _offersToTake = data.map((jsonItem) => OfferModel.fromJson(jsonItem)).toList();
        });
      } else {
        setState(() {
          _offersToTake = [];
        });
      }
    } catch (e) {
      print('Error fetching offers to take: $e');
      setState(() {
        _offersToTake = [];
      });
    }
  }

  void _refreshCurrentTab() {
    if (_selectedTab == 0) {
      _loadOffersToTake();
    } else {
      _loadMyOffers(); 
    }
  }
}