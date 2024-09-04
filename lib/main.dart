import 'dart:async';
import 'dart:math';

import 'package:duration/duration.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uberclone/models/driver.dart';

void main() async {
  Supabase.initialize(
      url: 'https://xXx.supabase.co',
      anonKey: 'xXx');
  runApp(const MaterialApp(
    home: MyApp(),
  ));
}

enum AppState { selecting, confirm, waiting, riding, finish }

final supabase = Supabase.instance.client;

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  AppState _appState = AppState.selecting;
  LatLng? _currentLocation;
  LatLng? _selectedDestination;
  CameraPosition? _initialPosition;
  late GoogleMapController _mapController;
  final Set<Polyline> _polylines = {};
  final Set<Marker> _markers = {};
  BitmapDescriptor? _carIcon;
  late int _fare;
  StreamSubscription? _driverSubscription;
  StreamSubscription? _rideSubscription;
  Driver? _driver;
  LatLng? _previousDriverPosition;

  @override
  void initState() {
    super.initState();
    _signInUser();
    _checkLocationPermission();
    _loadIcons();
  }

  Future<void> _checkLocationPermission() async {
    final isEnabled = await Geolocator.isLocationServiceEnabled();
    if (!isEnabled) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Please enable GPS')));
        return;
      }
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('Please enable GPS')));
          return;
        }
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Please enable GPS')));
        return;
      }
    }

    final position = await Geolocator.getCurrentPosition();
    setState(() {
      _currentLocation = LatLng(position.latitude, position.longitude);
      _initialPosition = CameraPosition(target: _currentLocation!, zoom: 14);
    });

    _mapController
        .animateCamera(CameraUpdate.newCameraPosition(_initialPosition!));
  }

  void _goToNextState() {
    setState(() {
      if (_appState == AppState.finish) {
        _appState = AppState.selecting;
      } else {
        _appState = AppState.values[_appState.index + 1];
      }
    });
  }

  void _updateDriverMarker(Driver driver) {
    setState(() {
      _markers.removeWhere((marker) => marker.markerId.value == 'driver');

      double rotation = 0;
      if (_previousDriverPosition != null) {
        rotation =
            _calculateRotation(_previousDriverPosition!, driver.location);
      }

      _markers.add(Marker(
          markerId: const MarkerId('driver'),
          position: driver.location,
          icon: _carIcon!,
          rotation: rotation));

      _previousDriverPosition = driver.location;
    });
  }

  double _calculateRotation(LatLng start, LatLng end) {
    double latDiff = end.latitude - start.latitude;
    double lngDiff = end.longitude - start.longitude;
    double angle = atan2(lngDiff, latDiff);
    return angle * 180 / pi;
  }

  Future<void> _signInUser() async {
    if (supabase.auth.currentSession == null) {
      await supabase.auth.signInAnonymously();
    }
  }

  Future<void> _loadIcons() async {
    const conf = ImageConfiguration(size: Size(48, 48));
    _carIcon = await BitmapDescriptor.asset(conf, 'lib/images/car.png');
  }

  void _adjustMapView({required LatLng target}) {
    final southwest = LatLng(min(_driver!.location.latitude, target.latitude),
        min(_driver!.location.longitude, target.longitude));

    final northeast = LatLng(max(_driver!.location.latitude, target.latitude),
        max(_driver!.location.longitude, target.longitude));

    final bounds = LatLngBounds(southwest: southwest, northeast: northeast);
    _mapController.animateCamera(CameraUpdate.newLatLngBounds(bounds, 50));
  }

  @override
  void dispose() {
    _driverSubscription?.cancel();
    _rideSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        home: Scaffold(
      body: Stack(children: [
        GoogleMap(
          markers: _markers,
          polylines: _polylines,
          myLocationEnabled: true,
          initialCameraPosition:
              CameraPosition(target: LatLng(37, -122), zoom: 14),
          onCameraMove: (position) {
            if (_appState == AppState.selecting) {
              _selectedDestination = position.target;
            }
          },
          onMapCreated: (controller) {
            _mapController = controller;
          },
        ),
        if (_appState == AppState.selecting)
          const Center(
            child: Icon(Icons.location_pin, color: Colors.red, size: 50),
          )
      ]),
      bottomSheet: (_appState == AppState.confirm ||
              _appState == AppState.waiting)
          ? Container(
              width: MediaQuery.of(context).size.width,
              padding: EdgeInsets.all(16)
                  .copyWith(bottom: MediaQuery.of(context).padding.bottom),
              decoration: BoxDecoration(color: Colors.white),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_appState == AppState.confirm) ...[
                    Text('Confirm Fare',
                        style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 16),
                    Text(
                        'Estimated fare: ${NumberFormat.currency(symbol: '\$', decimalDigits: 2).format(_fare / 100)}'),
                    ElevatedButton(
                        onPressed: () async {
                          try {
                            final response =
                                await supabase.rpc('find_driver', params: {
                              'origin':
                                  'POINT(${_currentLocation!.longitude} ${_currentLocation!.latitude})',
                              'destination':
                                  'POINT(${_selectedDestination!.longitude} ${_selectedDestination!.latitude})',
                              'fare': _fare
                            }) as List<dynamic>;

                            if (response.isEmpty) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: Text(
                                            'No driver was found. Please try again later.')));
                              }
                            }
                            final driverId =
                                response.first['driver_id'] as String;
                            final rideId = response.first['ride_id'] as String;

                            _driverSubscription = supabase
                                .from('drivers')
                                .stream(primaryKey: ['id'])
                                .eq('id', driverId)
                                .listen((drivers) {
                                  // update the driver position
                                  _driver = Driver.fromJson(drivers.first);
                                  _updateDriverMarker(_driver!);
                                  _adjustMapView(
                                      target: _appState == AppState.waiting
                                          ? _currentLocation!
                                          : _selectedDestination!);
                                });

                            _rideSubscription = supabase
                                .from('rides')
                                .stream(primaryKey: ['id'])
                                .eq('id', rideId)
                                .listen((rides) {
                                  // update the app status
                                });

                            _goToNextState();
                          } catch (error) {
                            print(error);
                          }
                        },
                        child: const Text('Confirm'))
                  ],
                  if (_appState == AppState.waiting && _driver != null) ...[
                    Text('Your Driver',
                        style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 8),
                    Text('Car: ${_driver!.model}',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Text('Plate Number: ${_driver!.number}',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 16),
                    Text('Your driver is on the way.',
                        style: Theme.of(context).textTheme.bodyMedium)
                  ]
                ],
              ),
            )
          : const SizedBox.shrink(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: _appState == AppState.selecting
          ? FloatingActionButton.extended(
              onPressed: () async {
                final response =
                    await supabase.functions.invoke('routes', body: {
                  'origin': {
                    'latitude': _currentLocation!.latitude,
                    'longitude': _currentLocation!.longitude
                  },
                  'destination': {
                    'latitude': _selectedDestination!.latitude,
                    'longitude': _selectedDestination!.longitude,
                  }
                });
                final data = response.data as Map<String, dynamic>;
                final coordinates = data['legs'][0]['polyline']
                    ['geoJsonLinestring']['coordinates'] as List<dynamic>;
                final duration = parseDuration(data['duration'] as String);
                _fare = (duration.inMinutes * 40).ceil();
                final polylineCoordinates = coordinates.map((coordinates) {
                  return LatLng((coordinates[1]), coordinates[0]);
                }).toList();

                setState(() {
                  _polylines.add(Polyline(
                      polylineId: const PolylineId('route'),
                      points: polylineCoordinates,
                      color: Colors.black,
                      width: 5));

                  _markers.add(Marker(
                      markerId: const MarkerId('destination'),
                      position: _selectedDestination!,
                      icon: BitmapDescriptor.defaultMarker));

                  final southwest = LatLng(
                      polylineCoordinates
                          .map((e) => e.latitude)
                          .reduce((a, b) => a < b ? a : b),
                      polylineCoordinates
                          .map((e) => e.longitude)
                          .reduce((a, b) => a < b ? a : b));
                  final northeast = LatLng(
                      polylineCoordinates
                          .map((e) => e.latitude)
                          .reduce((a, b) => a > b ? a : b),
                      polylineCoordinates
                          .map((e) => e.longitude)
                          .reduce((a, b) => a > b ? a : b));
                  final bounds =
                      LatLngBounds(southwest: southwest, northeast: northeast);
                  _mapController
                      .animateCamera(CameraUpdate.newLatLngBounds(bounds, 50));

                  setState(() {
                    _goToNextState();
                  });
                });
              },
              label: const Text('Confirm Destination'))
          : const SizedBox.shrink(),
    ));
  }
}
