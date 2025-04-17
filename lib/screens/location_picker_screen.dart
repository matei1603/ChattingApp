import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class LocationPickerScreen extends StatefulWidget {
  final void Function(LatLng) onLocationSelected;

  const LocationPickerScreen({Key? key, required this.onLocationSelected}) : super(key: key);

  @override
  _LocationPickerScreenState createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  LatLng? selectedLocation;
  GoogleMapController? _mapController;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Pick a Location")),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: LatLng(45.9432, 24.9668), // Romania default center
              zoom: 6,
            ),
            onTap: (LatLng latLng) {
              setState(() => selectedLocation = latLng);
            },
            markers: selectedLocation != null
                ? {
              Marker(
                markerId: MarkerId('selected'),
                position: selectedLocation!,
              )
            }
                : {},
            onMapCreated: (controller) => _mapController = controller,
          ),
          if (selectedLocation != null)
            Positioned(
              bottom: 20,
              left: 40,
              right: 40,
              child: ElevatedButton(
                onPressed: () {
                  widget.onLocationSelected(selectedLocation!);
                  Navigator.pop(context);
                },
                child: Text("Save This Location"),
              ),
            ),
        ],
      ),
    );
  }
}
