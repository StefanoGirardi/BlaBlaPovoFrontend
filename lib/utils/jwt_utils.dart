import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:multi_user_flutter_app/models/user_model.dart';
import 'dart:convert';

import 'package:multi_user_flutter_app/routes.dart';

class JwtAuthService {
  
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  
  static final JwtAuthService _instance = JwtAuthService._internal();
  factory JwtAuthService() => _instance;
  JwtAuthService._internal();

  Future<void> storeTokens(String accessToken) async {
    await _storage.write(key: 'access_token', value: accessToken);
  }

  Future<String?> getAccessToken() async {
    return await _storage.read(key: 'access_token');
  }

  Future<bool> isAuthenticated() async {
    final token = await getAccessToken();
    if (token == null) return false;
    final user_res = await getUserInfo(token);
    if (user_res == null) return false;
    return true;
  }

  Future<String?> getSamlLoginUrl() async {
    try {
      final response = await http.get(
        Uri.parse('$apiBaseUrl/api/login'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['redirect_url']; // URL for webview
      }
    } catch (e) {
      debugPrint('Error getting SAML login URL: $e');
    }
    return null;
  }

  Future<Map<String, dynamic>?> handleSamlCallback(Map<String, String> headers) async {
    try {
      debugPrint('Calling saml_handle with headers: $headers');
      
      final response = await http.get(
        Uri.parse('$apiBaseUrl/api/auth/saml_handle'),
        headers: headers,
      );

      debugPrint('SAML handle response: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        // Handle both array and object response formats
        if (data is List && data.length >= 2) {
          // Your format: [userData, {access_token: ...}]
          final userData = data[0];
          final tokenData = data[1];
          final accessToken = tokenData['access_token'] as String;
          
          await storeTokens(accessToken);
          
          return {
            'user': User.fromJson(userData),
            'token': accessToken,
          };
        } else if (data is Map) {
          // Alternative format: {user: {...}, access_token: ...}
          final userData = data['user'];
          final accessToken = data['access_token'] as String;
          
          await storeTokens(accessToken);
          
          return {
            'user': User.fromJson(userData),
            'token': accessToken,
          };
        }
      } else {
        debugPrint('SAML handle failed: ${response.body}');
      }
    } catch (e) {
      debugPrint('Error handling SAML callback: $e');
    }
    return null;
  }
  
  Future<void> logout() async {
    await _storage.delete(key: 'access_token');
  }

  bool _isTokenExpired(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return true;
      
      final payload = parts[1];
      // Add padding if needed
      String paddedPayload = payload.padRight((payload.length + 3) ~/ 4 * 4, '=');
      final decoded = utf8.decode(base64Url.decode(paddedPayload));
      final payloadMap = json.decode(decoded);
      
      final exp = payloadMap['exp'] as int;
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      
      return exp < now;
    } catch (e) {
      return true;
    }
  }

  Future<User?> getUserInfo(String token) async {
  final String url = '$apiBaseUrl/api/get_user_info';

  try {
    final response = await http.get(
      Uri.parse(url),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = json.decode(response.body);
      return User.fromJson(data);
    } else {
      return null;
    }
  } catch (e) {
    return null; 
  }
}
}