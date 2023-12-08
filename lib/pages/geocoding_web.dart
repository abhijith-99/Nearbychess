import 'dart:convert';
import 'package:http/http.dart' as http;

Future<String> getPlaceFromCoordinates(double latitude, double longitude) async {
  var url = Uri.parse('https://api.opencagedata.com/geocode/v1/json?q=$latitude+$longitude&key=e8c9f5423a8d4089af7af3ece5b1d0b3');
  var response = await http.get(url);

  if (response.statusCode == 200) {
    var jsonResponse = json.decode(response.body);

    // Check if results are available
    if (jsonResponse['results'] != null && jsonResponse['results'].isNotEmpty) {
      var firstResult = jsonResponse['results'][0];

      // Extracting location name
      String locationName = firstResult['formatted'] ?? 'Unknown Location';
      return locationName;
    } else {
      throw Exception('No results found');
    }
  } else {
    throw Exception('Failed to load location data');
  }
}
