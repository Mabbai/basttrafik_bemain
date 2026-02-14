import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

class Station {
  Station(this.name, this.location, {this.radius, String? apiName}) : _apiName = apiName;

  final String name;

  final Offset location;

  final double? radius;

  final String? _apiName;

  String get apiName => _apiName ?? name;

  static Future<List<Station>> readAsset(String assetPath) async {
    final json = jsonDecode(await rootBundle.loadString(assetPath)) as List<dynamic>;

    return json
        .map(
          (element) => Station(
            element["name"],
            Offset(element["location"]["x"], element["location"]["y"]),
            radius: (element["radius"] as num?)?.toDouble(),
            apiName: element["api_name"] as String? ?? element["apiName"] as String?,
          ),
        )
        .toList();
  }
}
