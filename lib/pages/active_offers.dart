import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:multi_user_flutter_app/l10n/app_localizations.dart';
import 'package:multi_user_flutter_app/models/stop_model.dart';
import 'package:multi_user_flutter_app/models/user_model.dart';
import 'package:multi_user_flutter_app/pages/create_offer.dart';
import 'package:multi_user_flutter_app/routes.dart';
import 'package:multi_user_flutter_app/utils/sse_utils.dart';
import 'package:multi_user_flutter_app/widgets/drawer_menu.dart';


//TODO:  maybr refractor the offer class to another file
class OfferModel extends ChangeNotifier {
  int session_id;
  int driver_id;
  LatLng start;
  LatLng destination;
  DateTime start_time;
  List<LatLng> route;
  List<Stop> stops;   
  int seat_available;
  Car? car;

  OfferModel({
    required this.session_id,
    required this.driver_id,
    required this.start,
    required this.destination,
    required this.route,
    required this.stops,
    required this.start_time,
    required this.seat_available,
    this.car,
  });

  factory OfferModel.fromJson(Map<String, dynamic> json) {
    return OfferModel(
      session_id: json['session_id'] as int,
      driver_id: json['driver_id'] as int,
      start: _parseLatLng(json['start']),
      destination: _parseLatLng(json['arrival']),
      route: (json['route']?['route'] as List<dynamic>?)
              ?.map((point) => LatLng(
                    (point['lat'] as num).toDouble(),
                    (point['lng'] as num).toDouble(),
                  ))
              .toList() ??
          [], // fallback to empty list
         stops: (json['stops'] as List<dynamic>? ?? [])
          .map((e) => Stop.fromJson(e as Map<String, dynamic>))
          .toList(), // fallback to empty list
      start_time: DateTime.parse(json['start_time'] as String).toLocal(),
      seat_available: json['seats_available'] as int,
      car: json['auto'] != null ? Car.fromJson(json['auto']) : null,
    );
  }

  static LatLng _parseLatLng(dynamic locationData) {
    if (locationData is Map<String, dynamic>) {
      return LatLng(
        locationData['lat'] as double,
        locationData['lng'] as double,
      );
    } else if (locationData is String) {
      final parts = locationData.split(',');
      if (parts.length == 2) {
        return LatLng(
          double.parse(parts[0]),
          double.parse(parts[1]),
        );
      }
    }
    throw FormatException('Invalid location data: $locationData');
  }
}


enum TimeFilter {
  all,
  nextHour, //for offers that starts from the next hour onward
  nextThreeHours, //for offers that starts 3 hours from now onward
  today,
  tomorrow,
}

class RideCard extends StatefulWidget {
  final OfferModel offerModel;
  final bool isActive; // to make the dot green and show it's active
  final VoidCallback onTap; 
  final UserModel userModel;

  const RideCard({
    super.key,
    required this.offerModel,
    required this.isActive,
    required this.onTap,
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
  
  // fn to get the name of the start and show it on the card
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
          borderRadius: BorderRadius.circular(30),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 6,
              offset: Offset(0, 3),
            )
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FutureBuilder<String?>(
                    future: _getDriverName(widget.offerModel.driver_id),
                    builder: (context, snapshot) {
                      final driverName = snapshot.data ?? "Loading...";
                      return Text("${AppLocalizations.of(context).name}: $driverName");
                    },
                  ),
                  const SizedBox(height: 8),
                  Text("${AppLocalizations.of(context).from}: $startName"),
                  const SizedBox(height: 8),
                  Text("${AppLocalizations.of(context).to}: $destinationName"),
                ],
              ),
            ),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                          "${AppLocalizations.of(context).seatsAvailable}: ${widget.offerModel.seat_available}"),
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
                  Text("${AppLocalizations.of(context).car}: ${widget.offerModel.car?.brand ?? 'Unknown'} ${widget.offerModel.car?.model ?? ''}"),
                  const SizedBox(height: 8),
                  Text(
                      "${AppLocalizations.of(context).time}: ${widget.offerModel.start_time.hour.toString().padLeft(2, '0')}:${widget.offerModel.start_time.minute.toString().padLeft(2, '0')}"),
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
        Uri.parse("$apiBaseUrl/api/get_username/$id"),
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


class OffersPage extends StatefulWidget {
  final UserModel userModel;

  const OffersPage({
    super.key,
    required this.userModel,
  });

  @override
  State<OffersPage> createState() => _OffersPageState();
}

class _OffersPageState extends State<OffersPage> {
  List<OfferModel> offers = [];
  List<OfferModel> filteredOffers = [];
  late OfferService _offerService;
  StreamSubscription<BroadcastResource>? _subscription;

  // Filter states
  TimeFilter _selectedTimeFilter = TimeFilter.all;
  String _startLocationFilter = '';
  String _destinationFilter = '';
  final TextEditingController _startLocationController = TextEditingController();
  final TextEditingController _destinationController = TextEditingController();

  bool isLoading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _offerService = OfferService();
    _loadInitialOffers();
    _setupSSEListener();
  }

  // fn to subscribe and listen to the sse events for offers update
  void _setupSSEListener() {
    _subscription = _offerService.connect().listen((updatedRequest) async {
      final off = (await getOffer(updatedRequest.id));
      if (!mounted) return;
      setState(()  {
        final index = offers.indexWhere(
          (r) => r.session_id == updatedRequest.id,
        );
        if (updatedRequest.type=="Modified") {
          if (index >= 0) {
            offers[index] = off!;
          } 
        }
        if (updatedRequest.type=="Created") {
          offers.add(off!);
        }
        if (updatedRequest.type=="Deleted") {
          if (index >= 0) {
            offers.removeAt(index);
          } 
        }
        _applyFilters(); 
      });
    }, onError: (error) {
      print('SSE Error: $error');
    });
  }

  Future<void> _loadInitialOffers() async {
    try {
      final id = widget.userModel.currentUser!.id;
      final response = await http.get(
        Uri.parse('$apiBaseUrl/api/all_offers/$id'),
        headers: {"Authorization":"Bearer ${await widget.userModel.jwt.getAccessToken()}"}
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final List<dynamic> data = jsonDecode(response.body);
        final loadedOffers = data.map((jsonItem) => OfferModel.fromJson(jsonItem)).toList();

        setState(() {
          offers = loadedOffers;
          filteredOffers = loadedOffers;
          isLoading = false;
        });
      } else {
        setState(() {
          error = "Server error: ${response.statusCode}";
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        error = "Error fetching offers: $e";
        isLoading = false;
      });
    }
  }

  Future<OfferModel?> getOffer(int id) async {
    try {
      final claims = await widget.userModel.jwt.getAccessToken();
      final response =
          await http.get(Uri.parse('$apiBaseUrl/api/get_offer/$id')
          ,headers: {'Authorization':'Bearer $claims'});
      if (response.statusCode == 200 || response.statusCode == 201) {
        final dynamic data = jsonDecode(response.body);
        final loadedRequest = OfferModel.fromJson(data);
        return loadedRequest;
      } else {
        return null;
      }
    } catch (e) {
      return null;
    }
  }


  void _applyFilters() {
    List<OfferModel> result = List.from(offers);

    final now = DateTime.now();
    switch (_selectedTimeFilter) {
      case TimeFilter.nextHour:
        final oneHourLater = now.add(const Duration(hours: 1));
        result = result.where((offer) => 
          offer.start_time.isAfter(now) && offer.start_time.isBefore(oneHourLater)
        ).toList();
        break;
      case TimeFilter.nextThreeHours:
        final threeHoursLater = now.add(const Duration(hours: 3));
        result = result.where((offer) => 
          offer.start_time.isAfter(now) && offer.start_time.isBefore(threeHoursLater)
        ).toList();
        break;
      case TimeFilter.today:
        final todayStart = DateTime(now.year, now.month, now.day);
        final tomorrowStart = todayStart.add(const Duration(days: 1));
        result = result.where((offer) => 
          offer.start_time.isAfter(todayStart) && offer.start_time.isBefore(tomorrowStart)
        ).toList();
        break;
      case TimeFilter.tomorrow:
        final tomorrow = now.add(const Duration(days: 1));
        final tomorrowStart = DateTime(tomorrow.year, tomorrow.month, tomorrow.day);
        final dayAfterTomorrow = tomorrowStart.add(const Duration(days: 1));
        result = result.where((offer) => 
          offer.start_time.isAfter(tomorrowStart) && offer.start_time.isBefore(dayAfterTomorrow)
        ).toList();
        break;
      case TimeFilter.all:
        // No time filtering
        break;
    }

    // Apply location filters
    if (_startLocationFilter.isNotEmpty) {
      result = result.where((offer) {
        final startName = _getCachedPlaceName(offer.start);
        return startName.toLowerCase().contains(_startLocationFilter.toLowerCase());
      }).toList();
    }

    if (_destinationFilter.isNotEmpty) {
      result = result.where((offer) {
        final destName = _getCachedPlaceName(offer.destination);
        return destName.toLowerCase().contains(_destinationFilter.toLowerCase());
      }).toList();
    }

    setState(() {
      filteredOffers = result;
    });
  }

  // Cache for place names to avoid repeated API calls during filtering
  final Map<String, String> _placeNameCache = {};

  String _getCachedPlaceName(LatLng location) {
    final key = '${location.latitude},${location.longitude}';
    return _placeNameCache[key] ?? 'Loading...';
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Filter Offers'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Time Filter
                  _buildTimeFilterSection(setDialogState),
                  const SizedBox(height: 20),
                  
                  // Start Location Filter
                  _buildStartLocationFilterSection(),
                  const SizedBox(height: 16),
                  
                  // Destination Filter
                  _buildDestinationFilterSection(),
                  const SizedBox(height: 16),
                  
                  // Active Filters Summary
                  _buildActiveFiltersSummary(),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  _clearFilters();
                  Navigator.pop(context);
                },
                child: Text('${AppLocalizations.of(context).clear}'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: Text('${AppLocalizations.of(context).cancel}'),
              ),
              ElevatedButton(
                onPressed: () {
                  _applyFilters();
                  Navigator.pop(context);
                },
                child: Text('${AppLocalizations.of(context).apply}'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTimeFilterSection(void Function(void Function()) setDialogState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${AppLocalizations.of(context).time}',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: TimeFilter.values.map((filter) {
            return FilterChip(
              label: Text(_getTimeFilterLabel(filter)),
              selected: _selectedTimeFilter == filter,
              onSelected: (selected) {
                setDialogState(() {
                  _selectedTimeFilter = selected ? filter : TimeFilter.all;
                });
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildStartLocationFilterSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${AppLocalizations.of(context).from}',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _startLocationController,
          decoration: InputDecoration(
            hintText: '${AppLocalizations.of(context).from}',
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
          onChanged: (value) {
            _startLocationFilter = value;
          },
        ),
      ],
    );
  }

  Widget _buildDestinationFilterSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${AppLocalizations.of(context).to}',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _destinationController,
          decoration: InputDecoration(
            hintText: '${AppLocalizations.of(context).to}',
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
          onChanged: (value) {
            _destinationFilter = value;
          },
        ),
      ],
    );
  }

  Widget _buildActiveFiltersSummary() {
    final activeFilters = <String>[];
    
    if (_selectedTimeFilter != TimeFilter.all) {
      activeFilters.add(_getTimeFilterLabel(_selectedTimeFilter));
    }
    if (_startLocationFilter.isNotEmpty) {
      activeFilters.add('${AppLocalizations.of(context).from}: $_startLocationFilter');
    }
    if (_destinationFilter.isNotEmpty) {
      activeFilters.add('${AppLocalizations.of(context).to}: $_destinationFilter');
    }

    if (activeFilters.isEmpty) {
      return const SizedBox();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${AppLocalizations.of(context).filter}',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: activeFilters.map((filter) => Chip(
            label: Text(filter),
            onDeleted: () {
              if (filter.startsWith('From:')) {
                _startLocationFilter = '';
                _startLocationController.clear();
              } else if (filter.startsWith('To:')) {
                _destinationFilter = '';
                _destinationController.clear();
              } else {
                _selectedTimeFilter = TimeFilter.all;
              }
              _applyFilters();
            },
          )).toList(),
        ),
      ],
    );
  }

  String _getTimeFilterLabel(TimeFilter filter) {
    switch (filter) {
      case TimeFilter.all:
        return '${AppLocalizations.of(context).allTimes}';
      case TimeFilter.nextHour:
        return '${AppLocalizations.of(context).nextHour}';
      case TimeFilter.nextThreeHours:
        return '${AppLocalizations.of(context).next3Hour}';
      case TimeFilter.today:
        return '${AppLocalizations.of(context).today}';
      case TimeFilter.tomorrow:
        return '${AppLocalizations.of(context).tomorrow}';
    }
  }

  void _clearFilters() {
    setState(() {
      _selectedTimeFilter = TimeFilter.all;
      _startLocationFilter = '';
      _destinationFilter = '';
      _startLocationController.clear();
      _destinationController.clear();
      filteredOffers = offers;
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _offerService.disconnect();
    _startLocationController.dispose();
    _destinationController.dispose();
    super.dispose();
  }

  Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(
      title:  Text("${AppLocalizations.of(context).available} ${AppLocalizations.of(context).offers}"),
      leading: Stack(
        children: [
          // Filter button on left top corner
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterDialog,
          ),
          if (_hasActiveFilters)
            Positioned(
              right: 8,
              top: 8,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                constraints: const BoxConstraints(
                  minWidth: 16,
                  minHeight: 16,
                ),
                child: Text(
                  _activeFilterCount.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
    ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : error != null
              ? Center(child: Text(error!))
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${filteredOffers.length} offer${filteredOffers.length == 1 ? '' : 's'} found',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.grey,
                            ),
                          ),
                          if (_hasActiveFilters)
                            TextButton(
                              onPressed: _clearFilters,
                              child:  Text('${AppLocalizations.of(context).clear}'),
                            ),
                        ],
                      ),
                    ),
                    
                    Expanded(
                      child: filteredOffers.isEmpty
                          ?  Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.search_off, size: 64, color: Colors.grey),
                                  SizedBox(height: 16),
                                  Text(
                                    '${AppLocalizations.of(context).noOffer}',
                                    style: TextStyle(fontSize: 16, color: Colors.grey),
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    'Try adjusting your filters',
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              itemCount: filteredOffers.length,
                              itemBuilder: (context, index) {
                                final offer = filteredOffers[index];
                                return RideCard(
                                  offerModel: offer,
                                  isActive: offer.seat_available > 0,
                                  userModel: widget.userModel,
                                  onTap: () async {
                                    final check = await _checkAvailability(offer);
                                    
                                    if (check){
                                      Navigator.pop(context);
                                      Navigator.pushNamed(
                                        context,
                                        '/offers_details',
                                        arguments: offer,
                                      );
                                    } else {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text("Failed the offer's seats are already taken")),
                                      );
                                    }
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                ),
      endDrawer: DrawerMenu(userModel: widget.userModel),
    );
  }

  bool get _hasActiveFilters {
    return _selectedTimeFilter != TimeFilter.all ||
        _startLocationFilter.isNotEmpty ||
        _destinationFilter.isNotEmpty;
  }

  int get _activeFilterCount {
    int count = 0;
    if (_selectedTimeFilter != TimeFilter.all) count++;
    if (_startLocationFilter.isNotEmpty) count++;
    if (_destinationFilter.isNotEmpty) count++;
    return count;
  }

  //fn to check if the offer is available to reserve seats, then decreases the # of seats and grant access to the reservation page.
  Future<bool> _checkAvailability(OfferModel? offerModel) async {
    final String url = "$apiBaseUrl/api/check_and_decrease/${offerModel!.session_id}";
    try {
      final response = await http.patch
        (Uri.parse(url),
        headers: {"Authorization":"Bearer ${await widget.userModel.jwt.getAccessToken()}"}
      );
      if (response.statusCode==200) {
        return true;
      } else {
        return false;
      }
    } catch(e) {
      return false;
    }
  }

  //TODO: probably isn't needed here, check if there are probable errors that can happen after the trigger of the check and decrease.
  //if there are use this.
  Future<bool> increaseSeats(OfferModel? offerModel) async {
    final String url = "$apiBaseUrl/api/increase_seat/${offerModel!.session_id}";
    try {
      final response = await http.patch(Uri.parse(url),
        headers: {
          'Content-Type':'application/json',
          "Authorization":"Bearer ${await widget.userModel.jwt.getAccessToken()}"
        }
      );
      if (response.statusCode==200) {
        return true;
      } else {
        return false;
      }
    } catch(e) {
      return false;
    }
  }
}