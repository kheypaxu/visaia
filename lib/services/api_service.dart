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
  final String scientificName;
  final String lifeStage;
  final String analysis;
  final String treatment;
  final List<BoundingBox> boxes;
  final String riskLevel;
  final String filename;
  final String? annotatedImageUrl;
  final String historicalContext;
  final String cropAffected;
  final double confidence;

  AnalysisResult({
    required this.pestName,
    required this.scientificName,
    required this.lifeStage,
    required this.analysis,
    required this.treatment,
    required this.boxes,
    required this.riskLevel,
    required this.filename,
    this.annotatedImageUrl,
    required this.historicalContext,
    required this.cropAffected,
    required this.confidence,
  });
}

class ApiService {
  static const String baseUrl = "https://automatically-unbefriended-misty.ngrok-free.dev";

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

  static double _calculateOverallConfidence(List<BoundingBox> boxes) {
    if (boxes.isEmpty) return 0.85; // Default confidence if no boxes
    double sum = boxes.fold(0.0, (s, b) => s + b.confidence);
    return (sum / boxes.length).clamp(0.0, 1.0);
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
      debugPrint('API Response: $decoded');

      String? getAbsoluteImageUrl(String? relativePath) {
        if (relativePath == null) return null;
        if (relativePath.startsWith('http')) return relativePath;
        return '$baseUrl$relativePath';
      }

      // Extract bounding boxes
      List<BoundingBox> boxes = [];
      if (decoded['boxes'] != null) {
        boxes = (decoded['boxes'] as List).map((b) => BoundingBox.fromJson(b)).toList();
      }

      // Calculate overall confidence
      double overallConfidence = _calculateOverallConfidence(boxes);
      
      // Also check if there's a direct confidence field
      if (decoded['confidence'] != null) {
        overallConfidence = (decoded['confidence'] as num).toDouble();
      }

      // Extract scientific name
      String scientificName = decoded['scientific_name'] ?? 
                              _getScientificNameForPest(decoded['pest'] ?? 'Fall Armyworm');

      // Extract historical context
      String historicalContext = _safeString(
        decoded['historical_context'],
        fallback: 'This pest is known to cause significant crop damage. '
                  'Regular monitoring and early intervention are key to management.',
      );

      // Extract crop affected or use default
      String cropAffected = decoded['crop_affected'] ?? 'Maize (Corn)';

      // FAW detected (has 'stages' field)
      if (decoded.containsKey('stages')) {
        List<String> stages = List<String>.from(decoded['stages'] ?? []);
        String lifeStage = stages.isNotEmpty ? stages.first : 'Unknown';
        String riskLevel = decoded['risk'] ?? 'Medium';
        
        // Safely extract analysis and treatment as strings
        String analysis = _safeString(
          decoded['analysis'], 
          fallback: 'The analysis could not be generated. Please consult an agricultural expert.',
        );
        
        String treatment = _safeString(
          decoded['treatment'],
          fallback: 'No treatment plan provided. Please contact agricultural extension services.',
        );

        return AnalysisResult(
          pestName: decoded['pest'] ?? 'Fall Armyworm',
          scientificName: scientificName,
          lifeStage: lifeStage,
          analysis: analysis,
          treatment: treatment,
          boxes: boxes,
          riskLevel: riskLevel,
          filename: decoded['image_url']?.split('/').last ?? '',
          annotatedImageUrl: getAbsoluteImageUrl(decoded['image_url']),
          historicalContext: historicalContext,
          cropAffected: cropAffected,
          confidence: overallConfidence,
        );
      } 
      // Not FAW – uses 'analysis' and 'treatment' as well
      else {
        String analysis = _safeString(
          decoded['analysis'], 
          fallback: 'No analysis provided. This may not be a recognized pest.',
        );
        
        String treatment = _safeString(
          decoded['treatment'],
          fallback: 'No treatment plan available for this detection.',
        );

        return AnalysisResult(
          pestName: decoded['pest'] ?? 'Unknown Pest',
          scientificName: scientificName,
          lifeStage: 'Unknown',
          analysis: analysis,
          treatment: treatment,
          boxes: boxes,
          riskLevel: decoded['risk'] ?? 'Low',
          filename: decoded['image_url']?.split('/').last ?? '',
          annotatedImageUrl: getAbsoluteImageUrl(decoded['image_url']),
          historicalContext: historicalContext,
          cropAffected: cropAffected,
          confidence: overallConfidence,
        );
      }
    } catch (e) {
      debugPrint('API Error: $e');
      rethrow;
    }
  }

  // Helper method to get scientific name based on pest name
  static String _getScientificNameForPest(String pestName) {
    final pestMap = {
      'Fall Army Worm': 'Spodoptera frugiperda',
      'African Armyworm': 'Spodoptera exempta',
      'Corn Earworm': 'Helicoverpa zea',
      'European Corn Borer': 'Ostrinia nubilalis',
      'Cotton Bollworm': 'Helicoverpa armigera',
      'Diamondback Moth': 'Plutella xylostella',
      'Aphid': 'Aphidoidea',
      'Whitefly': 'Aleyrodidae',
      'Locust': 'Acrididae',
      'Beetle': 'Coleoptera',
    };
    
    return pestMap[pestName] ?? 'Species unidentified';
  }
}