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

  // AI Insights state
  Map<String, dynamic>? _insightSummary;
  Map<String, dynamic>? _insightTrends;
  Map<String, dynamic>? _insightRecommendations;
  Map<String, dynamic>? _insightJurisdictions;
  bool _insightsLoading = false;
  bool _summaryLoading = false;
  bool _trendsLoading = false;
  bool _recommendationsLoading = false;
  bool _jurisdictionsLoading = false;
  int _insightsCompleted = 0;
  String? _insightsError;

  List<PotholeReport> get reports => _reports;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // AI Insights getters
  Map<String, dynamic>? get insightSummary => _insightSummary;
  Map<String, dynamic>? get insightTrends => _insightTrends;
  Map<String, dynamic>? get insightRecommendations => _insightRecommendations;
  Map<String, dynamic>? get insightJurisdictions => _insightJurisdictions;
  bool get insightsLoading => _insightsLoading;
  bool get summaryLoading => _summaryLoading;
  bool get trendsLoading => _trendsLoading;
  bool get recommendationsLoading => _recommendationsLoading;
  bool get jurisdictionsLoading => _jurisdictionsLoading;
  int get insightsCompleted => _insightsCompleted;
  String? get insightsError => _insightsError;
  bool get hasInsights =>
      _insightSummary != null ||
      _insightTrends != null ||
      _insightRecommendations != null ||
      _insightJurisdictions != null;

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

  // ── AI Insights ─────────────────────────────────────────────────────────

  /// Load all four Gemini insight panels progressively.
  /// Each section streams in as soon as its API call completes.
  Future<void> loadInsights() async {
    _insightsLoading = true;
    _insightsError = null;
    _insightsCompleted = 0;
    _summaryLoading = true;
    _trendsLoading = true;
    _recommendationsLoading = true;
    _jurisdictionsLoading = true;
    // Clear old data so skeletons show for each section
    _insightSummary = null;
    _insightTrends = null;
    _insightRecommendations = null;
    _insightJurisdictions = null;
    notifyListeners();

    // Fire all 4 concurrently but handle each individually
    final futures = <Future<void>>[
      _api.fetchInsightSummary().then((data) {
        _insightSummary = data;
        _summaryLoading = false;
        _insightsCompleted++;
        notifyListeners();
      }),
      _api.fetchInsightTrends().then((data) {
        _insightTrends = data;
        _trendsLoading = false;
        _insightsCompleted++;
        notifyListeners();
      }),
      _api.fetchInsightRecommendations().then((data) {
        _insightRecommendations = data;
        _recommendationsLoading = false;
        _insightsCompleted++;
        notifyListeners();
      }),
      _api.fetchInsightJurisdictions().then((data) {
        _insightJurisdictions = data;
        _jurisdictionsLoading = false;
        _insightsCompleted++;
        notifyListeners();
      }),
    ];

    try {
      await Future.wait(futures);
    } catch (e) {
      _insightsError = e.toString();
      debugPrint('loadInsights error: $e');
    } finally {
      _insightsLoading = false;
      _summaryLoading = false;
      _trendsLoading = false;
      _recommendationsLoading = false;
      _jurisdictionsLoading = false;
      notifyListeners();
    }
  }
}
