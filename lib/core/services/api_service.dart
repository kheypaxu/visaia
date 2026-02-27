import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class BoundingBox {
  final double x, y, width, height, confidence;
  final String className;

  BoundingBox({
    required this.x, 
    required this.y, 
    required this.width, 
    required this.height, 
    required this.className,
    required this.confidence,
  });

  factory BoundingBox.fromJson(Map<String, dynamic> json) {
    return BoundingBox(
      x: (json['x']?.toDouble() ?? 0.0),
      y: (json['y']?.toDouble() ?? 0.0),
      width: (json['width']?.toDouble() ?? 0.0),
      height: (json['height']?.toDouble() ?? 0.0),
      className: json['class'] ?? 'Object',
      confidence: (json['confidence']?.toDouble() ?? 0.0),
    );
  }
}

class AnalysisResult {
  final String pestName, lifeStage, fullPrediction, explanation, riskLevel;
  final List<BoundingBox> boxes;

  AnalysisResult({
    required this.pestName, required this.lifeStage, required this.fullPrediction,
    required this.boxes, required this.explanation, required this.riskLevel,
  });
}

class ApiService {
  static const String baseUrl = "http://192.168.1.39:5000"; 

  static Future<AnalysisResult> sendImage(File imageFile) async {
    try {
      debugPrint('🚀 Sending request to $baseUrl/predict');
      
      var request = http.MultipartRequest('POST', Uri.parse('$baseUrl/predict'));
      request.files.add(await http.MultipartFile.fromPath('image', imageFile.path));

      // Increased timeout to 90 seconds for AI processing
      var streamedResponse = await request.send().timeout(
        const Duration(seconds: 90),
        onTimeout: () => throw Exception('Server is taking too long to process.'),
      );

      var response = await http.Response.fromStream(streamedResponse).timeout(
        const Duration(seconds: 90),
        onTimeout: () => throw Exception('Connection lost while receiving data.'),
      );

      if (response.statusCode != 200) {
        throw Exception("Server error: ${response.statusCode}\n${response.body}");
      }

      final decoded = json.decode(response.body);

      List<BoundingBox> boxes = [];
      if (decoded['boxes'] != null) {
        boxes = (decoded['boxes'] as List).map((b) => BoundingBox.fromJson(b)).toList();
      }

      return AnalysisResult(
        pestName: decoded['pest'] ?? 'Unknown',
        lifeStage: decoded['stage'] ?? '',
        fullPrediction: decoded['full_prediction'] ?? 'No prediction',
        boxes: boxes,
        explanation: decoded['explanation'] ?? '',
        riskLevel: decoded['risk_level'] ?? 'N/A',
      );
    } catch (e) {
      debugPrint('❌ API Error: $e');
      rethrow;
    }
  }
}