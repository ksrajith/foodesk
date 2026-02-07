import 'package:cloud_firestore/cloud_firestore.dart';

const String _settingsDocId = 'settings';

/// App-wide settings (meal price visibility, meal limits). Stored in app_settings/settings.
Future<Map<String, dynamic>> getAppSettings() async {
  final snap = await FirebaseFirestore.instance.collection('app_settings').doc(_settingsDocId).get();
  if (!snap.exists || snap.data() == null) {
    return {
      'showMealPricesToCustomers': true,
      'mealLimits': {'Breakfast': 2, 'Lunch': 1, 'Dinner': 2},
    };
  }
  final data = snap.data()!;
  return {
    'showMealPricesToCustomers': data['showMealPricesToCustomers'] as bool? ?? true,
    'mealLimits': data['mealLimits'] is Map
        ? Map<String, int>.from(
            (data['mealLimits'] as Map).map((k, v) => MapEntry(k.toString(), (v is int) ? v : (v is num ? v.toInt() : 2))),
          )
        : {'Breakfast': 2, 'Lunch': 1, 'Dinner': 2},
  };
}

Stream<DocumentSnapshot<Map<String, dynamic>>> appSettingsStream() {
  return FirebaseFirestore.instance.collection('app_settings').doc(_settingsDocId).snapshots();
}

/// Returns max allowed quantity for [mealType] per customer per day (default 2 if not set).
Future<int> getMealLimitForType(String mealType) async {
  final settings = await getAppSettings();
  final limits = settings['mealLimits'] as Map<String, int>? ?? {};
  return limits[mealType] ?? 2;
}

/// Returns true if meal prices should be shown to customers.
Future<bool> getShowMealPricesToCustomers() async {
  final settings = await getAppSettings();
  return settings['showMealPricesToCustomers'] as bool? ?? true;
}
