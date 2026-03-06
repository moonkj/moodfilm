import 'package:hive_flutter/hive_flutter.dart';
import '../models/filter_model.dart';
import '../models/effect_model.dart';
import '../models/user_preferences.dart';

class StorageService {
  static const String _prefsBoxName = 'user_preferences';

  static late Box<UserPreferences> _prefsBox;

  static Future<void> init() async {
    await Hive.initFlutter();

    // 어댑터 등록 (hive_generator가 생성한 어댑터)
    Hive.registerAdapter(FilterCategoryAdapter());
    Hive.registerAdapter(FilterModelAdapter());
    Hive.registerAdapter(EffectTypeAdapter());
    Hive.registerAdapter(UserPreferencesAdapter());

    // Box 열기
    _prefsBox = await Hive.openBox<UserPreferences>(_prefsBoxName);

    // 최초 실행 시 기본값 생성
    if (_prefsBox.isEmpty) {
      await _prefsBox.add(UserPreferences());
    }
  }

  static UserPreferences get prefs => _prefsBox.getAt(0)!;

  static Future<void> close() async {
    await Hive.close();
  }
}
