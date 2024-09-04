enum RideStatus {
  picking_up, riding, completed
}

class Ride {
  final String id;
  final String driverId;
  final String passengerId;
  final int fare;
  final RideStatus status;

  Ride({
    required this.id,
    required this.driverId,
    required this.passengerId,
    required this.fare,
    required this.status,
  });

  factory Ride.fromJson(Map<String, dynamic> json) {
    return Ride(
        id: json['id'],
        driverId: json['driver_id'],
        passengerId: json['passenger_id'],
        fare: json['fare'],
        status: RideStatus.values.firstWhere((e) => e.toString().split('.').last == json['status']));
  }
}
