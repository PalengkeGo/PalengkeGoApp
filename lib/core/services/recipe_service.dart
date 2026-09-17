import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

class RecipeIngredient {
  final String name;
  final String amount;
  final String marketSection;

  const RecipeIngredient({
    required this.name,
    required this.amount,
    required this.marketSection,
  });

  factory RecipeIngredient.fromJson(Map<String, dynamic> json) {
    return RecipeIngredient(
      name: json['name'] as String? ?? '',
      amount: json['amount'] as String? ?? '',
      marketSection: json['marketSection'] as String? ?? 'General Section',
    );
  }

  /// Scales quantity numbers inside ingredient amounts for multiple servings.
  /// E.g. "150g pork ribs" x 4 -> "600g pork ribs", "1/2 medium tomato" x 4 -> "2 medium tomato"
  RecipeIngredient scaled(double scaleFactor) {
    if (scaleFactor == 1.0) return this;
    final String newName = _scaleTextNumbers(name, scaleFactor);
    final String newAmount = _scaleTextNumbers(amount, scaleFactor);
    return RecipeIngredient(
      name: newName,
      amount: newAmount,
      marketSection: marketSection,
    );
  }

  static String _scaleTextNumbers(String text, double scaleFactor) {
    return text.replaceAllMapped(
      RegExp(r'(\d+/\d+|\d+(?:\.\d+)?)(?:\s*-\s*(\d+(?:\.\d+)?))?'),
      (match) {
        final group1 = match.group(1)!;
        final group2 = match.group(2);

        final double num1 = _parseNum(group1);
        final double scaled1 = num1 * scaleFactor;

        if (group2 != null) {
          final double num2 = _parseNum(group2);
          final double scaled2 = num2 * scaleFactor;
          return '${_formatNum(scaled1)}-${_formatNum(scaled2)}';
        }
        return _formatNum(scaled1);
      },
    );
  }

  static double _parseNum(String str) {
    if (str.contains('/')) {
      final parts = str.split('/');
      if (parts.length == 2) {
        final n = double.tryParse(parts[0]) ?? 0;
        final d = double.tryParse(parts[1]) ?? 1;
        return d != 0 ? n / d : 0;
      }
    }
    return double.tryParse(str) ?? 1.0;
  }

  static String _formatNum(double num) {
    if (num % 1 == 0) {
      return num.toInt().toString();
    } else {
      return num.toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '');
    }
  }
}

class Recipe {
  final String id;
  final String title;
  final String description;
  final int prepTimeMinutes;
  final int cookTimeMinutes;
  final int servings;
  final String category;
  final bool isLocalBicolDish;
  final List<RecipeIngredient> ingredients;
  final List<String> instructions;

  const Recipe({
    required this.id,
    required this.title,
    required this.description,
    required this.prepTimeMinutes,
    required this.cookTimeMinutes,
    required this.servings,
    required this.category,
    required this.isLocalBicolDish,
    required this.ingredients,
    required this.instructions,
  });

  /// Returns scaled ingredients for [targetServings] people (base recipe is for [servings] person/s).
  List<RecipeIngredient> getScaledIngredients(int targetServings) {
    if (targetServings <= 0 || servings <= 0 || targetServings == servings) {
      return ingredients;
    }
    final double scaleFactor = targetServings / servings;
    return ingredients.map((ing) => ing.scaled(scaleFactor)).toList();
  }

  factory Recipe.fromJson(Map<String, dynamic> json) {
    return Recipe(
      id: json['id']?.toString() ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      prepTimeMinutes: json['prepTimeMinutes'] as int? ?? 15,
      cookTimeMinutes: json['cookTimeMinutes'] as int? ?? 30,
      servings: json['servings'] as int? ?? 4,
      category: json['category'] as String? ?? 'Main Dish',
      isLocalBicolDish: json['isLocalBicolDish'] as bool? ?? false,
      ingredients: (json['ingredients'] as List<dynamic>?)
              ?.map((e) => RecipeIngredient.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      instructions: (json['instructions'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
    );
  }
}

class RecipeService {
  final http.Client _client;
  final String? _spoonacularApiKey;

  RecipeService({
    http.Client? client,
    String? spoonacularApiKey,
  })  : _client = client ?? http.Client(),
        _spoonacularApiKey = spoonacularApiKey ??
            const String.fromEnvironment('SPOONACULAR_API_KEY');

  /// Load local curated Filipino/Bicolano recipes from assets/data/recipes.json
  Future<List<Recipe>> loadLocalCuratedRecipes() async {
    try {
      final String raw =
          await rootBundle.loadString('assets/data/recipes.json');
      final List<dynamic> parsed = jsonDecode(raw) as List<dynamic>;
      return parsed
          .map((item) => Recipe.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Search recipes by ingredients using Spoonacular API + Fallback to Local Database
  Future<List<Recipe>> searchByIngredients(List<String> ingredients) async {
    final localRecipes = await loadLocalCuratedRecipes();

    if (_spoonacularApiKey == null || _spoonacularApiKey.isEmpty) {
      return _filterLocalByIngredients(localRecipes, ingredients);
    }

    try {
      final queryParams = ingredients.join(',');
      final url = Uri.parse(
          'https://api.spoonacular.com/recipes/findByIngredients?ingredients=$queryParams&number=5&apiKey=$_spoonacularApiKey');
      
      final response = await _client.get(url).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final List<dynamic> remoteData = jsonDecode(response.body);
        final remoteRecipes = remoteData.map((item) {
          return Recipe(
            id: item['id'].toString(),
            title: item['title'] as String? ?? 'Recipe',
            description: 'Spoonacular suggested recipe based on cart ingredients.',
            prepTimeMinutes: 15,
            cookTimeMinutes: 25,
            servings: 4,
            category: 'Suggested Dish',
            isLocalBicolDish: false,
            ingredients: (item['usedIngredients'] as List<dynamic>?)
                    ?.map((i) => RecipeIngredient(
                          name: i['name'] as String? ?? '',
                          amount: '${i['amount']} ${i['unit']}',
                          marketSection: 'Wet Market',
                        ))
                    .toList() ??
                [],
            instructions: ['Follow recipe steps on Spoonacular.'],
          );
        }).toList();

        // Surface local Bicolano dishes first, followed by Spoonacular results
        final filteredLocal = _filterLocalByIngredients(localRecipes, ingredients);
        return [...filteredLocal, ...remoteRecipes];
      }
    } catch (_) {
      // Fallback to local curated database on network error/timeout
    }

    return _filterLocalByIngredients(localRecipes, ingredients);
  }

  List<Recipe> _filterLocalByIngredients(List<Recipe> recipes, List<String> userIngredients) {
    if (userIngredients.isEmpty) return recipes;
    final lowerUserIngs = userIngredients.map((e) => e.toLowerCase()).toList();

    final matched = recipes.where((recipe) {
      return recipe.ingredients.any((ing) =>
          lowerUserIngs.any((u) => ing.name.toLowerCase().contains(u)));
    }).toList();

    return matched.isNotEmpty ? matched : recipes;
  }
}
