import 'package:hive_flutter/hive_flutter.dart';

part 'filter_model.g.dart';

@HiveType(typeId: 0)
enum FilterCategory {
  @HiveField(0)
  warm,
  @HiveField(1)
  cool,
  @HiveField(2)
  film,
  @HiveField(3)
  aesthetic,
}

@HiveType(typeId: 1)
class FilterModel extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final FilterCategory category;

  @HiveField(3)
  final String lutFileName; // e.g. 'milk.cube'

  @HiveField(4)
  final bool isPro;

  @HiveField(5)
  bool isFavorite;

  @HiveField(6)
  double lastIntensity; // 마지막 사용 강도 0.0~1.0

  @HiveField(7)
  final String? packId; // 월간 드롭 팩 소속

  @HiveField(8)
  bool isNew; // NEW 배지

  @HiveField(9)
  final String description; // 필터 설명 (예: '부드러운 화이트 우유빛')

  FilterModel({
    required this.id,
    required this.name,
    required this.category,
    required this.lutFileName,
    this.isPro = false,
    this.isFavorite = false,
    this.lastIntensity = 1.0,
    this.packId,
    this.isNew = false,
    this.description = '',
  });

  String get thumbnailAssetPath => 'assets/thumbnails/$id.jpg';

  @override
  String toString() => 'FilterModel($id, $name, isPro: $isPro)';
}

/// MVP 20종 필터 정의 (계획서 4장 기준)
class FilterData {
  FilterData._();

  static final List<FilterModel> all = [
    // ── MoodFilm 시그니처 (2종) ──────────────────────────────
    FilterModel(
      id: 'mood',
      name: 'Mood',
      category: FilterCategory.warm,
      lutFileName: 'mood.cube',
      description: 'MoodFilm 시그니처 — 따뜻한 드리미 필름',
      isPro: false,
      isNew: true,
    ),
    FilterModel(
      id: 'dream',
      name: 'Dream',
      category: FilterCategory.aesthetic,
      lutFileName: 'dream.cube',
      description: '몽환적 보랏빛 안개 감성',
      isPro: false,
      isNew: true,
    ),

    // Warm Tone (5종)
    FilterModel(
      id: 'milk',
      name: 'Milk',
      category: FilterCategory.warm,
      lutFileName: 'milk.cube',
      description: '부드러운 화이트 우유빛',
      isPro: false,
    ),
    FilterModel(
      id: 'cream',
      name: 'Cream',
      category: FilterCategory.warm,
      lutFileName: 'cream.cube',
      description: '크림색 따뜻한 오후',
      isPro: false,
    ),
    FilterModel(
      id: 'butter',
      name: 'Butter',
      category: FilterCategory.warm,
      lutFileName: 'butter.cube',
      description: '노란빛 감성 포근함',
      isPro: true,
    ),
    FilterModel(
      id: 'honey',
      name: 'Honey',
      category: FilterCategory.warm,
      lutFileName: 'honey.cube',
      description: '골든아워 꿀빛',
      isPro: true,
    ),
    FilterModel(
      id: 'peach',
      name: 'Peach',
      category: FilterCategory.warm,
      lutFileName: 'peach.cube',
      description: '따뜻한 핑크톤 복숭아',
      isPro: true,
    ),

    // Cool Tone (5종)
    FilterModel(
      id: 'sky',
      name: 'Sky',
      category: FilterCategory.cool,
      lutFileName: 'sky.cube',
      description: '맑은 하늘 청량함',
      isPro: false,
    ),
    FilterModel(
      id: 'ocean',
      name: 'Ocean',
      category: FilterCategory.cool,
      lutFileName: 'ocean.cube',
      description: '깊은 바다 차가운 감성',
      isPro: true,
    ),
    FilterModel(
      id: 'mint',
      name: 'Mint',
      category: FilterCategory.cool,
      lutFileName: 'mint.cube',
      description: '민트초코 시원한 톤',
      isPro: true,
    ),
    FilterModel(
      id: 'cloud',
      name: 'Cloud',
      category: FilterCategory.cool,
      lutFileName: 'cloud.cube',
      description: '하얀 구름 같은 부드러움',
      isPro: false,
    ),
    FilterModel(
      id: 'ice',
      name: 'Ice',
      category: FilterCategory.cool,
      lutFileName: 'ice.cube',
      description: '겨울 아침 깨끗함',
      isPro: true,
    ),

    // Film Tone (5종)
    FilterModel(
      id: 'film98',
      name: 'Film98',
      category: FilterCategory.film,
      lutFileName: 'film98.cube',
      description: '90년대 필름 감성',
      isPro: false,
    ),
    FilterModel(
      id: 'film03',
      name: 'Film03',
      category: FilterCategory.film,
      lutFileName: 'film03.cube',
      description: 'Y2K 감성 2003년',
      isPro: true,
    ),
    FilterModel(
      id: 'disposable',
      name: 'Disposable',
      category: FilterCategory.film,
      lutFileName: 'disposable.cube',
      description: '일회용 카메라 느낌',
      isPro: false,
    ),
    FilterModel(
      id: 'retro_ccd',
      name: 'Retro CCD',
      category: FilterCategory.film,
      lutFileName: 'retro_ccd.cube',
      description: '구형 디카 색감',
      isPro: true,
    ),
    FilterModel(
      id: 'kodak_soft',
      name: 'Kodak Soft',
      category: FilterCategory.film,
      lutFileName: 'kodak_soft.cube',
      description: '코닥 필름 부드러움',
      isPro: true,
    ),

    // Aesthetic (5종)
    FilterModel(
      id: 'soft_pink',
      name: 'Soft Pink',
      category: FilterCategory.aesthetic,
      lutFileName: 'soft_pink.cube',
      description: '인스타 핑크 감성',
      isPro: false,
    ),
    FilterModel(
      id: 'lavender',
      name: 'Lavender',
      category: FilterCategory.aesthetic,
      lutFileName: 'lavender.cube',
      description: '라벤더 보라빛 감성',
      isPro: false,
    ),
    FilterModel(
      id: 'dusty_blue',
      name: 'Dusty Blue',
      category: FilterCategory.aesthetic,
      lutFileName: 'dusty_blue.cube',
      description: '먼지낀 파란색 빈티지',
      isPro: true,
    ),
    FilterModel(
      id: 'cafe_mood',
      name: 'Cafe Mood',
      category: FilterCategory.aesthetic,
      lutFileName: 'cafe_mood.cube',
      description: '카페 안 따뜻한 오후',
      isPro: true,
    ),
    FilterModel(
      id: 'seoul_night',
      name: 'Seoul Night',
      category: FilterCategory.aesthetic,
      lutFileName: 'seoul_night.cube',
      description: '서울 야경 네온빛',
      isPro: true,
    ),

    // ── W11 추가 8종 ─────────────────────────────────────────
    // Warm +2
    FilterModel(
      id: 'latte',
      name: 'Latte',
      category: FilterCategory.warm,
      lutFileName: 'latte.cube',
      description: '카페라떼 브라운 따뜻함',
      isPro: true,
      isNew: true,
    ),
    FilterModel(
      id: 'mocha',
      name: 'Mocha',
      category: FilterCategory.warm,
      lutFileName: 'mocha.cube',
      description: '모카 브라운 감성',
      isPro: true,
      isNew: true,
    ),

    // Cool +2
    FilterModel(
      id: 'pale',
      name: 'Pale',
      category: FilterCategory.cool,
      lutFileName: 'pale.cube',
      description: '창백한 쿨톤 무드',
      isPro: true,
      isNew: true,
    ),
    FilterModel(
      id: 'winter',
      name: 'Winter',
      category: FilterCategory.cool,
      lutFileName: 'winter.cube',
      description: '겨울 아침 청량함',
      isPro: true,
      isNew: true,
    ),

    // Film +2
    FilterModel(
      id: 'bronze',
      name: 'Bronze',
      category: FilterCategory.film,
      lutFileName: 'bronze.cube',
      description: '구리빛 복고 필름',
      isPro: true,
      isNew: true,
    ),
    FilterModel(
      id: 'noir',
      name: 'Noir',
      category: FilterCategory.film,
      lutFileName: 'noir.cube',
      description: '흑백 감성 필름',
      isPro: true,
      isNew: true,
    ),

    // Aesthetic +2
    FilterModel(
      id: 'blossom',
      name: 'Blossom',
      category: FilterCategory.aesthetic,
      lutFileName: 'blossom.cube',
      description: '벚꽃 핑크 봄 감성',
      isPro: true,
      isNew: true,
    ),
    FilterModel(
      id: 'vivid',
      name: 'Vivid',
      category: FilterCategory.aesthetic,
      lutFileName: 'vivid.cube',
      description: '선명하고 진한 채도',
      isPro: true,
      isNew: true,
    ),
  ];

  /// 필터별 기본 강도 (최신 트렌드 기준 — 자연스럽고 은은하게)
  /// 사용자가 슬라이더로 조정 시 이 값이 덮어씌워짐
  static const Map<String, double> defaultIntensities = {
    // Signature
    'mood':        0.65,
    'dream':       0.60,
    // Warm — 피부톤 살리되 과하지 않게
    'milk':        0.55,
    'cream':       0.55,
    'butter':      0.50,
    'honey':       0.50,
    'peach':       0.55,
    // Cool — 청량하되 파랗지 않게
    'sky':         0.60,
    'ocean':       0.55,
    'mint':        0.50,
    'cloud':       0.60,
    'ice':         0.55,
    // Film — 필름 감성은 조금 더 강하게
    'film98':      0.70,
    'film03':      0.65,
    'disposable':  0.75,
    'retro_ccd':   0.65,
    'kodak_soft':  0.65,
    // Aesthetic — 색감 개성, 은은하게
    'soft_pink':   0.55,
    'lavender':    0.55,
    'dusty_blue':  0.60,
    'cafe_mood':   0.55,
    'seoul_night': 0.65,
    // W11 추가
    'latte':       0.55,
    'mocha':       0.55,
    'pale':        0.55,
    'winter':      0.60,
    'bronze':      0.65,
    'noir':        0.70,
    'blossom':     0.55,
    'vivid':       0.60,
  };

  static List<FilterModel> byCategory(FilterCategory category) =>
      all.where((f) => f.category == category).toList();

  static FilterModel? byId(String id) {
    try {
      return all.firstWhere((f) => f.id == id);
    } catch (_) {
      return null;
    }
  }
}
