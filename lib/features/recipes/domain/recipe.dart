import 'package:flutter/material.dart';

/// A market substitute offered for a [RecipeIngredient]. Substitutes are read
/// from the recipe JSON/DB and serialized so the dynamic calorie total can
/// adapt when a substitute is chosen.
class RecipeSubstitute {
  final String name;
  final String description;
  final String? imageUrl;

  /// Energy contribution (kcal) of this substitute for its portion. When a
  /// substitute is chosen, it replaces the ingredient's own [RecipeIngredient
  /// .calorie] in the recipe's dynamic total.
  final int? calorie;

  const RecipeSubstitute({
    required this.name,
    required this.description,
    this.imageUrl,
    this.calorie,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      if (imageUrl != null) 'imageUrl': imageUrl,
      if (calorie != null) 'calorie': calorie,
    };
  }

  factory RecipeSubstitute.fromMap(Map<String, dynamic> map) {
    return RecipeSubstitute(
      name: map['name'] as String? ?? '',
      description: map['description'] as String? ?? '',
      imageUrl: map['image_url'] as String? ?? map['imageUrl'] as String?,
      calorie: (map['calorie'] as num?)?.toInt(),
    );
  }
}

class RecipeIngredient {
  final String name;
  final String description;
  final String? imageUrl;

  /// Energy contribution (kcal) of this ingredient for its described portion.
  /// Used to compute the recipe's dynamic [Recipe.energyLabel]; substitutes
  /// with their own [RecipeSubstitute.calorie] replace it when chosen.
  final int? calorie;

  /// Optional market substitutes offered when this ingredient is ticked.
  final List<RecipeSubstitute>? substitutes;

  const RecipeIngredient({
    required this.name,
    required this.description,
    this.imageUrl,
    this.calorie,
    this.substitutes,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      if (imageUrl != null) 'imageUrl': imageUrl,
      if (calorie != null) 'calorie': calorie,
      if (substitutes != null)
        'substitutes': substitutes!.map((s) => s.toMap()).toList(),
    };
  }

  factory RecipeIngredient.fromMap(Map<String, dynamic> map) {
    return RecipeIngredient(
      name: map['name'] as String? ?? '',
      description: map['description'] as String? ?? '',
      imageUrl: map['image_url'] as String? ?? map['imageUrl'] as String?,
      calorie: (map['calorie'] as num?)?.toInt(),
      substitutes: (map['substitutes'] as List?)
          ?.map((e) => RecipeSubstitute.fromMap((e as Map).cast<String, dynamic>()))
          .toList(),
    );
  }
}

class RecipeStep {
  final String title;
  final String description;

  const RecipeStep({required this.title, required this.description});

  Map<String, dynamic> toMap() {
    return {'title': title, 'description': description};
  }
}

class Recipe {
  const Recipe({
    required this.id,
    required this.title,
    required this.category,
    required this.time,
    required this.difficulty,
    required this.imageUrl,
    required this.backgroundColor,
    this.serving,
    this.calories,
    this.ingredients,
    this.steps,
  });

  /// Stable unique identifier. Recipes are matched by [id] — never by title,
  /// since two recipes can legitimately share a title.
  final String id;

  final String title;
  final String category;
  final String time;
  final String difficulty;
  final String imageUrl;
  final Color backgroundColor;
  final String? serving;
  final String? calories;
  final List<RecipeIngredient>? ingredients;
  final List<RecipeStep>? steps;

  String get description => '$category • $difficulty • $time';

  /// Dynamic energy label. When the recipe's ingredients (or their chosen
  /// substitutes) carry calorie data, this sums them into a `NNN kcal` string;
  /// otherwise it falls back to the static [calories] value, then a sensible
  /// default. Passing [chosenSubstitutes] lets the caller reflect substitutions
  /// the user picked while ticking ingredients.
  String energyLabel([Map<String, RecipeSubstitute> chosenSubstitutes = const {}]) {
    final ings = ingredients;
    if (ings != null && ings.isNotEmpty) {
      var hasCalories = false;
      var total = 0;
      for (final ing in ings) {
        final sub = chosenSubstitutes[ing.name];
        final kcal = sub?.calorie ?? ing.calorie;
        if (kcal != null) {
          hasCalories = true;
          total += kcal;
        }
      }
      if (hasCalories) return '$total kcal';
    }
    if (calories != null && calories!.isNotEmpty) return calories!;
    return '320 kcal';
  }

  Map<String, dynamic> toDetailsMap() {
    return {
      'name': title,
      'imageUrl': imageUrl,
      'description': description,
      'time': time,
      if (serving != null) 'serving': serving,
      if (calories != null) 'calories': calories,
      if (ingredients != null)
        'ingredients': ingredients!.map((i) => i.toMap()).toList(),
      if (steps != null) 'steps': steps!.map((s) => s.toMap()).toList(),
    };
  }
}
