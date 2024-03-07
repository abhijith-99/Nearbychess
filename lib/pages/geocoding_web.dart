import 'dart:convert';
import 'package:http/http.dart' as http;


Future<String> getPlaceFromCoordinates(double latitude, double longitude) async {
  var url = Uri.parse('https://api.opencagedata.com/geocode/v1/json?q=$latitude+$longitude&key=e8c9f5423a8d4089af7af3ece5b1d0b3');
  var response = await http.get(url);

  if (response.statusCode == 200) {
    var jsonResponse = json.decode(response.body);

    if (jsonResponse['results'] != null && jsonResponse['results'].isNotEmpty) {
      var components = jsonResponse['results'][0]['components'];
      // Prioritize 'suburb' or similar fields that might contain specific location names like 'Kakkanad'
      String specificLocation = components['suburb'] ?? components['neighbourhood'] ?? components['town'] ?? components['city'] ?? components['village'] ?? 'Unknown Location';

      String userLocation = specificLocation.split(" ")[0];
      // String userLocation = components['suburb'] ?? components['neighbourhood'] ?? components['town'] ?? components['city'] ?? components['village'] ?? 'Unknown Location';

      return userLocation;
    } else {
      throw Exception('No results found');
    }
  } else {
    throw Exception('Failed to load location data');
  }
}

