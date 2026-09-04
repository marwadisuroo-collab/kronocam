import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart';

import '../services/location_service.dart';

class MapScreen extends StatefulWidget {
  final LocationResult? initialLocation;

  const MapScreen({super.key, this.initialLocation});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  GoogleMapController? _mapController;
  late LatLng _selected;
  final _searchController = TextEditingController();
  bool _searching = false;

  @override
  void initState() {
    super.initState();
    final location = widget.initialLocation;
    _selected = LatLng(location?.latitude ?? 20.5937, location?.longitude ?? 78.9629);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;
    setState(() => _searching = true);
    try {
      final results = await locationFromAddress(query);
      if (results.isEmpty) throw const FormatException('Place not found');
      final result = results.first;
      await _select(LatLng(result.latitude, result.longitude));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Place not found. Try a fuller address.')),
        );
      }
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _select(LatLng point) async {
    setState(() => _selected = point);
    await _mapController?.animateCamera(CameraUpdate.newLatLng(point));
  }

  Future<void> _useLocation() async {
    final result = await LocationService.fromCoordinates(
      _selected.latitude,
      _selected.longitude,
    );
    if (mounted) Navigator.pop(context, result);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Choose Location')),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(target: _selected, zoom: 15),
            onMapCreated: (controller) => _mapController = controller,
            onTap: _select,
            zoomControlsEnabled: true,
            myLocationButtonEnabled: true,
            markers: {
              Marker(markerId: const MarkerId('selected'), position: _selected),
            },
          ),
          Positioned(
            left: 12,
            right: 12,
            top: 12,
            child: Material(
              elevation: 4,
              borderRadius: BorderRadius.circular(8),
              child: TextField(
                controller: _searchController,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _search(),
                decoration: InputDecoration(
                  hintText: 'Search a place or address',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searching
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : IconButton(icon: const Icon(Icons.arrow_forward), onPressed: _search),
                  filled: true,
                  fillColor: Theme.of(context).colorScheme.surface,
                  border: InputBorder.none,
                ),
              ),
            ),
          ),
          Positioned(
            left: 20,
            right: 20,
            bottom: 20,
            child: FilledButton.icon(
              onPressed: _useLocation,
              icon: const Icon(Icons.location_on),
              label: const Text('Use This Location'),
            ),
          ),
        ],
      ),
    );
  }
}
