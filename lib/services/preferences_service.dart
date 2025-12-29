import 'package:shared_preferences/shared_preferences.dart';

class PreferencesService {
  static final PreferencesService instance = PreferencesService._();
  PreferencesService._();

  // Keys
  static const String _keyNotifNewProperties = 'notif_new_properties';
  static const String _keyNotifPriceUpdates = 'notif_price_updates';
  static const String _keyNotifMessages = 'notif_messages';
  static const String _keyEmailWeeklyDigest = 'email_weekly_digest';
  static const String _keyEmailPromotional = 'email_promotional';
  static const String _keyPrivacyProfileVisible = 'privacy_profile_visible';
  static const String _keyPrivacyShowContact = 'privacy_show_contact';
  static const String _keyPrivacyActivityStatus = 'privacy_activity_status';
  static const String _keyLanguage = 'language';
  static const String _keyTheme = 'theme';

  // Notification Settings
  Future<bool> getNotificationNewProperties() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyNotifNewProperties) ?? true;
  }

  Future<void> setNotificationNewProperties(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyNotifNewProperties, value);
  }

  Future<bool> getNotificationPriceUpdates() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyNotifPriceUpdates) ?? true;
  }

  Future<void> setNotificationPriceUpdates(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyNotifPriceUpdates, value);
  }

  Future<bool> getNotificationMessages() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyNotifMessages) ?? true;
  }

  Future<void> setNotificationMessages(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyNotifMessages, value);
  }

  // Email Notification Settings
  Future<bool> getEmailWeeklyDigest() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyEmailWeeklyDigest) ?? false;
  }

  Future<void> setEmailWeeklyDigest(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyEmailWeeklyDigest, value);
  }

  Future<bool> getEmailPromotional() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyEmailPromotional) ?? false;
  }

  Future<void> setEmailPromotional(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyEmailPromotional, value);
  }

  // Privacy Settings
  Future<bool> getPrivacyProfileVisible() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyPrivacyProfileVisible) ?? true;
  }

  Future<void> setPrivacyProfileVisible(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyPrivacyProfileVisible, value);
  }

  Future<bool> getPrivacyShowContact() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyPrivacyShowContact) ?? true;
  }

  Future<void> setPrivacyShowContact(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyPrivacyShowContact, value);
  }

  Future<bool> getPrivacyActivityStatus() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyPrivacyActivityStatus) ?? false;
  }

  Future<void> setPrivacyActivityStatus(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyPrivacyActivityStatus, value);
  }

  // Language Settings
  Future<String> getLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyLanguage) ?? 'en';
  }

  Future<void> setLanguage(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLanguage, value);
  }

  // Theme Settings
  Future<String> getTheme() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyTheme) ?? 'light';
  }

  Future<void> setTheme(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyTheme, value);
  }

  // Clear all preferences
  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}
