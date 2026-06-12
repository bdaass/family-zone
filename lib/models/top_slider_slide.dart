/// A hero banner slide loaded from Firebase Storage (`topSlider/{locale}/`).
class TopSliderSlide {
  final String id;
  final String imageUrl;
  final TopSliderCategory category;

  const TopSliderSlide({
    required this.id,
    required this.imageUrl,
    required this.category,
  });

  /// Filter chips to apply when the user taps this slide.
  TopSliderFilterAction? get filterAction => category.filterAction;
}

enum TopSliderCategory {
  male,
  female,
  boy,
  girl,
  sale,
  unknown;

  static TopSliderCategory fromFileStem(String stem) {
    switch (stem.toLowerCase()) {
      case 'male':
      case 'man':
        return TopSliderCategory.male;
      case 'female':
      case 'woman':
      case 'women':
        return TopSliderCategory.female;
      case 'boy':
        return TopSliderCategory.boy;
      case 'girl':
        return TopSliderCategory.girl;
      case 'solde':
      case 'sale':
      case 'soldes':
        return TopSliderCategory.sale;
      default:
        return TopSliderCategory.unknown;
    }
  }

  TopSliderFilterAction? get filterAction {
    switch (this) {
      case TopSliderCategory.male:
        return const TopSliderFilterAction(ageGroup: 'Adult', sex: 'Male');
      case TopSliderCategory.female:
        return const TopSliderFilterAction(ageGroup: 'Adult', sex: 'Female');
      case TopSliderCategory.boy:
        return const TopSliderFilterAction(ageGroup: 'Kids', sex: 'Male');
      case TopSliderCategory.girl:
        return const TopSliderFilterAction(ageGroup: 'Kids', sex: 'Female');
      case TopSliderCategory.sale:
        return const TopSliderFilterAction(saleOnly: true);
      case TopSliderCategory.unknown:
        return null;
    }
  }

  /// Storage filename stem (e.g. `Male.jpg`).
  String? get fileStem {
    switch (this) {
      case TopSliderCategory.male:
        return 'Male';
      case TopSliderCategory.female:
        return 'Female';
      case TopSliderCategory.boy:
        return 'Boy';
      case TopSliderCategory.girl:
        return 'Girl';
      case TopSliderCategory.sale:
        return 'Solde';
      case TopSliderCategory.unknown:
        return null;
    }
  }

  /// Preferred display order in the carousel.
  int get sortIndex {
    switch (this) {
      case TopSliderCategory.male:
        return 0;
      case TopSliderCategory.female:
        return 1;
      case TopSliderCategory.boy:
        return 2;
      case TopSliderCategory.girl:
        return 3;
      case TopSliderCategory.sale:
        return 4;
      case TopSliderCategory.unknown:
        return 99;
    }
  }
}

class TopSliderFilterAction {
  final String? ageGroup;
  final String? sex;
  final bool? saleOnly;

  const TopSliderFilterAction({this.ageGroup, this.sex, this.saleOnly});
}
