import '../../shared/models/app_models.dart';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProfileAvatarCache {
  static String _pathKey(String ref) => 'profile_avatar_path_$ref';
  static String _urlKey(String ref) => 'profile_avatar_url_$ref';

  static Future<File?> getCached(SessionProfile profile) async {
    if (profile.ref.trim().isEmpty) {
      return null;
    }
    final prefs = await SharedPreferences.getInstance();
    final path = prefs.getString(_pathKey(profile.ref));
    final url = prefs.getString(_urlKey(profile.ref));
    if (path == null || path.isEmpty || url != profile.avatarUrl) {
      return null;
    }
    final file = File(path);
    if (await file.exists()) {
      return file;
    }
    return null;
  }

  static Future<File?> cacheFromBytes(
    SessionProfile profile,
    List<int> bytes,
    String filename,
  ) async {
    if (profile.ref.trim().isEmpty || bytes.isEmpty) {
      return null;
    }
    final dir = await getApplicationDocumentsDirectory();
    final ext = _extensionFromFilename(filename);
    final file = File('${dir.path}/avatar_${profile.ref}$ext');
    await file.writeAsBytes(bytes, flush: true);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pathKey(profile.ref), file.path);
    await prefs.setString(_urlKey(profile.ref), profile.avatarUrl);
    return file;
  }

  static Future<File?> ensureCached(SessionProfile profile) async {
    if (profile.avatarUrl.trim().isEmpty) {
      return null;
    }
    final cached = await getCached(profile);
    if (cached != null) {
      return cached;
    }

    final response = await http.get(Uri.parse(profile.avatarUrl));
    if (response.statusCode != 200 || response.bodyBytes.isEmpty) {
      return null;
    }
    return cacheFromBytes(profile, response.bodyBytes, profile.avatarUrl);
  }

  static String _extensionFromFilename(String filename) {
    final clean = filename.split('?').first;
    final dot = clean.lastIndexOf('.');
    if (dot <= 0 || dot == clean.length - 1) {
      return '.img';
    }
    return clean.substring(dot);
  }
}
