import 'package:google_maps_flutter/google_maps_flutter.dart';

class Driver {
  final String id;
  final String model;
  final String number;
  final bool isAvailable;
  final LatLng location;

  Driver({
    required this.id,
    required this.model,
    required this.number,
    required this.isAvailable,
    required this.location,
  });

  factory Driver.fromJson(Map<String, dynamic> json) {
    return Driver(
        id: json['id'],
        model: json['model'],
        number: json['number'],
        isAvailable: json['is_available'],
        location: LatLng(json['latitude'], json['longitude']));
  }
}
