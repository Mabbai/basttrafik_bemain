import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';

class Station {
  Station(this.name, this.location, {String? apiName}) : _apiName = apiName;

  final String name;

  final Offset location;

  final String? _apiName;

  String get apiName => _apiName ?? name;

  static Future<List<Station>> readFile(File file) async {
    final json = jsonDecode(await file.readAsString()) as List<dynamic>;

    return json
        .map(
          (element) => Station(
            element["name"],
            Offset(element["location"]["x"], element["location"]["y"]),
          ),
        )
        .toList();
  }
}
