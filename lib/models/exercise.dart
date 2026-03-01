class ExerciseCategory {
  final int id;
  final String name;

  ExerciseCategory({required this.id, required this.name});

  factory ExerciseCategory.fromJson(Map<String, dynamic> json) {
    return ExerciseCategory(
      id: json['id'],
      name: json['name'],
    );
  }
}

class Muscle {
  final int id;
  final String name;
  final String nameEn;
  final bool isFront;
  final String imageUrlMain;
  final String imageUrlSecondary;

  Muscle({
    required this.id,
    required this.name,
    required this.nameEn,
    required this.isFront,
    required this.imageUrlMain,
    required this.imageUrlSecondary,
  });

  factory Muscle.fromJson(Map<String, dynamic> json) {
    return Muscle(
      id: json['id'],
      name: json['name'] ?? '',
      nameEn: json['name_en'] ?? '',
      isFront: json['is_front'] ?? true,
      imageUrlMain: json['image_url_main'] ?? '',
      imageUrlSecondary: json['image_url_secondary'] ?? '',
    );
  }

  String get displayName => nameEn.isNotEmpty ? nameEn : name;
}

class Equipment {
  final int id;
  final String name;

  Equipment({required this.id, required this.name});

  factory Equipment.fromJson(Map<String, dynamic> json) {
    return Equipment(
      id: json['id'],
      name: json['name'],
    );
  }
}

class ExerciseImage {
  final int id;
  final String image;
  final bool isMain;

  ExerciseImage({
    required this.id,
    required this.image,
    required this.isMain,
  });

  factory ExerciseImage.fromJson(Map<String, dynamic> json) {
    return ExerciseImage(
      id: json['id'],
      image: json['image'] ?? '',
      isMain: json['is_main'] ?? false,
    );
  }
}

class Exercise {
  final int id;
  final String uuid;
  final String name;
  final String description;
  final int categoryId;
  final String categoryName;
  final List<Muscle> muscles;
  final List<Muscle> musclesSecondary;
  final List<Equipment> equipment;
  final List<ExerciseImage> images;

  Exercise({
    required this.id,
    required this.uuid,
    required this.name,
    required this.description,
    required this.categoryId,
    required this.categoryName,
    required this.muscles,
    required this.musclesSecondary,
    required this.equipment,
    required this.images,
  });

  factory Exercise.fromExerciseInfo(Map<String, dynamic> json) {
    // Parse translations for English name/description
    String name = 'Exercise #${json['id']}';
    String description = '';
    if (json['translations'] != null) {
      for (var t in json['translations']) {
        if (t['language'] == 2) {
          name = t['name'] ?? name;
          description = t['description'] ?? '';
          break;
        }
      }
      // Fallback: use first translation if no English found
      if (name == 'Exercise #${json['id']}' &&
          (json['translations'] as List).isNotEmpty) {
        var first = json['translations'][0];
        name = first['name'] ?? name;
        description = first['description'] ?? '';
      }
    }

    // Parse category
    String categoryName = '';
    int categoryId = 0;
    if (json['category'] != null) {
      categoryId = json['category']['id'] ?? 0;
      categoryName = json['category']['name'] ?? '';
    }

    // Parse muscles
    List<Muscle> muscles = [];
    if (json['muscles'] != null) {
      muscles = (json['muscles'] as List)
          .map((m) => Muscle.fromJson(m))
          .toList();
    }

    List<Muscle> musclesSecondary = [];
    if (json['muscles_secondary'] != null) {
      musclesSecondary = (json['muscles_secondary'] as List)
          .map((m) => Muscle.fromJson(m))
          .toList();
    }

    // Parse equipment
    List<Equipment> equipment = [];
    if (json['equipment'] != null) {
      equipment = (json['equipment'] as List)
          .map((e) => Equipment.fromJson(e))
          .toList();
    }

    // Parse images
    List<ExerciseImage> images = [];
    if (json['images'] != null) {
      images = (json['images'] as List)
          .map((i) => ExerciseImage.fromJson(i))
          .toList();
    }

    // Strip HTML from description
    description = description.replaceAll(RegExp(r'<[^>]*>'), '');

    return Exercise(
      id: json['id'],
      uuid: json['uuid'] ?? '',
      name: name,
      description: description,
      categoryId: categoryId,
      categoryName: categoryName,
      muscles: muscles,
      musclesSecondary: musclesSecondary,
      equipment: equipment,
      images: images,
    );
  }

  String? get mainImageUrl {
    for (var img in images) {
      if (img.isMain) return img.image;
    }
    if (images.isNotEmpty) return images.first.image;
    return null;
  }
}
