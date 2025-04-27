import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_google_places_hoc081098/flutter_google_places_hoc081098.dart';
import 'package:flutter_google_places_hoc081098/google_maps_webservice_places.dart';

const String kGoogleApiKey = 'AIzaSyB6pRZCHnvSBlqZiawHzuysuNCnVH4sNwM';
final GoogleMapsPlaces _places = GoogleMapsPlaces(apiKey: kGoogleApiKey);

class LocationPickerScreen extends StatefulWidget {
  final void Function(LatLng) onLocationSelected;

  const LocationPickerScreen({Key? key, required this.onLocationSelected}) : super(key: key);

  @override
  _LocationPickerScreenState createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  LatLng? selectedLocation;
  GoogleMapController? _mapController;

  void _goToLocation(LatLng latLng) {
    _mapController?.animateCamera(CameraUpdate.newLatLngZoom(latLng, 15));
    setState(() {
      selectedLocation = latLng;
    });
  }

  Future<void> _handleSearch() async {
    final prediction = await PlacesAutocomplete.show(
      context: context,
      apiKey: kGoogleApiKey,
      mode: Mode.overlay,
      language: "en",
      components: [Component(Component.country, "ro")],
    );

    if (prediction != null) {
      final detail = await _places.getDetailsByPlaceId(prediction.placeId!);
      final lat = detail.result.geometry!.location.lat;
      final lng = detail.result.geometry!.location.lng;
      _goToLocation(LatLng(lat, lng));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Pick a Location"),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: _handleSearch,
          )
        ],
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: const CameraPosition(
              target: LatLng(45.9432, 24.9668), // Romania default
              zoom: 6,
            ),
            onMapCreated: (controller) => _mapController = controller,
            onTap: (LatLng latLng) {
              setState(() => selectedLocation = latLng);
            },
            markers: selectedLocation != null
                ? {
              Marker(
                markerId: const MarkerId('selected'),
                position: selectedLocation!,
              )
            }
                : {},
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
                child: const Text("Save This Location"),
              ),
            ),
        ],
      ),
    );
  }
}
