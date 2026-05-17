import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/api_constants.dart';

class SettingsProvider extends ChangeNotifier {
  late SharedPreferences _prefs;

  String _defaultQuality = '1080';
  String _defaultMode = 'auto';
  String _defaultAudioFormat = 'mp3';
  String _cobaltBaseUrl = ApiConstants.defaultCobaltBaseUrl;
  String _youtubeApiUrl = ApiConstants.defaultYoutubeApiUrl;
  String _youtubeApiKey = '';
  bool _useV2UI = false;

  String get defaultQuality => _defaultQuality;
  String get defaultMode => _defaultMode;
  String get defaultAudioFormat => _defaultAudioFormat;
  String get cobaltBaseUrl => _cobaltBaseUrl;
  String get youtubeApiUrl => _youtubeApiUrl;
  String get youtubeApiKey => _youtubeApiKey;
  bool get useV2UI => _useV2UI;

  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    _defaultQuality = _prefs.getString('default_quality') ?? '1080';
    _defaultMode = _prefs.getString('default_mode') ?? 'auto';
    _defaultAudioFormat = _prefs.getString('default_audio_format') ?? 'mp3';
    _cobaltBaseUrl = _prefs.getString('cobalt_base_url') ?? ApiConstants.defaultCobaltBaseUrl;
    _youtubeApiUrl = _prefs.getString('youtube_api_url') ?? ApiConstants.defaultYoutubeApiUrl;
    _youtubeApiKey = _prefs.getString('youtube_api_key') ?? '';
    // Force V1 as default — remove any previously saved V2 preference
    await _prefs.remove('use_v2_ui');
    _useV2UI = false;
    notifyListeners();
  }

  Future<void> setDefaultQuality(String quality) async {
    _defaultQuality = quality;
    await _prefs.setString('default_quality', quality);
    notifyListeners();
  }

  Future<void> setDefaultMode(String mode) async {
    _defaultMode = mode;
    await _prefs.setString('default_mode', mode);
    notifyListeners();
  }

  Future<void> setDefaultAudioFormat(String format) async {
    _defaultAudioFormat = format;
    await _prefs.setString('default_audio_format', format);
    notifyListeners();
  }

  Future<void> setCobaltBaseUrl(String url) async {
    _cobaltBaseUrl = url;
    await _prefs.setString('cobalt_base_url', url);
    notifyListeners();
  }

  Future<void> resetCobaltBaseUrl() async {
    _cobaltBaseUrl = ApiConstants.defaultCobaltBaseUrl;
    await _prefs.remove('cobalt_base_url');
    notifyListeners();
  }

  Future<void> setYoutubeApiUrl(String url) async {
    _youtubeApiUrl = url;
    await _prefs.setString('youtube_api_url', url);
    notifyListeners();
  }

  Future<void> setYoutubeApiKey(String key) async {
    _youtubeApiKey = key;
    await _prefs.setString('youtube_api_key', key);
    notifyListeners();
  }

  Future<void> setUseV2UI(bool value) async {
    _useV2UI = value;
    await _prefs.setBool('use_v2_ui', value);
    notifyListeners();
  }

  Future<void> clearYoutubeApi() async {
    _youtubeApiUrl = '';
    _youtubeApiKey = '';
    await _prefs.remove('youtube_api_url');
    await _prefs.remove('youtube_api_key');
    notifyListeners();
  }
}
