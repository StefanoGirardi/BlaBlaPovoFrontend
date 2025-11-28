import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:multi_user_flutter_app/utils/jwt_utils.dart';
import 'package:multi_user_flutter_app/widgets/map_widget.dart';

class User {
  final int id;
  final String name;
  final String surname;
  final String mail;
  String? username;
  String? telegram_username;
  final Map<String, dynamic>? starredRoutes;
  Map<String, dynamic>? auto;
  String token = "";

  User({
    required this.id,
    required this.name,
    required this.surname,
    required this.mail,
    this.username,
    this.telegram_username,
    this.starredRoutes,
    this.auto,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      name: json['name'],
      surname: json['surname'],
      mail: json['mail'],
      username: json['telegram_username'],
      telegram_username: json['telegram_username'],
      starredRoutes: json['starred_routes'],
      auto: json['auto'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'surname': surname,
      'mail': mail,
      'username': username,
      'telegram_username': telegram_username,
      'starred_routes': starredRoutes,
      'auto': auto,
    };
  }
}

class UserModel extends ChangeNotifier {
  User? currentUser;
  final String apiBaseUrl = 'http://localhost:8000';
  // static const String apiBaseUrl = 'https://mp.disi.unitn.it/blablaunitn'; 
  final JwtAuthService  jwt = JwtAuthService();

  Future<void> fetchUsers() async {
    try {
      final response = await http.get(Uri.parse('$apiBaseUrl/api/users'));
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        final users = data.map((u) => User.fromJson(u)).toList();
        currentUser = users.first;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error fetching users: \$e');
    }
  }

  Future<User?> fetchUserById(String id) async {
    try {
      final response = await http.get(Uri.parse('$apiBaseUrl/api/users/$id'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final user = User.fromJson(data[0]);
        user.token = (data[1]['access_token'] as String);
        jwt.storeTokens(user.token);
        return user;
      }
    } catch (e) {
      debugPrint('Error fetching user by ID: $e');
    }
    return null;
  }

  void login(User user) {
    currentUser = user;
    notifyListeners();
  }

  void logout() {
    currentUser = null;
    notifyListeners();
  }
}
