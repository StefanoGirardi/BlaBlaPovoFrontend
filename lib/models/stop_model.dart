import 'package:http/http.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:multi_user_flutter_app/routes.dart';

class Stop {
  final int id;
  final LatLng stop;

  Stop({required this.id, required this.stop});

  factory Stop.fromJson(Map<String, dynamic> json) {
    return Stop(
      id: json['id'] as int,
      stop: LatLng(
        (json['stop']['lat'] as num).toDouble(),
        (json['stop']['lng'] as num).toDouble(),
      ),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'stop': {
          'lat': stop.latitude,
          'lng': stop.longitude,
        },
      };

  Future<String?> getUsername(int id,String token) async {
    try {
      final url = '$apiBaseUrl/api/get_username/$id';
      final response = await http.get(
        Uri.parse(url),
        headers: {'Authorization':'Bearer $token'}
      );
      if (response.statusCode == 200) {
        return response.body.toString();
      } else {
        return null;
      }
    } catch(e){
      return null;
    }
  }
}
