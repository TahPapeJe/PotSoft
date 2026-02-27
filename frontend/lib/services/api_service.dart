import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiService {
  final String? _baseUrl = dotenv.env['API_BASE_URL'];

  Future<String> analyzeImage(File image) async {
    if (_baseUrl == null) {
      throw Exception("API_BASE_URL not found in .env file");
    }
    
    final uri = Uri.parse('$_baseUrl/analyze');
    final request = http.MultipartRequest('POST', uri);
    final mimeType = _mimeTypeFromPath(image.path);
    request.files.add(await http.MultipartFile.fromPath(
      'file',
      image.path,
      contentType: mimeType,
    ));

    try {
      final response = await request.send();

      if (response.statusCode == 200) {
        final responseBody = await response.stream.bytesToString();
        final decoded = json.decode(responseBody);
        if (decoded['success'] == true) {
          return decoded['analysis'];
        } else {
          throw Exception(decoded['error'] ?? 'Failed to analyze image.');
        }
      } else {
        final responseBody = await response.stream.bytesToString();
        throw Exception('Failed to connect to the server: ${response.statusCode} ${response.reasonPhrase} $responseBody');
      }
    } catch (e) {
      throw Exception('Failed to send image: $e');
    }
  }

  MediaType _mimeTypeFromPath(String path) {
    final ext = path.toLowerCase().split('.').last;
    const map = {
      'jpg': 'image/jpeg',
      'jpeg': 'image/jpeg',
      'png': 'image/png',
      'gif': 'image/gif',
      'webp': 'image/webp',
      'bmp': 'image/bmp',
      'heic': 'image/heic',
      'tiff': 'image/tiff',
      'avif': 'image/avif',
    };
    final mime = map[ext] ?? 'application/octet-stream';
    final parts = mime.split('/');
    return MediaType(parts[0], parts[1]);
  }
}
