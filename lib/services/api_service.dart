import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class BoundingBox {
  final double x, y, width, height, confidence;
  final String className;
  BoundingBox({required this.x, required this.y, required this.width, required this.height, required this.className, required this.confidence});
  factory BoundingBox.fromJson(Map<String, dynamic> json) => BoundingBox(
    x: (json['x']?.toDouble() ?? 0.0),
    y: (json['y']?.toDouble() ?? 0.0),
    width: (json['width']?.toDouble() ?? 0.0),
    height: (json['height']?.toDouble() ?? 0.0),
    className: json['class'] ?? 'Object',
    confidence: (json['confidence']?.toDouble() ?? 0.0),
  );
}

class AnalysisResult {
  final String pestName;
  final String lifeStage;
  final String analysis;
  final String treatment;
  final List<BoundingBox> boxes;
  final String riskLevel;
  final String filename;
  final String? annotatedImageUrl;

  AnalysisResult({
    required this.pestName,
    required this.lifeStage,
    required this.analysis,
    required this.treatment,
    required this.boxes,
    required this.riskLevel,
    required this.filename,
    this.annotatedImageUrl,
  });
}

class ApiService {
  static const String baseUrl = "http://192.168.1.19:5000";

  static String _safeString(dynamic value, {String fallback = 'No information provided'}) {
    if (value == null) return fallback;
    if (value is String) return value;
    if (value is Map) {
      // If it's a map, try to convert to string or extract 'text' field
      if (value.containsKey('text')) return value['text'].toString();
      if (value.containsKey('content')) return value['content'].toString();
      return value.toString();
    }
    return value.toString();
  }

  static Future<AnalysisResult> sendImage(File imageFile) async {
    try {
      debugPrint('Sending request to $baseUrl/predict');
      var request = http.MultipartRequest('POST', Uri.parse('$baseUrl/predict'));
      request.files.add(await http.MultipartFile.fromPath('image', imageFile.path));

      var streamedResponse = await request.send().timeout(const Duration(seconds: 90));
      var response = await http.Response.fromStream(streamedResponse).timeout(const Duration(seconds: 90));

      if (response.statusCode != 200) {
        throw Exception("Server error: ${response.statusCode}\n${response.body}");
      }

      final decoded = json.decode(response.body);

      String? getAbsoluteImageUrl(String? relativePath) {
        if (relativePath == null) return null;
        if (relativePath.startsWith('http')) return relativePath;
        return '$baseUrl$relativePath';
      }

      // FAW detected (has 'stages' field)
      if (decoded.containsKey('stages')) {
        List<String> stages = List<String>.from(decoded['stages'] ?? []);
        String lifeStage = stages.isNotEmpty ? stages.first : 'Unknown';
        String riskLevel = decoded['risk'] ?? 'Medium';
        List<BoundingBox> boxes = [];
        if (decoded['boxes'] != null) {
          boxes = (decoded['boxes'] as List).map((b) => BoundingBox.fromJson(b)).toList();
        }

        // Safely extract analysis and treatment as strings
        String analysis = _safeString(decoded['analysis'], fallback: 'No analysis provided.');
        String treatment = _safeString(decoded['treatment'], fallback: 'No treatment plan provided.');

        return AnalysisResult(
          pestName: decoded['pest'] ?? 'Fall Armyworm',
          lifeStage: lifeStage,
          analysis: analysis,
          treatment: treatment,
          boxes: boxes,
          riskLevel: riskLevel,
          filename: decoded['image_url']?.split('/').last ?? '',
          annotatedImageUrl: getAbsoluteImageUrl(decoded['image_url']),
        );
      } 
      // Not FAW – uses 'analysis' and 'treatment' as well
      else {
        String analysis = _safeString(decoded['analysis'], fallback: 'No analysis provided.');
        String treatment = _safeString(decoded['treatment'], fallback: 'No treatment plan provided.');
        return AnalysisResult(
          pestName: decoded['pest'] ?? 'Unknown',
          lifeStage: 'None',
          analysis: analysis,
          treatment: treatment,
          boxes: [],
          riskLevel: 'Low',
          filename: decoded['image_url']?.split('/').last ?? '',
          annotatedImageUrl: getAbsoluteImageUrl(decoded['image_url']),
        );
      }
    } catch (e) {
      debugPrint('API Error: $e');
      rethrow;
    }
  }
}