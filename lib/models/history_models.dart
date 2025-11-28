import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:multi_user_flutter_app/models/stop_model.dart';
import 'package:multi_user_flutter_app/models/user_model.dart';
import 'package:multi_user_flutter_app/routes.dart';
import 'package:multi_user_flutter_app/widgets/drawer_menu.dart';

class RequestRideHistory {
  final int sessionId;
  final int driverId;
  final int passengerId;
  final Stop start;
  final Stop arrival;
  final Route route;
  final DateTime day;

  RequestRideHistory({
    required this.sessionId,
    required this.driverId,
    required this.passengerId,
    required this.start,
    required this.arrival,
    required this.route,
    required this.day,
  });

  factory RequestRideHistory.fromJson(Map<String, dynamic> json) {
    return RequestRideHistory(
      sessionId: json['session_id'] as int,
      driverId: json['driver_id'] as int,
      passengerId: json['passenger_id'] as int,
      start: Stop.fromJson(json['start']),
      arrival: Stop.fromJson(json['arrival']),
      route: Route.fromJson(json['route']),
      day: DateTime.parse(json['day'] as String).toLocal(),
    );
  }
}

class OfferRideHistory {
  final int sessionId;
  final int driverId;
  final List<int> passengerIds;
  final Stop start;
  final Stop arrival;
  final Route route;
  final List<Stop> stops;
  final DateTime day;

  OfferRideHistory({
    required this.sessionId,
    required this.driverId,
    required this.passengerIds,
    required this.start,
    required this.arrival,
    required this.route,
    required this.stops,
    required this.day,
  });

  factory OfferRideHistory.fromJson(Map<String, dynamic> json) {
    return OfferRideHistory(
      sessionId: json['session_id'] as int,
      driverId: json['driver_id'] as int,
      passengerIds: (json['passengers_id'] as List<dynamic>).cast<int>(),
      start: Stop.fromJson(json['start']),
      arrival: Stop.fromJson(json['arrival']),
      route: Route.fromJson(json['route']),
      stops: (json['stops'] as List<dynamic>)
          .map((stop) => Stop.fromJson(stop))
          .toList(),
      day: DateTime.parse(json['day'] as String).toLocal(),
    );
  }
}

class Route {
  final List<LatLng> route;

  Route({required this.route});

  factory Route.fromJson(Map<String, dynamic> json) {
    return Route(
      route: (json['route'] as List<dynamic>)
          .map((point) => LatLng(
                (point['lat'] as num).toDouble(),
                (point['lng'] as num).toDouble(),
              ))
          .toList(),
    );
  }
}