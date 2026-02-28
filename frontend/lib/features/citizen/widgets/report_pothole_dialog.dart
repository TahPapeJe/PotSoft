import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/report_provider.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../core/widgets/app_toast.dart';

class ReportPotholeDialog extends StatefulWidget {
  final double initialLat;
  final double initialLong;

  const ReportPotholeDialog({
    super.key,
    required this.initialLat,
    required this.initialLong,
  });

  @override
  State<ReportPotholeDialog> createState() => _ReportPotholeDialogState();
}

// Default fallback: Kuala Lumpur city centre
const double _kKLLat = 3.1390;
const double _kKLLng = 101.6869;

class _ReportPotholeDialogState extends State<ReportPotholeDialog> {
  final ImagePicker _picker = ImagePicker();
  Uint8List? _imageBytes;
  String? _base64Image;
  bool _isSubmitting = false;
  bool _isLoadingLocation = true;

  late double _selectedLat;
  late double _selectedLong;
  GoogleMapController? _dialogMapController;

  @override
  void initState() {
    super.initState();
    _selectedLat = widget.initialLat;
    _selectedLong = widget.initialLong;
    _resolveLocation();
  }

  /// Try the device GPS first; fall back to the passed-in coords or KL.
  Future<void> _resolveLocation() async {
    try {
      final serviceOk = await Geolocator.isLocationServiceEnabled();
      if (!serviceOk) {
        _fallback();
        return;
      }

      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
        if (perm == LocationPermission.denied) {
          _fallback();
          return;
        }
      }
      if (perm == LocationPermission.deniedForever) {
        _fallback();
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      if (mounted) {
        setState(() {
          _selectedLat = pos.latitude;
          _selectedLong = pos.longitude;
          _isLoadingLocation = false;
        });
        _dialogMapController?.animateCamera(
          CameraUpdate.newLatLng(LatLng(_selectedLat, _selectedLong)),
        );
      }
    } catch (_) {
      _fallback();
    }
  }

  void _fallback() {
    if (!mounted) return;
    // If the caller already had a real position use it; otherwise KL.
    final useFallbackKL =
        (_selectedLat == kMalaysiaCenter.lat &&
            _selectedLong == kMalaysiaCenter.lng) ||
        (_selectedLat == 0 && _selectedLong == 0);
    setState(() {
      if (useFallbackKL) {
        _selectedLat = _kKLLat;
        _selectedLong = _kKLLng;
      }
      _isLoadingLocation = false;
    });
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        imageQuality: 80,
      );

      if (image != null) {
        final bytes = await image.readAsBytes();
        setState(() {
          _imageBytes = bytes;
          _base64Image = base64Encode(bytes);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(AppToast.error('Failed to pick image: $e'));
      }
    }
  }

  Future<void> _submit() async {
    if (_base64Image == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(AppToast.info('Please provide an image of the pothole.'));
      return;
    }

    setState(() => _isSubmitting = true);

    final provider = Provider.of<ReportProvider>(context, listen: false);

    final newReport = await provider.submitReport(
      _selectedLat,
      _selectedLong,
      'data:image/jpeg;base64,$_base64Image',
    );

    if (mounted) {
      Navigator.of(context).pop();

      if (newReport != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          AppToast.success(
            'Report submitted successfully! Thank you for helping improve our roads.',
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          AppToast.error('Failed to submit report. Please try again.'),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500),
          decoration: BoxDecoration(
            color: AppColors.surface.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.borderFaint),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Report a Pothole',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: AppColors.textMuted),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: AppColors.border),

              // Scrollable content
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Image selection area
                      if (_imageBytes == null)
                        Container(
                          height: 200,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.borderFaint),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _buildImageButton(
                                icon: Icons.camera_alt,
                                label: 'Take Photo',
                                onTap: () => _pickImage(ImageSource.camera),
                              ),
                              Container(
                                width: 1,
                                height: 100,
                                color: AppColors.border,
                              ),
                              _buildImageButton(
                                icon: Icons.photo_library,
                                label: 'Gallery',
                                onTap: () => _pickImage(ImageSource.gallery),
                              ),
                            ],
                          ),
                        )
                      else
                        Stack(
                          alignment: Alignment.topRight,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.memory(
                                _imageBytes!,
                                height: 200,
                                width: double.infinity,
                                fit: BoxFit.cover,
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: CircleAvatar(
                                backgroundColor: Colors.black54,
                                child: IconButton(
                                  icon: const Icon(
                                    Icons.refresh,
                                    color: Colors.white,
                                  ),
                                  onPressed: () => setState(() {
                                    _imageBytes = null;
                                    _base64Image = null;
                                  }),
                                ),
                              ),
                            ),
                          ],
                        ),

                      const SizedBox(height: 24),

                      // Location pinpoint
                      const Text(
                        'Pinpoint exact location (Drag to adjust)',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        height: 250,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.borderSubtle),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Stack(
                            children: [
                              if (_isLoadingLocation)
                                const Center(
                                  child: CircularProgressIndicator(
                                    color: AppColors.accent,
                                  ),
                                )
                              else
                                GoogleMap(
                                  initialCameraPosition: CameraPosition(
                                    target: LatLng(_selectedLat, _selectedLong),
                                    zoom: 16,
                                  ),
                                  style: kDarkMapStyle,
                                  onMapCreated: (c) => _dialogMapController = c,
                                  onCameraMove: (position) {
                                    _selectedLat = position.target.latitude;
                                    _selectedLong = position.target.longitude;
                                  },
                                  myLocationEnabled: true,
                                  myLocationButtonEnabled: true,
                                  zoomControlsEnabled: false,
                                ),
                              const Center(
                                child: Padding(
                                  padding: EdgeInsets.only(bottom: 35.0),
                                  child: Icon(
                                    Icons.location_on,
                                    size: 40,
                                    color: Colors.redAccent,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Submit button
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(
                              color: Colors.black,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            'Submit Report',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                            ),
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImageButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: AppColors.accent),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
