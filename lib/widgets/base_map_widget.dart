// widgets/base_map_widget.dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class SafeMapController {
  final MapController controller = MapController();
  bool _isReady = false;
  final List<VoidCallback> _pendingActions = [];

  SafeMapController() {
    // Once the map is attached, mark as ready
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _isReady = true;
      for (final action in _pendingActions) {
        action();
      }
      _pendingActions.clear();
    });
  }

  void move(LatLng center, double zoom) {
    _runOrQueue(() => controller.move(center, zoom));
  }

  void fitCamera(CameraFit fit) {
    _runOrQueue(() => controller.fitCamera(fit));
  }

  LatLng get center => controller.camera.center;
  double get zoom => controller.camera.zoom;

  void _runOrQueue(VoidCallback action) {
    if (_isReady) {
      action();
    } else {
      _pendingActions.add(action);
    }
  }
}

class BaseMapWidget extends StatefulWidget {
  final SafeMapController? controller;
  final Function(TapPosition, LatLng)? onTap;
  final LatLng initialCenter;
  final double initialZoom;
  final LatLngBounds? boundsConstraint;
  final List<Widget> overlays;

  const BaseMapWidget({
    super.key,
    this.controller,
    this.onTap,
    this.initialCenter = const LatLng(46.0669, 11.1217),
    this.initialZoom = 14,
    this.boundsConstraint,
    this.overlays = const [],
  });

  @override
  State<BaseMapWidget> createState() => _BaseMapWidgetState();
}

class _BaseMapWidgetState extends State<BaseMapWidget> {
  late SafeMapController _safeController;

  @override
  void initState() {
    super.initState();
    _safeController = widget.controller ?? SafeMapController();
  }

  @override
  Widget build(BuildContext context) {
    return FlutterMap(
      mapController: _safeController.controller, // underlying controller
      options: MapOptions(
        initialCenter: widget.initialCenter,
        initialZoom: widget.initialZoom,
        onTap: widget.onTap,
        minZoom: 11,
        cameraConstraint: widget.boundsConstraint != null
            ? CameraConstraint.contain(bounds: widget.boundsConstraint!)
            : const CameraConstraint.unconstrained(),
      ),
      children: [
        TileLayer(
          urlTemplate: "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
          subdomains: const ['a', 'b', 'c'],
        ),
        ...widget.overlays,
      ],
    );
  }
}
