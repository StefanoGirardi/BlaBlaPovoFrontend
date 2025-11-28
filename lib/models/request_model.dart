import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:multi_user_flutter_app/models/request_model.dart';
import 'package:multi_user_flutter_app/models/user_model.dart';
import 'package:multi_user_flutter_app/pages/active_offers.dart';
import 'package:multi_user_flutter_app/routes.dart';
import 'package:multi_user_flutter_app/widgets/drawer_menu.dart';

class RequestModel  {
  final int session_id;
  final int passenger_id;
  int ? driver_id;
  final LatLng start;
  final LatLng arrival;
  List<LatLng>? route;
  final DateTime startTime;
  LatLng? driver_start;
  LatLng? driver_arrival;

  RequestModel({
    required this.session_id,
    required this.passenger_id,
    this.driver_id,
    this.route,
    required this.start,
    required this.arrival,
    required this.startTime,
    this.driver_start,
    this.driver_arrival,
  });

  Map<String, dynamic> toJson() {
    return {
      "session_id": session_id,
      "passenger_id": passenger_id,
      "driver_id": driver_id,
      "start": {
        "lat": start.latitude,
        "lng": start.longitude, // use "lng" if your backend expects that
      },
      "arrival": {
        "lat": arrival.latitude,
        "lng": arrival.longitude,
      },
      "start_time": startTime.toUtc().toIso8601String(),
    };
  }

  factory RequestModel.fromJson(Map<String, dynamic> json) {
    return RequestModel(
      session_id: json["session_id"] as int,
      passenger_id: json["passenger_id"] as int,
      driver_id: json["drivers_id"] as int?, 
      route: (json['route']?['route'] as List<dynamic>?)
              ?.map((point) => LatLng(
                    (point['lat'] as num).toDouble(),
                    (point['lng'] as num).toDouble(),
                  ))
              .toList() ??
          [], // fallback to empty list
      start: LatLng(
        (json["start"]["lat"] as num).toDouble(),
        (json["start"]["lng"] as num).toDouble(),
      ),
      arrival: LatLng(
        (json["arrival"]["lat"] as num).toDouble(),
        (json["arrival"]["lng"] as num).toDouble(),
      ),
      startTime: DateTime.parse(json["start_time"] as String),
      driver_start: json["driver_start"] != null ? LatLng(
        (json["driver_start"]!["lat"] as num).toDouble(),
        (json["driver_start"]!["lng"] as num).toDouble(),
      ) : null,
      driver_arrival: json["driver_arrival"] != null ? LatLng(
        (json["driver_arrival"]!["lat"] as num).toDouble(),
        (json["driver_arrival"]!["lng"] as num).toDouble(),
      ) : null,
    );
  }

  RequestModel copyWith({
    int? session_id,
    int? passenger_id,
    int? driver_id,
    LatLng? start,
    LatLng? arrival,
    LatLng? driver_start,
    LatLng? driver_arrival,
    DateTime? startTime,
    List<LatLng>? route,
  }) {
    return RequestModel(
      session_id: session_id ?? this.session_id,
      passenger_id: passenger_id ?? this.passenger_id,
      driver_id: driver_id ?? this.driver_id,
      start: start ?? this.start,
      arrival: arrival ?? this.arrival,
      driver_start: driver_start ?? this.driver_start,
      driver_arrival: driver_arrival ?? this.driver_arrival,
      startTime: startTime ?? this.startTime,
      route: route ?? this.route,
    );
  }


}
