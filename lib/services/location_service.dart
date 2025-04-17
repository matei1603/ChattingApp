import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';

class LocationService {
  static const double radiusInMeters = 100;

  static Future<GeoPoint?> getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return null;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        return null;
      }
    }

    final position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
    return GeoPoint(position.latitude, position.longitude);
  }

  static double _calculateDistance(GeoPoint point1, GeoPoint point2) {
    const earthRadius = 6371000.0;
    final dLat = _degToRad(point2.latitude - point1.latitude);
    final dLon = _degToRad(point2.longitude - point1.longitude);

    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_degToRad(point1.latitude)) *
            cos(_degToRad(point2.latitude)) *
            sin(dLon / 2) * sin(dLon / 2);

    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  static double _degToRad(double deg) => deg * pi / 180;

  static Future<bool> isWithinRadius(GeoPoint? userLocation, GeoPoint? targetLocation) async {
    if (userLocation == null || targetLocation == null) return false;
    double distance = _calculateDistance(userLocation, targetLocation);
    return distance <= radiusInMeters;
  }

  static Future<bool> shouldShowMessage({
    required String currentUserId,
    required String senderId,
    required String locationType,
    required Map<String, dynamic>? currentUserData,
  }) async {
    if (senderId == currentUserId) return true;

    if (locationType == 'public') return true;

    GeoPoint? targetLocation = currentUserData?[locationType == 'home' ? 'homeLocation' : 'workLocation'];
    if (targetLocation == null) return true;

    final currentLoc = await getCurrentLocation();
    if (currentLoc == null) return false;

    return await isWithinRadius(currentLoc, targetLocation);
  }
}
