// Page used to show the current active requests.
// Same construction as the active_offers page
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:multi_user_flutter_app/l10n/app_localizations.dart';
import 'package:multi_user_flutter_app/models/user_model.dart';
import 'package:multi_user_flutter_app/models/request_model.dart';
import 'package:multi_user_flutter_app/routes.dart';
import 'package:multi_user_flutter_app/utils/sse_utils.dart';
import 'package:multi_user_flutter_app/widgets/drawer_menu.dart';

class RideCard extends StatefulWidget {
  final RequestModel requestModel;
  final UserModel userModel;
  final bool isActive; //for the animation of the green dot
  final VoidCallback onTap;

  const RideCard({
    super.key,
    required this.requestModel,
    required this.userModel,
    required this.isActive,
    required this.onTap,
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
    setName();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  
  Future<void> setName() async {
    String? name = await getUsername(widget.requestModel.passenger_id, (await widget.userModel.jwt.getAccessToken())!);
    setState(() {
      passenger_name = name ?? "Unknown";
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
            // Left column
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("${AppLocalizations.of(context).name}: $passenger_name"),
                  const SizedBox(height: 8),
                  Text("${AppLocalizations.of(context).from}: $startName"),
                  const SizedBox(height: 8),
                  Text("${AppLocalizations.of(context).to}: $destinationName"),
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
                  Text("${AppLocalizations.of(context).time}: ${_formatDateTime(widget.requestModel.startTime)}"),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  String _formatDateTime(dynamic dateTime) {
    if (dateTime is String) {
      return dateTime;
    } else if (dateTime is DateTime) {
      return '${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
    }
    return dateTime.toString();
  }
}

enum TimeFilter {
  all,
  nextHour,
  nextThreeHours,
  today,
  tomorrow,
}

class RequestsPage extends StatefulWidget {
  final UserModel userModel;

  const RequestsPage({
    super.key,
    required this.userModel,
  });

  @override
  State<RequestsPage> createState() => _RequestsPageState();
}

class _RequestsPageState extends State<RequestsPage> {
  List<RequestModel> requests = [];
  List<RequestModel> filteredRequests = [];
  late RequestService _requestService;
  StreamSubscription<BroadcastResource>? _subscription;

  // Filter states
  TimeFilter _selectedTimeFilter = TimeFilter.all;
  String _startLocationFilter = '';
  String _destinationFilter = '';
  final TextEditingController _startLocationController = TextEditingController();
  final TextEditingController _destinationController = TextEditingController();

  bool isLoading = true;
  String? error;

  // Timer for 2-minute auto-resign
  Timer? _autoResignTimer;
  int? _currentAssignedSessionId;

  // Cache for place names to avoid repeated API calls during filtering
  final Map<String, String> _placeNameCache = {};

  @override
  void initState() {
    super.initState();
    _requestService = RequestService();

    // Load initial HTTP requests
    _loadInitialRequests();

    // Listen for live SSE updates
    _setupSSEListener();
  }

  void _setupSSEListener() async {
    _subscription = _requestService.connect().listen((updatedRequest) async {
      final req = (await getRequest(updatedRequest.id));
      if (!mounted) return;
      setState(() {
        final index = requests.indexWhere(
          (r) => r.session_id == updatedRequest.id,
        );
        if (updatedRequest.type=="Modified") {
          if (index >= 0) {
            requests[index] = req!;
          } 
        }
        if (updatedRequest.type=="Created") {
          requests.add(req!);
        }
        if (updatedRequest.type=="Deleted") {
          if (index >= 0) {
            requests.removeAt(index);
          } 
        }
        _applyFilters(); 
      });
    }, onError: (error) {
      print('SSE Error: $error');
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _requestService.disconnect();
    _startLocationController.dispose();
    _destinationController.dispose();
    _autoResignTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadInitialRequests() async {
    try {
      final id = widget.userModel.currentUser!.id;
      final claims = await widget.userModel.jwt.getAccessToken();
      final response = await http.get(
        Uri.parse('$apiBaseUrl/api/get_all_requests/$id'),
        headers: {'Authorization':'Bearer $claims'}
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final List<dynamic> data = jsonDecode(response.body);
        final loadedRequests = data.map((jsonItem) => RequestModel.fromJson(jsonItem)).toList();

        setState(() {
          requests = loadedRequests;
          filteredRequests = List.from(requests);
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
        error = "Error fetching requests: $e";
        isLoading = false;
      });
    }
  }

  Future<RequestModel?> getRequest(int id) async {
    try {
      final claims = await widget.userModel.jwt.getAccessToken();
      final response = await http.get(
        Uri.parse('$apiBaseUrl/api/get_request_on_id/$id'),
        headers: {'Authorization':'Bearer $claims'}
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final dynamic data = jsonDecode(response.body);
        final loadedRequest = RequestModel.fromJson(data);
        return loadedRequest;
      } else {
        return null;
      }
    } catch (e) {
      return null;
    }
  }

  // Start the 2-minute auto-resign timer
  void _startAutoResignTimer(int sessionId) {
    _currentAssignedSessionId = sessionId;
    _autoResignTimer?.cancel();
    _autoResignTimer = Timer(const Duration(minutes: 2), () async {
      print('2-minute timer expired, auto-resigning from request $sessionId');
      await resignDriver(sessionId);
      _currentAssignedSessionId = null;
    });
  }

  // Cancel the auto-resign timer (when user confirms the request)
  void _cancelAutoResignTimer() {
    _autoResignTimer?.cancel();
    _autoResignTimer = null;
    _currentAssignedSessionId = null;
  }

  Future<bool> assignDriver(int sessionId) async {
    final String url = "$apiBaseUrl/api/check_and_assign_driver/$sessionId";
    try {
      final response = await http.patch(
        Uri.parse(url),
        headers: {
          "Authorization": "Bearer ${await widget.userModel.jwt.getAccessToken()}"
        },
      );

      if (response.statusCode == 200) {
        // Start the 2-minute timer when assignment is successful
        _startAutoResignTimer(sessionId);
        return true;
      } else {
        print('Failed to assign driver: ${response.statusCode} - ${response.body}');
        return false;
      }
    } catch (e) {
      print('Error assigning driver: $e');
      return false;
    }
  }

  Future<bool> resignDriver(int sessionId) async {
    final String url = "$apiBaseUrl/api/resign_driver/$sessionId";
    try {
      final response = await http.patch(
        Uri.parse(url),
        headers: {
          "Authorization": "Bearer ${await widget.userModel.jwt.getAccessToken()}"
        },
      );

      if (response.statusCode == 200) {
        // Cancel timer when resigning manually
        if (sessionId == _currentAssignedSessionId) {
          _cancelAutoResignTimer();
        }
        return true;
      } else {
        print('Failed to resign driver: ${response.statusCode} - ${response.body}');
        return false;
      }
    } catch (e) {
      print('Error resigning driver: $e');
      return false;
    }
  }

// Handle page navigation with timer management
void _handleRequestTap(RequestModel request) async {
  final check = await assignDriver(request.session_id);
  if (check) {
    // Show confirmation dialog with timer
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => TimerConfirmationDialog(
        sessionId: request.session_id,
        onConfirm: () {
          _cancelAutoResignTimer(); // Cancel timer when confirmed
          Navigator.pop(context, true);
        },
        onCancel: () async {
          await resignDriver(request.session_id); // Resign when canceled
          Navigator.pop(context, false);
        },
      ),
    );

    if (confirmed == true && mounted) {
      // Use regular push instead of pushReplacement
      Navigator.pushNamed(
        context,
        '/request_details',
        arguments: request,
      );
    } else if (confirmed == false && mounted) {
      // Show message if user canceled
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Request assignment canceled")),
      );
    }
  } else {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to assign driver to this request")),
      );
    }
  }
}

  void _applyFilters() {
    List<RequestModel> result = List.from(requests);

    // Apply time filter
    final now = DateTime.now();
    switch (_selectedTimeFilter) {
      case TimeFilter.nextHour:
        final oneHourLater = now.add(const Duration(hours: 1));
        result = result.where((request) => 
          _parseTime(request.startTime).isAfter(now) && 
          _parseTime(request.startTime).isBefore(oneHourLater)
        ).toList();
        break;
      case TimeFilter.nextThreeHours:
        final threeHoursLater = now.add(const Duration(hours: 3));
        result = result.where((request) => 
          _parseTime(request.startTime).isAfter(now) && 
          _parseTime(request.startTime).isBefore(threeHoursLater)
        ).toList();
        break;
      case TimeFilter.today:
        final todayStart = DateTime(now.year, now.month, now.day);
        final tomorrowStart = todayStart.add(const Duration(days: 1));
        result = result.where((request) => 
          _parseTime(request.startTime).isAfter(todayStart) && 
          _parseTime(request.startTime).isBefore(tomorrowStart)
        ).toList();
        break;
      case TimeFilter.tomorrow:
        final tomorrow = now.add(const Duration(days: 1));
        final tomorrowStart = DateTime(tomorrow.year, tomorrow.month, tomorrow.day);
        final dayAfterTomorrow = tomorrowStart.add(const Duration(days: 1));
        result = result.where((request) => 
          _parseTime(request.startTime).isAfter(tomorrowStart) && 
          _parseTime(request.startTime).isBefore(dayAfterTomorrow)
        ).toList();
        break;
      case TimeFilter.all:
        // No time filtering
        break;
    }

    // Apply location filters
    if (_startLocationFilter.isNotEmpty) {
      result = result.where((request) {
        final startName = _getCachedPlaceName(request.start);
        return startName.toLowerCase().contains(_startLocationFilter.toLowerCase());
      }).toList();
    }

    if (_destinationFilter.isNotEmpty) {
      result = result.where((request) {
        final destName = _getCachedPlaceName(request.arrival);
        return destName.toLowerCase().contains(_destinationFilter.toLowerCase());
      }).toList();
    }

    setState(() {
      filteredRequests = result;
    });
  }

  DateTime _parseTime(dynamic timeValue) {
    if (timeValue is DateTime) {
      return timeValue;
    } else if (timeValue is String) {
      try {
        final timeParts = timeValue.split(':');
        if (timeParts.length >= 2) {
          final now = DateTime.now();
          return DateTime(now.year, now.month, now.day, 
            int.parse(timeParts[0]), int.parse(timeParts[1]));
        }
      } catch (e) {
        print('Error parsing time string: $timeValue, error: $e');
      }
    }
    return DateTime.now();
  }

  String _getCachedPlaceName(dynamic location) {
    if (location is LatLng) {
      final key = '${location.latitude},${location.longitude}';
      return _placeNameCache[key] ?? 'Loading...';
    } else if (location is String) {
      return location;
    }
    return location.toString();
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text('${AppLocalizations.of(context).filter}'),
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
          '${AppLocalizations.of(context).filter}:',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: activeFilters.map((filter) => Chip(
            label: Text(filter),
            onDeleted: () {
              if (filter.startsWith('${AppLocalizations.of(context).from}:')) {
                _startLocationFilter = '';
                _startLocationController.clear();
              } else if (filter.startsWith('${AppLocalizations.of(context).to}:')) {
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
      filteredRequests = List.from(requests);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("${AppLocalizations.of(context).available} ${AppLocalizations.of(context).requests}"),
        leading: Stack(
          children: [
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
                            '${filteredRequests.length} request${filteredRequests.length == 1 ? '' : 's'} found',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.grey,
                            ),
                          ),
                          if (_hasActiveFilters)
                            TextButton(
                              onPressed: _clearFilters,
                              child: Text('${AppLocalizations.of(context).clear}'),
                            ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: filteredRequests.isEmpty
                          ?  Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.search_off, size: 64, color: Colors.grey),
                                  SizedBox(height: 16),
                                  Text(
                                    '${AppLocalizations.of(context).noRequest}',
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
                              itemCount: filteredRequests.length,
                              itemBuilder: (context, index) {
                                final request = filteredRequests[index];
                                return RideCard(
                                  requestModel: request,
                                  userModel: widget.userModel,
                                  isActive: true,
                                  onTap: () => _handleRequestTap(request),
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
}

// Timer Confirmation Dialog Widget
class TimerConfirmationDialog extends StatefulWidget {
  final int sessionId;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  const TimerConfirmationDialog({
    super.key,
    required this.sessionId,
    required this.onConfirm,
    required this.onCancel,
  });

  @override
  State<TimerConfirmationDialog> createState() => _TimerConfirmationDialogState();
}

class _TimerConfirmationDialogState extends State<TimerConfirmationDialog> {
  late Timer _countdownTimer;
  int _secondsRemaining = 120; // 2 minutes in seconds
  bool _isDialogOpen = true;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  @override
  void dispose() {
    _countdownTimer.cancel();
    _isDialogOpen = false;
    super.dispose();
  }

  void _startCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 0 && _isDialogOpen) {
        setState(() {
          _secondsRemaining--;
        });
      } else {
        timer.cancel();
        // Auto-cancel when time runs out
        if (_isDialogOpen && mounted) {
          widget.onCancel();
          Navigator.pop(context);
        }
      }
    });
  }

  String _formatTime(int seconds) {
    final minutes = (seconds ~/ 60).toString().padLeft(2, '0');
    final remainingSeconds = (seconds % 60).toString().padLeft(2, '0');
    return '$minutes:$remainingSeconds';
  }

  void _handleConfirm() {
    _countdownTimer.cancel();
    _isDialogOpen = false;
    widget.onConfirm();
    if (mounted) {
      Navigator.pop(context, true);
    }
  }

  void _handleCancel() {
    _countdownTimer.cancel();
    _isDialogOpen = false;
    widget.onCancel();
    if (mounted) {
      Navigator.pop(context, false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Confirm Request Assignment"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text("You have been assigned to this request."),
          const SizedBox(height: 8),
          const Text("Please confirm within:"),
          const SizedBox(height: 8),
          Text(
            _formatTime(_secondsRemaining),
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: _secondsRemaining <= 30 ? Colors.red : Colors.green,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            "If you don't confirm in time, you will be automatically unassigned.",
            style: TextStyle(fontSize: 12, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _handleCancel,
          child: Text("${AppLocalizations.of(context).cancel}"),
        ),
        ElevatedButton(
          onPressed: _handleConfirm,
          child: const Text("Confirm"),
        ),
      ],
    );
  }
}