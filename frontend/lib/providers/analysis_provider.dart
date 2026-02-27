import 'dart:io';
import 'package:flutter/material.dart';
import '../services/api_service.dart';

/// Provider that manages the state for image selection and AI analysis.
/// Uses ChangeNotifier to reactively update the UI when state changes.
class AnalysisProvider with ChangeNotifier {
  File? _image;
  String? _analysisResult;
  bool _isLoading = false;
  String? _errorMessage;

  File? get image => _image;
  String? get analysisResult => _analysisResult;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  final ApiService _apiService = ApiService();

  /// Sets the selected image and clears previous results.
  void setImage(File? image) {
    _image = image;
    _analysisResult = null;
    _errorMessage = null;
    notifyListeners();
  }

  /// Sends the image to the FastAPI backend for Gemini analysis.
  Future<void> analyzeImage() async {
    if (_image == null) {
      _errorMessage = 'Please select an image first.';
      notifyListeners();
      return;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _analysisResult = await _apiService.analyzeImage(_image!);
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Clears all state — selected image, results, and errors.
  void clear() {
    _image = null;
    _analysisResult = null;
    _errorMessage = null;
    _isLoading = false;
    notifyListeners();
  }
}
