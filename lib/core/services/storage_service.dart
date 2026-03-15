import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/filter_model.dart';
import '../models/effect_model.dart';
import '../models/user_preferences.dart';

class StorageService {
  static const String _prefsBoxName = 'user_preferences';

  static late Box<UserPreferences> _prefsBox;

  static Future<void> init() async {
    debugPrint('[StorageService] Hive.initFlutter() 호출');
    await Hive.initFlutter();

    // 어댑터 등록 (hive_generator가 생성한 어댑터)
    Hive.registerAdapter(FilterCategoryAdapter());
    Hive.registerAdapter(FilterModelAdapter());
    Hive.registerAdapter(EffectTypeAdapter());
    Hive.registerAdapter(UserPreferencesAdapter());
    debugPrint('[StorageService] 어댑터 등록 완료');

    // Box 열기
    _prefsBox = await Hive.openBox<UserPreferences>(_prefsBoxName);
    debugPrint('[StorageService] Box 열기 완료 isEmpty=${_prefsBox.isEmpty}');

    // 최초 실행 시 기본값 생성
    if (_prefsBox.isEmpty) {
      await _prefsBox.add(UserPreferences());
      debugPrint('[StorageService] 기본 UserPreferences 생성');
    } else {
      debugPrint('[StorageService] 기존 UserPreferences 로드 완료');
      // 강도 마이그레이션: 저장값이 새 기본값과 다르면 제거 → 새 기본값 적용
      // 기본값을 내렸으므로 저장값 > 0.5(구 기본값 범위)인 경우 이전 기본값으로 판단 후 초기화
      final p = _prefsBox.getAt(0)!;
      bool changed = false;
      for (final entry in FilterData.defaultIntensities.entries) {
        final stored = p.filterIntensities[entry.key];
        if (stored != null && stored > 0.5) {
          p.filterIntensities.remove(entry.key);
          changed = true;
        }
      }
      if (changed) {
        await p.save();
        debugPrint('[StorageService] 필터 강도 마이그레이션 완료 (기본값 하향)');
      }
    }
  }

  static UserPreferences get prefs => _prefsBox.getAt(0)!;

  static Future<void> close() async {
    await Hive.close();
  }
}
