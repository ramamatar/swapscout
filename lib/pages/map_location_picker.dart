import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

class MapLocationPickerPage extends StatefulWidget {
  final LatLng? initialLocation;
  final String? addressQuery;

  const MapLocationPickerPage({super.key, this.initialLocation, this.addressQuery});

  @override
  State<MapLocationPickerPage> createState() => _MapLocationPickerPageState();
}

class _MapLocationPickerPageState extends State<MapLocationPickerPage> {
  GoogleMapController? _mapController;
  LatLng? _selectedLocation;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    if (widget.initialLocation != null) {
      _selectedLocation = widget.initialLocation;
      _isLoading = false;
    } else {
      _determinePosition();
    }
  }

  Future<void> _determinePosition() async {
    // If we have an address query string from the Add Home screen, try mapping it first
    if (widget.addressQuery != null && widget.addressQuery!.trim().isNotEmpty && widget.addressQuery!.trim() != ",") {
      try {
        List<Location> locations = await locationFromAddress(widget.addressQuery!);
        if (locations.isNotEmpty) {
          setState(() {
            _selectedLocation = LatLng(locations.first.latitude, locations.first.longitude);
            _isLoading = false;
          });
          return;
        }
      } catch (e) {
        // Fallthrough down to device position if geocoding failed
      }
    }
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        throw Exception('Location permissions are denied');
      }

      Position position = await Geolocator.getCurrentPosition();
      setState(() {
        _selectedLocation = LatLng(position.latitude, position.longitude);
        _isLoading = false;
      });
    } catch (e) {
      // Default to Paris if permission fails
      setState(() {
        _selectedLocation = const LatLng(48.8566, 2.3522);
        _isLoading = false;
      });
    }
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
  }

  void _onTap(LatLng location) {
    setState(() {
      _selectedLocation = location;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Drop a Pin', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.black87),
        elevation: 0,
        actions: [
          if (_selectedLocation != null)
            TextButton(
              onPressed: () {
                Navigator.pop(context, _selectedLocation);
              },
              child: const Text('Confirm', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFFF28C64))),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFF28C64)))
          : Stack(
              children: [
                GoogleMap(
                  onMapCreated: _onMapCreated,
                  myLocationEnabled: true,
                  myLocationButtonEnabled: true,
                  initialCameraPosition: CameraPosition(
                    target: _selectedLocation!,
                    zoom: 12.0,
                  ),
                  onTap: _onTap,
                  markers: _selectedLocation != null
                      ? {
                          Marker(
                            markerId: const MarkerId('selected-location'),
                            position: _selectedLocation!,
                            infoWindow: const InfoWindow(title: "Property Location"),
                          ),
                        }
                      : {},
                ),
                Positioned(
                  top: 16,
                  left: 16,
                  right: 16,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
                    ),
                    child: TextField(
                      decoration: const InputDecoration(
                        hintText: 'Search a precise address or landmark...',
                        prefixIcon: Icon(Icons.search, color: Colors.grey),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 14),
                      ),
                      onSubmitted: (value) async {
                        if (value.trim().isEmpty) return;
                        try {
                          List<Location> locations = await locationFromAddress(value);
                          if (locations.isNotEmpty) {
                            final newLoc = LatLng(locations.first.latitude, locations.first.longitude);
                            setState(() {
                              _selectedLocation = newLoc;
                            });
                            _mapController?.animateCamera(CameraUpdate.newLatLngZoom(newLoc, 14.0));
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Could not find location: $value')),
                            );
                          }
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
