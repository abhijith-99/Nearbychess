// TODO Implement this library.
// TODO Implement this librar
import 'package:geocoding/geocoding.dart' as geocoding;
// import 'package:opencage_geocoder/opencage_geocoder.dart';

Future<String> getPlaceFromCoordinates(double latitude, double longitude) async {
  try {
    List<geocoding.Placemark> placemarks = await geocoding.placemarkFromCoordinates(latitude, longitude);

    if (placemarks.isNotEmpty) {
      geocoding.Placemark place = placemarks.first;
      String detailedLocationName = place.subLocality ?? place.locality ?? place.subAdministrativeArea ?? place.administrativeArea ?? 'Unknown Location';
      return detailedLocationName;

    }
    else {
      throw Exception('No results found');
    }
  } catch (e) {
    throw Exception('Failed to get placemark from coordinates: $e');
  }
}
