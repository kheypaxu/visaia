import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// The weather that was actually recorded at a pest detection point and time.
///
/// Adult moths are carried well beyond their own ~5 km flight range when it
/// is windy, so the proximity zone is scaled with the sustained 10 m wind
/// recorded at the detection point. Uses the same Open-Meteo reanalysis
/// endpoints as the web dashboard.
class DetectionWeather {
  final double lat;
  final double lng;

  /// km/h
  final double windSpeed;

  /// Meteorological degrees: the direction the wind blows FROM.
  final int windDirection;

  final DateTime observedAt;

  const DetectionWeather({
    required this.lat,
    required this.lng,
    required this.windSpeed,
    required this.windDirection,
    required this.observedAt,
  });
}

/// Fetches and caches the historical wind at detection points.
class DetectionWeatherService {
  static const String _archiveEndpoint =
      'https://archive-api.open-meteo.com/v1/archive';
  static const String _recentEndpoint =
      'https://api.open-meteo.com/v1/forecast';

  /// At or below this the zone is not scaled.
  static const double windCalmKmh = 10;

  /// At or above this the zone doubles.
  static const double windStrongKmh = 40;

  static const double mothMaxMultiplier = 2;
  static const double mothBaseRadiusM = 5000;

  /// Detections inside this window are served by the forecast endpoint.
  static const int _recentWindowDays = 7;

  static const int _requestTimeoutMs = 12000;

  /// ~1.1 km. Far finer than a 5 km monitoring zone, so nearby detections
  /// collapse onto one request without changing the answer.
  static const int _coordPrecision = 2;

  final Map<String, DetectionWeather?> _cache = <String, DetectionWeather?>{};

  /// The monitoring radius in metres for a detection, scaled by the wind.
  static double mothRadiusMeters(DetectionWeather? weather) {
    final multiplier = windSpreadMultiplier(weather);
    // Rounded to 100 m so the circle and the label read cleanly.
    return (mothBaseRadiusM * multiplier / 100).round() * 100;
  }

  /// Wind assisted dispersal multiplier, 1.0 (calm) to 2.0 (strong wind).
  static double windSpreadMultiplier(DetectionWeather? weather) {
    if (weather == null || !weather.windSpeed.isFinite) return 1;
    if (weather.windSpeed <= windCalmKmh) return 1;
    if (weather.windSpeed >= windStrongKmh) return mothMaxMultiplier;
    final ramp = (weather.windSpeed - windCalmKmh) / (windStrongKmh - windCalmKmh);
    return 1 + ramp * (mothMaxMultiplier - 1);
  }

  String _cacheKey(double lat, double lng, DateTime date) {
    final day = date.toIso8601String().substring(0, 10);
    return '${lat.toStringAsFixed(_coordPrecision)},'
        '${lng.toStringAsFixed(_coordPrecision)}|$day';
  }

  /// Resolves the weather recorded at a detection point and time.
  Future<DetectionWeather?> fetch(
      double lat, double lng, DateTime date) async {
    if (!lat.isFinite || !lng.isFinite) return null;

    final key = _cacheKey(lat, lng, date);
    if (_cache.containsKey(key)) return _cache[key];

    final day = date.toIso8601String().substring(0, 10);
    final useArchive = day.compareTo(_daysAgoKey(_recentWindowDays)) <= 0;

    DetectionWeather? result;
    try {
      final uri = useArchive
          ? Uri.parse(_archiveEndpoint).replace(queryParameters: {
              'latitude': '$lat',
              'longitude': '$lng',
              'hourly': 'wind_speed_10m,wind_direction_10m',
              'wind_speed_unit': 'kmh',
              'timezone': 'GMT',
              'timeformat': 'unixtime',
              'start_date': day,
              'end_date': day,
            })
          : Uri.parse(_recentEndpoint).replace(queryParameters: {
              'latitude': '$lat',
              'longitude': '$lng',
              'hourly': 'wind_speed_10m,wind_direction_10m',
              'wind_speed_unit': 'kmh',
              'timezone': 'GMT',
              'timeformat': 'unixtime',
              'past_days': '$_recentWindowDays',
              'forecast_days': '1',
            });

      final response = await http
          .get(uri)
          .timeout(const Duration(milliseconds: _requestTimeoutMs));
      if (response.statusCode == 200) {
        result = _parse(jsonDecode(response.body), lat, lng, date);
      }
    } catch (e) {
      debugPrint('DetectionWeatherService: wind lookup failed: $e');
    }

    _cache[key] = result;
    return result;
  }

  /// Fetches the wind for many detections with a bounded parallelism.
  Future<List<DetectionWeather?>> fetchBatch(
      List<({double lat, double lng, DateTime date})> items,
      {int concurrency = 4}) async {
    final results = List<DetectionWeather?>.filled(items.length, null);
    var index = 0;

    Future<void> worker() async {
      while (true) {
        final i = index++;
        if (i >= items.length) return;
        final item = items[i];
        try {
          results[i] = await fetch(item.lat, item.lng, item.date);
        } catch (e) {
          results[i] = null;
        }
      }
    }

    final workers = List.generate(
      concurrency.clamp(1, items.isEmpty ? 1 : items.length),
      (_) => worker(),
    );
    await Future.wait(workers);
    return results;
  }

  DetectionWeather? _parse(
      Map<String, dynamic> body, double lat, double lng, DateTime target) {
    if (body['error'] == true) return null;
    final hourly = body['hourly'];
    if (hourly is! Map) return null;

    final times = hourly['time'];
    final speeds = hourly['wind_speed_10m'];
    final directions = hourly['wind_direction_10m'];
    if (times is! List || times.isEmpty || speeds is! List) return null;

    var bestIndex = -1;
    var bestDelta = 1 << 62;
    final targetMs = target.millisecondsSinceEpoch;
    for (var i = 0; i < times.length; i++) {
      final raw = times[i];
      if (raw is! num) continue;
      final delta = (raw.toInt() * 1000 - targetMs).abs();
      if (delta < bestDelta) {
        bestDelta = delta;
        bestIndex = i;
      }
    }
    // Reject a match further away than 2 hours.
    if (bestIndex < 0 || bestDelta > 2 * 60 * 60 * 1000) return null;

    final speed = speeds[bestIndex];
    if (speed is! num) return null;

    final direction = (directions is List && directions[bestIndex] is num)
        ? (directions[bestIndex] as num).toInt()
        : 0;

    return DetectionWeather(
      lat: double.parse(lat.toStringAsFixed(_coordPrecision)),
      lng: double.parse(lng.toStringAsFixed(_coordPrecision)),
      windSpeed: speed.toDouble(),
      windDirection: direction,
      observedAt:
          DateTime.fromMillisecondsSinceEpoch((times[bestIndex] as num).toInt() * 1000),
    );
  }

  String _daysAgoKey(int days) {
    final date = DateTime.now().subtract(Duration(days: days));
    return date.toIso8601String().substring(0, 10);
  }
}
