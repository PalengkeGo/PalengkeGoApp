import 'package:flutter/material.dart';

class RecipeIngredient {
  final String name;
  final String description;
  final String? imageUrl;

  const RecipeIngredient({
    required this.name,
    required this.description,
    this.imageUrl,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      if (imageUrl != null) 'imageUrl': imageUrl,
    };
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
