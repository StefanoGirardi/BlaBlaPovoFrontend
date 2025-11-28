import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:multi_user_flutter_app/models/request_model.dart';
import 'package:multi_user_flutter_app/pages/active_offers.dart';
import 'package:multi_user_flutter_app/routes.dart';

class SSEService<T> {
  final String url;
  StreamController<T>? _controller;
  http.Client? _client;
  bool _isConnected = false;

  SSEService(this.url);

  Stream<T> connect(T Function(Map<String, dynamic>) fromJson) {
    _controller = StreamController<T>();
    _client = http.Client();
    _isConnected = true;

    _listen(fromJson);
    return _controller!.stream;
  }

  void _listen(T Function(Map<String, dynamic>) fromJson) async {
    try {
      final request = http.Request('GET', Uri.parse(url));
      request.headers['Accept'] = 'text/event-stream';
      request.headers['Cache-Control'] = 'no-cache';

      final response = await _client!.send(request);
      final stream = response.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter());

      await for (final line in stream) {
        if (!_isConnected) break;
        
        if (line.startsWith('data: ')) {
          final jsonStr = line.substring(6);
          if (jsonStr.trim().isNotEmpty && !jsonStr.contains('"status"')) {
            try {
              final jsonMap = jsonDecode(jsonStr) as Map<String, dynamic>;
              final item = fromJson(jsonMap);
              _controller!.add(item);
            } catch (e) {
              print('Error parsing SSE data: $e, data: $jsonStr');
            }
          }
        }
      }
    } catch (e) {
      if (_isConnected) {
        print('SSE connection error: $e');
        _controller!.addError(e);
      }
    } finally {
      if (_isConnected) {
        disconnect();
      }
    }
  }

  void disconnect() {
    _isConnected = false;
    _client?.close();
    _controller?.close();
    _client = null;
    _controller = null;
  }
}

class BroadcastResource {
  final String type;
  final int id;

  BroadcastResource._({required this.type, required this.id});

  factory BroadcastResource.fromJson(Map<String, dynamic> json) {
    if (json.containsKey('Modified')) {
      return BroadcastResource._(type: 'modified', id: json['Modified'] as int);
    } else if (json.containsKey('Deleted')) {
      return BroadcastResource._(type: 'deleted', id: json['Deleted'] as int);
    } else if (json.containsKey('Created')) {
      return BroadcastResource._(type: 'created', id: json['Created'] as int);
    }
    throw FormatException('Invalid BroadcastResource format: $json');
  }

  Map<String, dynamic> toJson() {
    switch (type) {
      case 'modified':
        return {'Modified': id};
      case 'deleted':
        return {'Deleted': id};
      case 'created':
        return {'Created': id};
      default:
        throw StateError('Unknown type: $type');
    }
  }
}

class OfferService {
  final SSEService<BroadcastResource> _sse =
      SSEService("$apiBaseUrl/api/sse/offers"); // Note: http not ws

  Stream<BroadcastResource> connect() {
    return _sse.connect((json) => BroadcastResource.fromJson(json));
  }

  void disconnect() => _sse.disconnect();
}

class RequestService {
  final SSEService<BroadcastResource> _sse =
      SSEService("$apiBaseUrl/api/sse/requests"); // Note: http not ws

  Stream<BroadcastResource> connect() {
    return _sse.connect((json) => BroadcastResource.fromJson(json));
  }

  void disconnect() => _sse.disconnect();
}