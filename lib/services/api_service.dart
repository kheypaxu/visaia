import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class BoundingBox {
  final double x;
  final double y;
  final double width;
  final double height;

  BoundingBox({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  factory BoundingBox.fromJson(Map<String, dynamic> json) {
    return BoundingBox(
      x: (json['x']?.toDouble() ?? 0.0),
      y: (json['y']?.toDouble() ?? 0.0),
      width: (json['width']?.toDouble() ?? 0.0),
      height: (json['height']?.toDouble() ?? 0.0),
    );
  }
}

class AnalysisResult {
  final String pestName;
  final String lifeStage;
  final String fullPrediction;
  final List<BoundingBox> boxes;
  final String explanation;
  final String riskLevel;

  AnalysisResult({
    required this.pestName,
    required this.lifeStage,
    required this.fullPrediction,
    required this.boxes,
    required this.explanation,
    required this.riskLevel,
  });
}

class ApiService {
  static const String baseUrl = "http://192.168.254.121:5000";

  /// Sends an image file to the Flask server and returns the analysis result
  static Future<AnalysisResult> sendImage(File imageFile) async {
    try {
      // --- Prepare multipart request ---
      var request = http.MultipartRequest('POST', Uri.parse('$baseUrl/predict'));
      request.files.add(await http.MultipartFile.fromPath('image', imageFile.path));

      // --- Send request ---
      var streamedResponse = await request.send().timeout(
        const Duration(seconds: 30),
        onTimeout: () => throw Exception('Request timeout'),
      );

      var response = await http.Response.fromStream(streamedResponse).timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw Exception('Response timeout'),
      );

      if (streamedResponse.statusCode != 200) {
        throw Exception(
            "Server error: ${streamedResponse.statusCode} - ${response.body}");
      }

      // --- Decode server response ---
      final decoded = json.decode(response.body);

      String pest = decoded['pest'] ?? 'Unknown Pest';
      String stage = decoded['stage'] ?? '';
      String fullPrediction = decoded['full_prediction'] ?? "$pest - $stage Stage";
      String explanation = decoded['explanation'] ?? "No explanation provided";
      String riskLevel = decoded['risk_level'] ?? "N/A";

      List<BoundingBox> boxes = [];
      if (decoded['boxes'] != null) {
        boxes = (decoded['boxes'] as List)
            .map((boxJson) => BoundingBox.fromJson(boxJson))
            .toList();
      }

      return AnalysisResult(
        pestName: pest,
        lifeStage: stage,
        fullPrediction: fullPrediction,
        boxes: boxes,
        explanation: explanation,
        riskLevel: riskLevel,
      );
    } catch (e) {
      debugPrint('API Error: $e');
      throw Exception('Failed to analyze image: $e');
    }
  }
}
