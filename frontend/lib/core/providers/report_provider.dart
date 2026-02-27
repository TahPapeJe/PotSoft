import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../models/pothole_report.dart';
import '../services/api_service.dart';

class ReportProvider extends ChangeNotifier {
  final ApiService _api = ApiService();

  List<PotholeReport> _reports = [];
  bool _isLoading = false;
  String? _error;

  List<PotholeReport> get reports => _reports;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Load all reports from backend
  Future<void> loadReports() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final jsonList = await _api.fetchReports();
      _reports = jsonList.map((json) => PotholeReport.fromJson(json)).toList();
    } catch (e) {
      _error = e.toString();
      debugPrint('loadReports error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Submit a new report (image + GPS -> Gemini analysis)
  Future<PotholeReport?> submitReport(
    double lat,
    double long,
    String imageDataUri,
  ) async {
    try {
      // Extract raw bytes from the data URI produced by image_picker
      // Format: "data:image/jpeg;base64,<base64string>"
      final Uint8List imageBytes;
      if (imageDataUri.contains(';base64,')) {
        final b64 = imageDataUri.split(';base64,').last;
        imageBytes = base64Decode(b64);
      } else {
        imageBytes = base64Decode(imageDataUri);
      }

      final json = await _api.submitReport(
        lat: lat,
        lng: long,
        imageBytes: imageBytes,
      );

      final report = PotholeReport.fromJson(json);
      _reports.add(report);
      notifyListeners();
      return report;
    } catch (e) {
      _error = e.toString();
      debugPrint('submitReport error: $e');
      notifyListeners();
      return null;
    }
  }

  // Update report status (Contractor flow)
  Future<void> updateStatus(String id, String newStatus) async {
    try {
      await _api.updateStatus(reportId: id, newStatus: newStatus);

      final index = _reports.indexWhere((r) => r.id == id);
      if (index != -1) {
        _reports[index] = _reports[index].copyWith(status: newStatus);
        notifyListeners();
      }
    } catch (e) {
      _error = e.toString();
      debugPrint('updateStatus error: $e');
      notifyListeners();
    }
  }
}
