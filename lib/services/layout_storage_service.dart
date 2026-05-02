import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import '../models/layout_model.dart';

class LayoutStorageService {
  static const String seedLayoutAsset = 'assets/layouts/layout.json';
  static const String savedLayoutFileName = 'layout_saved.json';

  Future<LayoutData> loadLayout() async {
    final savedFile = await _getSavedLayoutFile();
    if (await savedFile.exists()) {
      final raw = await savedFile.readAsString();
      return LayoutData.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    }

    final assetRaw = await rootBundle.loadString(seedLayoutAsset);
    return LayoutData.fromJson(jsonDecode(assetRaw) as Map<String, dynamic>);
  }

  Future<File> saveLayout(LayoutData layout) async {
    final savedFile = await _getSavedLayoutFile();
    await savedFile.writeAsString(layout.toPrettyJson(), flush: true);
    return savedFile;
  }

  Future<File> _getSavedLayoutFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$savedLayoutFileName');
  }
}
