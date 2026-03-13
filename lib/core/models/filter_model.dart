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
    // ── Dream 그룹 (벚꽃 배경) ──────────────────────────────────
    FilterModel(
      id: 'dream',
      name: 'Dream',
      category: FilterCategory.aesthetic,
      lutFileName: 'dream.cube',
      description: '몽환적 보랏빛 안개 감성',
      isPro: false,
      isNew: true,
    ),
    FilterModel(
      id: 'peach',
      name: 'Peach',
      category: FilterCategory.warm,
      lutFileName: 'peach.cube',
      description: '따뜻한 핑크톤 복숭아',
      isPro: true,
    ),
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
    FilterModel(
      id: 'kodak_soft',
      name: 'Kodak Soft',
      category: FilterCategory.film,
      lutFileName: 'kodak_soft.cube',
      description: '코닥 필름 부드러움',
      isPro: true,
    ),
    FilterModel(
      id: 'milk',
      name: 'Milk',
      category: FilterCategory.warm,
      lutFileName: 'milk.cube',
      description: '부드러운 화이트 우유빛',
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
      id: 'vivid',
      name: 'Vivid',
      category: FilterCategory.aesthetic,
      lutFileName: 'vivid.cube',
      description: '선명하고 진한 채도',
      isPro: true,
      isNew: true,
    ),
    FilterModel(
      id: 'ice',
      name: 'Ice',
      category: FilterCategory.cool,
      lutFileName: 'ice.cube',
      description: '겨울 아침 깨끗함',
      isPro: true,
    ),

    // ── 그룹 E (컬리 웨이브, 화이트 티, 실내) ── cream 대표
    FilterModel(
      id: 'cream',
      name: 'Cream',
      category: FilterCategory.warm,
      lutFileName: 'cream.cube',
      description: '크림색 따뜻한 오후',
      isPro: false,
    ),
    FilterModel(
      id: 'disposable',
      name: 'Lomo',
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

    // ── 그룹 B (단발, 화이트 캐미, 야외)
    FilterModel(
      id: 'butter',
      name: 'Butter',
      category: FilterCategory.warm,
      lutFileName: 'butter.cube',
      description: '노란빛 감성 포근함',
      isPro: true,
    ),
    FilterModel(
      id: 'film98',
      name: 'Film98',
      category: FilterCategory.film,
      lutFileName: 'film98.cube',
      description: '90년대 필름 감성',
      isPro: false,
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

    // ── 그룹 D (긴 직모, 블루셔츠, 화이트 스튜디오)
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
      id: 'winter',
      name: 'Winter',
      category: FilterCategory.cool,
      lutFileName: 'winter.cube',
      description: '겨울 아침 청량함',
      isPro: true,
      isNew: true,
    ),
    FilterModel(
      id: 'dusty_blue',
      name: 'Dusty Blue',
      category: FilterCategory.aesthetic,
      lutFileName: 'dusty_blue.cube',
      description: '먼지낀 파란색 빈티지',
      isPro: true,
    ),

    // ── 그룹 A (긴 웨이브, 오프숄더, 보케) ── mood 대표
    FilterModel(
      id: 'mood',
      name: 'Mood',
      category: FilterCategory.warm,
      lutFileName: 'mood.cube',
      description: 'Like it! 시그니처 — 따뜻한 드리미 필름',
      isPro: false,
      isNew: true,
    ),
    FilterModel(
      id: 'soft_pink',
      name: 'Soft Pink',
      category: FilterCategory.aesthetic,
      lutFileName: 'soft_pink.cube',
      description: '인스타 핑크 감성',
      isPro: false,
    ),
    FilterModel(
      id: 'blossom',
      name: 'Blossom',
      category: FilterCategory.aesthetic,
      lutFileName: 'blossom.cube',
      description: '벚꽃 핑크 봄 감성',
      isPro: true,
      isNew: true,
    ),

    // ── 그룹 C (긴 웨이브 브라운, 베이지 스웨터, 골든 보케)
    FilterModel(
      id: 'honey',
      name: 'Honey',
      category: FilterCategory.warm,
      lutFileName: 'honey.cube',
      description: '골든아워 꿀빛',
      isPro: true,
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
      id: 'pale',
      name: 'Pale',
      category: FilterCategory.cool,
      lutFileName: 'pale.cube',
      description: '창백한 쿨톤 무드',
      isPro: true,
      isNew: true,
    ),
  ];

  /// 필터별 기본 강도
  /// intensity 1.0 = LUT 2회 적용(2배 강도), 0.5 = LUT 1회
  /// 사용자가 슬라이더로 조정 시 이 값이 덮어씌워짐
  static const Map<String, double> defaultIntensities = {
    // Warm — 따뜻한 계열
    'mood':        0.70, // 시그니처 드리미 필름 — 자연스러운 따뜻함
    'milk':        0.55, // 부드러운 우유빛 — 너무 강하면 하얗게 날림
    'cream':       0.65, // 크림 따뜻한 오후 — 은은한 베이지
    'butter':      0.65, // 노란빛 포근함 — 과하면 노란색 캐스트
    'honey':       0.70, // 골든아워 꿀빛 — 선명한 골든톤
    'peach':       0.65, // 핑크톤 복숭아 — 자연스러운 핑크
    'latte':       0.65, // 카페라떼 브라운 — 따뜻한 브라운톤
    'mocha':       0.65, // 모카 브라운 — 진한 브라운
    // Cool — 쿨톤 계열
    'sky':         0.65, // 맑은 하늘 청량 — 은은한 블루
    'ocean':       0.70, // 깊은 바다 차가움 — 선명한 딥블루
    'mint':        0.65, // 민트초코 시원함 — 쿨한 민트
    'cloud':       0.60, // 하얀 구름 부드러움 — 너무 강하면 탁해짐
    'ice':         0.65, // 겨울 아침 깨끗함 — 선명한 쿨화이트
    'pale':        0.55, // 창백한 쿨톤 — 연하게 써야 자연스러움
    'winter':      0.65, // 겨울 아침 청량함 — 맑은 쿨톤
    // Film — 필름 계열 (효과가 뚜렷해야 필름느낌)
    'film98':      0.75, // 90년대 필름 — 강하게 써야 감성 살아남
    'film03':      0.75, // Y2K 2003년 — 선명한 Y2K 색감
    'disposable':  0.75, // 일회용 카메라 — 특유의 채도/그레인
    'retro_ccd':   0.75, // 구형 디카 색감 — 진한 레트로
    'kodak_soft':  0.70, // 코닥 필름 부드러움 — 부드럽지만 필름감
    // Aesthetic — 감성 계열
    'dream':       0.65, // 몽환적 보랏빛 안개 — 너무 강하면 보라로 뭉침
    'lavender':    0.65, // 라벤더 보라빛 — 은은한 라벤더
    'soft_pink':   0.60, // 인스타 핑크 — 연하게 써야 자연스러움
    'dusty_blue':  0.65, // 먼지낀 파란색 빈티지 — 빈티지 블루
    'blossom':     0.65, // 벚꽃 핑크 봄 — 은은한 벚꽃빛
    'vivid':       0.70, // 선명하고 진한 채도 — 너무 강하면 인공적으로 보임
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
