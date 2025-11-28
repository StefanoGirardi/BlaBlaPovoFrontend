import 'dart:convert';
import 'package:http/http.dart' as http;

class ChatRequest {
  final int initiatorId;
  final int targetId;
  final String? initiatorUsername;
  final String? targetUsername;
  final String token;

  ChatRequest({
    required this.initiatorId,
    required this.targetId,
    this.initiatorUsername,
    this.targetUsername,
    required this.token,
  });

  Map<String, dynamic> toJson() => {
    'initiator_id': initiatorId,
    'target_id': targetId,
    'initiator_username': initiatorUsername,
    'target_username': targetUsername,
    'token' : token,
  };
}

class ChatResponse {
  final bool success;
  final String message;
  final String? deepLink;

  ChatResponse({
    required this.success,
    required this.message,
    this.deepLink,
  });

  factory ChatResponse.fromJson(Map<String, dynamic> json) => ChatResponse(
    success: json['success'],
    message: json['message'],
    deepLink: json['deep_link'],
    
  );
}

class TelegramApiService {
  // static const String apiBaseUrl = 'https://mp.disi.unitn.it/blablaunitn';  
  static const String apiBaseUrl = 'http://localhost:8000';
  static Future<ChatResponse> initiateChat(ChatRequest request) async {
    final client = http.Client();
    try {
      final response = await client.post(
        Uri.parse('$apiBaseUrl/api/initiate_telegram_chat'),
        headers: {
          'Content-Type': 'application/json',
          "Authorization":"Bearer ${request.token}"
        },
        body: jsonEncode(request.toJson()),
      ).timeout(const Duration(seconds: 10)); // Add timeout here

      if (response.statusCode == 200) {
        return ChatResponse.fromJson(jsonDecode(response.body));
      } else {
        // Handle different HTTP status codes
        if (response.statusCode == 404) {
          throw Exception('API endpoint not found. Please check the server URL.');
        } else if (response.statusCode >= 500) {
          throw Exception('Server error: ${response.statusCode}');
        } else {
          throw Exception('Failed to initiate chat: ${response.statusCode}');
        }
      }
    } on http.ClientException catch (e) {
      throw Exception('Network error: $e');
    } on Exception catch (_e) {
      rethrow;
    } finally {
      client.close();
    }
  }

  // Optional: Add a method to check if backend is reachable
  static Future<bool> isBackendReachable() async {
    final client = http.Client();
    try {
      final response = await client.get(
        Uri.parse('$apiBaseUrl/api/telegram/status'),
      ).timeout(const Duration(seconds: 5)); // Add timeout here
      return response.statusCode == 200;
    } catch (e) {
      return false;
    } finally {
      client.close();
    }
  }
}