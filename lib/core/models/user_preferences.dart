import 'package:hive_flutter/hive_flutter.dart';

part 'user_preferences.g.dart';

@HiveType(typeId: 3)
class UserPreferences extends HiveObject {
  @HiveField(0)
  bool hasSeenOnboarding;

  @HiveField(1)
  String? lastUsedFilterId;

  @HiveField(2)
  bool isProUser;

  @HiveField(3)
  Map<String, double> filterIntensities; // filterId → intensity

  @HiveField(4)
  List<String> favoriteFilterIds;

  @HiveField(5)
  bool hasSeenDreamyGlowTip;

  @HiveField(6)
  bool hasSeenSwipeHint;

  @HiveField(7)
  bool hasSeenEditHint;

  @HiveField(8)
  int totalPhotosCapture; // 촬영 횟수 (리텐션 분석용)

  UserPreferences({
    this.hasSeenOnboarding = false,
    this.lastUsedFilterId,
    this.isProUser = false,
    Map<String, double>? filterIntensities,
    List<String>? favoriteFilterIds,
    this.hasSeenDreamyGlowTip = false,
    this.hasSeenSwipeHint = false,
    this.hasSeenEditHint = false,
    this.totalPhotosCapture = 0,
  })  : filterIntensities = filterIntensities ?? {},
        favoriteFilterIds = favoriteFilterIds ?? [];

  double intensityFor(String filterId) =>
      filterIntensities[filterId] ?? 1.0;

  void setIntensity(String filterId, double intensity) {
    filterIntensities[filterId] = intensity;
    save();
  }

  void toggleFavorite(String filterId) {
    if (favoriteFilterIds.contains(filterId)) {
      favoriteFilterIds.remove(filterId);
    } else {
      favoriteFilterIds.add(filterId);
    }
    save();
  }
}
