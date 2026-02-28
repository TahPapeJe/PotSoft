import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

/// HTTP client for the PotSoft backend API.
///
/// Switch [baseUrl] between localhost (dev) and your deployed URL (prod).
/// Uses `const String.fromEnvironment` so you can pass it at build time:
///   flutter run --dart-define=API_URL=https://your-api.run.app
class ApiService {
  final String baseUrl;

  ApiService({
    this.baseUrl = const String.fromEnvironment(
      'API_URL',
      defaultValue: 'http://localhost:8000',
    ),
  });

  // ── GET /api/reports ────────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> fetchReports() async {
    final uri = Uri.parse('$baseUrl/api/reports');
    final response = await http.get(uri);

    if (response.statusCode == 200) {
      final List<dynamic> body = jsonDecode(response.body);
      return body.cast<Map<String, dynamic>>();
    } else {
      throw ApiException('Failed to load reports (${response.statusCode})');
    }
  }

  // ── POST /api/reports ───────────────────────────────────────────────────
  /// Submits a new pothole report.
  ///
  /// [lat], [lng] — GPS coordinates.
  /// [imageBytes] — raw image bytes (from image_picker).
  /// [mimeType] — e.g. "image/jpeg".
  Future<Map<String, dynamic>> submitReport({
    required double lat,
    required double lng,
    required Uint8List imageBytes,
    String mimeType = 'image/jpeg',
  }) async {
    final uri = Uri.parse('$baseUrl/api/reports');

    final request = http.MultipartRequest('POST', uri)
      ..fields['lat'] = lat.toString()
      ..fields['long'] = lng.toString()
      ..files.add(
        http.MultipartFile.fromBytes(
          'image',
          imageBytes,
          filename: 'pothole.jpg',
        ),
      );

    final streamed = await request.send();
    final body = await streamed.stream.bytesToString();

    if (streamed.statusCode == 201) {
      return jsonDecode(body) as Map<String, dynamic>;
    } else {
      throw ApiException(
        'Failed to submit report (${streamed.statusCode}): $body',
      );
    }
  }

  // ── PATCH /api/reports/:id/status ───────────────────────────────────────
  Future<Map<String, dynamic>> updateStatus({
    required String reportId,
    required String newStatus,
  }) async {
    final uri = Uri.parse('$baseUrl/api/reports/$reportId/status');
    final response = await http.patch(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'status': newStatus}),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw ApiException(
        'Failed to update status (${response.statusCode}): ${response.body}',
      );
    }
  }

  // ── AI Insights endpoints ───────────────────────────────────────────────

  Future<Map<String, dynamic>> fetchInsightSummary() async {
    final uri = Uri.parse('$baseUrl/api/insights/summary');
    final response = await http.get(uri);
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw ApiException('Failed to load summary (${response.statusCode})');
    }
  }

  Future<Map<String, dynamic>> fetchInsightTrends() async {
    final uri = Uri.parse('$baseUrl/api/insights/trends');
    final response = await http.get(uri);
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw ApiException('Failed to load trends (${response.statusCode})');
    }
  }

  Future<Map<String, dynamic>> fetchInsightRecommendations() async {
    final uri = Uri.parse('$baseUrl/api/insights/recommendations');
    final response = await http.get(uri);
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw ApiException(
        'Failed to load recommendations (${response.statusCode})',
      );
    }
  }

  Future<Map<String, dynamic>> fetchInsightJurisdictions() async {
    final uri = Uri.parse('$baseUrl/api/insights/jurisdictions');
    final response = await http.get(uri);
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw ApiException(
        'Failed to load jurisdiction scores (${response.statusCode})',
      );
    }
  }
}

/// Simple exception class for API errors.
class ApiException implements Exception {
  final String message;
  ApiException(this.message);

  @override
  String toString() => 'ApiException: $message';
}
