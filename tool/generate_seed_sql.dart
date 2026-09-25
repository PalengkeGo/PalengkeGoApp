// ignore_for_file: avoid_print, unused_local_variable, unnecessary_brace_in_string_interps, prefer_const_constructors
import 'dart:io';
import 'dart:convert';

/// Parses the extracted breakfast.txt and ulam.txt into structured recipes
/// and generates a Supabase SQL migration for bulk insert.

class ParsedRecipe {
  final String title;
  final String category;
  final String difficulty;
  final String servings;
  final String calories;
  final String description;
  final List<ParsedIngredient> ingredients;
  final List<ParsedStep> steps;

  ParsedRecipe({
    required this.title,
    required this.category,
    required this.difficulty,
    required this.servings,
    required this.calories,
    required this.description,
    required this.ingredients,
    required this.steps,
  });

  Map<String, dynamic> toJson() => {
    'title': title,
    'category': category,
    'difficulty': difficulty,
    'serving': servings,
    'calories': calories,
    'description': description,
    'ingredients': ingredients.map((i) => i.toJson()).toList(),
    'steps': steps.map((s) => s.toJson()).toList(),
  };
}

class ParsedIngredient {
  final String name;
  final String description;
  final String? imageUrl;

  ParsedIngredient({required this.name, required this.description, this.imageUrl});

  Map<String, dynamic> toJson() => {
    'name': name,
    'description': description,
    if (imageUrl != null) 'image_url': imageUrl,
  };
}

class ParsedStep {
  final String title;
  final String description;

  ParsedStep({required this.title, required this.description});

  Map<String, dynamic> toJson() => {'title': title, 'description': description};
}

class ParsedRecipeWithIndex {
  final ParsedRecipe recipe;
  final int endIndex;

  ParsedRecipeWithIndex({required this.recipe, required this.endIndex});
}

void main() async {
  final breakfastText = File('tool/extracted/breakfast.txt').readAsStringSync();
  final ulamText = File('tool/extracted/ulam.txt').readAsStringSync();

  final breakfastRecipes = parseRecipes(breakfastText, 'breakfast');
  final ulamRecipes = parseRecipes(ulamText, 'ulam');

  // Deduplicate by title (case-insensitive)
  final seen = <String>{};
  final allRecipes = <ParsedRecipe>[];

  for (final r in [...breakfastRecipes, ...ulamRecipes]) {
    final key = r.title.toLowerCase().trim();
    if (!seen.contains(key)) {
      seen.add(key);
      allRecipes.add(r);
    }
  }

  print('Total unique recipes: ${allRecipes.length}');
  print('Breakfast: ${breakfastRecipes.length}, Ulam: ${ulamRecipes.length}');

  // Generate SQL
  final sql = generateSqlMigration(allRecipes);
  File('supabase/migrations/20260816000001_seed_bulk_recipes.sql').writeAsStringSync(sql);
  print('Generated migration file');

  // Also output JSON for debugging
  File('tool/generated_recipes.json').writeAsStringSync(
    const JsonEncoder.withIndent('  ').convert(allRecipes.map((r) => r.toJson()).toList())
  );
}

List<ParsedRecipe> parseRecipes(String text, String source) {
  final lines = text.split('\n');
  final recipes = <ParsedRecipe>[];

  int i = 0;
  while (i < lines.length) {
    final line = lines[i].trim();

    // Match recipe header: "N. Title" or "N. Title\nRegion: ..."
    final headerMatch = RegExp(r'^(\d+)\.\s*(.+)$').firstMatch(line);
    if (headerMatch == null) {
      i++;
      continue;
    }

    final recipeNum = int.parse(headerMatch.group(1)!);

    // Skip if this looks like a step number inside a recipe (e.g., "1. Heat oil...")
    // Recipe numbers should be sequential and have region/category on next lines
    if (recipeNum > 71 || (source == 'breakfast' && recipeNum > 50)) {
      i++;
      continue;
    }

    // Look ahead to confirm this is a recipe header (next lines have Region/Category)
    bool isRecipeHeader = false;
    for (int j = i + 1; j < min(i + 5, lines.length); j++) {
      if (lines[j].contains('Region:') || lines[j].contains('Category:') || lines[j].contains('Difficulty:')) {
        isRecipeHeader = true;
        break;
      }
    }
    if (!isRecipeHeader) {
      i++;
      continue;
    }

    // Parse the recipe block
    final recipe = parseRecipeBlock(lines, i, source);
    if (recipe != null) {
      recipes.add(recipe.recipe);
      i = recipe.endIndex;
    } else {
      i++;
    }
  }

  return recipes;
}

ParsedRecipeWithIndex? parseRecipeBlock(List<String> lines, int startIndex, String source) {
  int i = startIndex;
  final headerLine = lines[i].trim();
  final headerMatch = RegExp(r'^(\d+)\.\s*(.+)$').firstMatch(headerLine);
  if (headerMatch == null) return null;

  var title = headerMatch.group(2)!.trim();
  i++;

  String region = '';
  String category = '';
  String difficulty = 'Easy';
  String servings = '1 person';
  String calories = '300 kcal';
  String description = '';

  // Parse metadata lines
  while (i < lines.length && lines[i].trim() != 'Ingredients') {
    final l = lines[i].trim();

    if (l.startsWith('Region:')) {
      // Format: "Region: Nationwide Category: Breakfast Difficulty: Easy Servings: 1 person"
      final parts = l.split(' ');
      for (int p = 0; p < parts.length; p++) {
        if (parts[p] == 'Region:' && p + 1 < parts.length) region = parts[p + 1];
        if (parts[p] == 'Category:' && p + 1 < parts.length) category = parts[p + 1];
        if (parts[p] == 'Difficulty:' && p + 1 < parts.length) difficulty = parts[p + 1];
        if (parts[p] == 'Servings:' && p + 1 < parts.length) {
          servings = '${parts[p + 1]} ${p + 2 < parts.length ? parts[p + 2] : ''}'.trim();
        }
      }
    } else if (l.startsWith('Category:') && !l.contains('Region:')) {
      final m = RegExp(r'Category:\s*(\S+)').firstMatch(l);
      if (m != null) category = m.group(1)!;
    } else if (l.startsWith('Difficulty:')) {
      final m = RegExp(r'Difficulty:\s*(\S+)').firstMatch(l);
      if (m != null) difficulty = m.group(1)!;
    } else if (l.startsWith('Servings:')) {
      final m = RegExp(r'Servings:\s*(.+)$').firstMatch(l);
      if (m != null) servings = m.group(1)!.trim();
    } else if (l.startsWith('Calories:')) {
      final m = RegExp(r'Calories:\s*(.+)$').firstMatch(l);
      if (m != null) calories = m.group(1)!.trim();
    } else if (l.isNotEmpty &&
               !l.startsWith('Ingredients') &&
               !l.startsWith('Steps') &&
               !l.startsWith('Cooking Tips') &&
               !l.startsWith('•') &&
               !RegExp(r'^\d+\.').hasMatch(l)) {
      // This is likely the description
      if (description.isEmpty) {
        description = l;
      }
    }
    i++;
  }

  // Normalize category
  category = normalizeCategory(category, source);

  // Parse ingredients
  final ingredients = <ParsedIngredient>[];
  if (i < lines.length && lines[i].trim() == 'Ingredients') {
    i++;
    while (i < lines.length && lines[i].trim() != 'Steps') {
      final l = lines[i].trim();
      if (l.isNotEmpty &&
          !l.startsWith('Steps') &&
          !l.startsWith('Cooking Tips') &&
          !l.startsWith('Calories:') &&
          !l.startsWith('Servings:') &&
          !RegExp(r'^\d+\.').hasMatch(l)) {
        // Clean up ingredient line
        var ingredientLine = l;
        if (ingredientLine.startsWith('•')) ingredientLine = ingredientLine.substring(1).trim();
        if (ingredientLine.startsWith('-')) ingredientLine = ingredientLine.substring(1).trim();

        final parsed = parseIngredientLine(ingredientLine);
        if (parsed != null) ingredients.add(parsed);
      }
      i++;
    }
  }

  // Parse steps
  final steps = <ParsedStep>[];
  if (i < lines.length && lines[i].trim() == 'Steps') {
    i++;
    int stepNum = 1;
    while (i < lines.length && !lines[i].trim().startsWith('Cooking Tips')) {
      final l = lines[i].trim();
      if (l.isNotEmpty && !l.startsWith('Cooking Tips')) {
        // Remove leading step number if present (e.g., "1. Heat oil...")
        var stepLine = l;
        final stepMatch = RegExp(r'^\d+\.\s*(.+)$').firstMatch(stepLine);
        if (stepMatch != null) {
          stepLine = stepMatch.group(1)!;
        }

        steps.add(ParsedStep(
          title: 'Step $stepNum',
          description: stepLine,
        ));
        stepNum++;
      }
      i++;
    }
  }

  // Skip cooking tips
  while (i < lines.length && lines[i].trim().startsWith('Cooking Tips')) {
    i++;
    while (i < lines.length && lines[i].trim().isNotEmpty && !RegExp(r'^\d+\.').hasMatch(lines[i].trim())) {
      i++;
    }
  }

  return ParsedRecipeWithIndex(
    recipe: ParsedRecipe(
      title: title,
      category: category,
      difficulty: difficulty,
      servings: servings,
      calories: calories,
      description: description,
      ingredients: ingredients,
      steps: steps,
    ),
    endIndex: i,
  );
}

ParsedIngredient? parseIngredientLine(String line) {
  line = line.trim();
  if (line.isEmpty) return null;

  // Fix OCR issues: "large" -> "arge", "liter" -> "iter"
  // Must handle these BEFORE the patterns match "l" as liter unit
  line = line.replaceAll('arge ', 'large ');
  line = line.replaceAll('iter ', 'liter ');
  line = line.replaceAll('llarge ', 'large '); // double replacement edge case
  line = line.replaceAll('llarge,', 'large,');
  line = line.replaceAll('llarge.', 'large.');

  final patterns = [
    RegExp(r'^([\d\/\-\.]+(?:\s*(?:pcs|pieces|pc|cups?|tbsp|tsp|cloves?|cans?|packs?|bunches?|stalks?|g|kg|ml|l(?:iter)?|oz|lb)\.?)\s*)(.+?)(?:\s*\((.+?)\))?$'),
    RegExp(r'^([\d\/\.\-]+\s*(?:g|kg|ml|l(?:iter)?|oz|lb))\s+(.+)$'),
    RegExp(r'^(\d+(?:\s*(?:cup|cups|tbsp|tsp|clove|cloves|piece|pieces|pc|pcs|can|cans|pack|packs|bunch|bunches|stalk|stalks|pinch|dash)))\s+(.+)$'),
  ];

  for (final pattern in patterns) {
    final m = pattern.firstMatch(line);
    if (m != null) {
      String name = m.group(2)?.trim() ?? line;
      String description = m.group(1)?.trim() ?? '';
      if (m.groupCount >= 3 && m.group(3) != null && m.group(3)!.isNotEmpty) {
        description = '$description (${m.group(3)!.trim()})';
      }
      if (name.contains('(')) {
        final parenIdx = name.indexOf('(');
        description = '$description ${name.substring(parenIdx)}'.trim();
        name = name.substring(0, parenIdx).trim();
      }
      return ParsedIngredient(name: name, description: description);
    }
  }

  return ParsedIngredient(name: line, description: '');
}

String normalizeCategory(String cat, String source) {
  final c = cat.toLowerCase().trim();
  if (source == 'breakfast') {
    if (c.contains('preserved')) return 'Preserved';
    if (c.contains('breakfast')) return 'Breakfast';
    if (c.contains('noodle') || c.contains('pancit')) return 'Noodles';
    if (c.contains('soup') || c.contains('lugaw') || c.contains('arroz')) return 'Soup';
    return 'Breakfast';
  }
  if (c.contains('braised')) return 'Braised';
  if (c.contains('grilled') || c.contains('fried')) return 'Grilled/Fried';
  if (c.contains('noodle') || c.contains('rice') || c.contains('pancit')) return 'Noodles/Rice';
  if (c.contains('preserved')) return 'Preserved';
  if (c.contains('salad') || c.contains('fresh')) return 'Salad/Fresh';
  if (c.contains('sautéed') || c.contains('sauteed') || c.contains('ginisang') || c.contains('ginisa')) return 'Sautéed';
  if (c.contains('soup') || c.contains('stew') || c.contains('sinigang') || c.contains('nilaga') || c.contains('tinola')) return 'Soup/Stew';
  return cat.isNotEmpty ? cat : 'Main Dish';
}

String generateSqlMigration(List<ParsedRecipe> recipes) {
  final buffer = StringBuffer();

  buffer.writeln('-- PalengkeGo — Bulk seed: ${recipes.length} Filipino recipes');
  buffer.writeln('-- Generated from extracted DOCX content (breakfast + ulam)');
  buffer.writeln('-- Apply with: supabase db push');
  buffer.writeln('');

  const bgColor = 4292932350;

  String getTime(String diff) {
    switch (diff.toLowerCase()) {
      case 'easy': return '30 min';
      case 'medium': return '45 min';
      case 'hard': return '60 min';
      default: return '30 min';
    }
  }

  String getImageUrl(String title) {
    return 'https://images.unsplash.com/photo-1563245372-f21724e3856d?w=400&h=250&fit=crop';
  }

  String getIngredientImageUrl(String name) {
    return 'https://images.unsplash.com/photo-1540420773420-3366772f4999?w=200&h=200&fit=crop';
  }

  for (int idx = 0; idx < recipes.length; idx++) {
    final r = recipes[idx];
    final time = getTime(r.difficulty);
    final imageUrl = getImageUrl(r.title);

    final ingredientsJson = r.ingredients.map((ing) {
      final imgUrl = getIngredientImageUrl(ing.name);
      return '{"name":${jsonEncode(ing.name)},"description":${jsonEncode(ing.description)},"image_url":${jsonEncode(imgUrl)}}';
    }).join(',');

    final stepsJson = r.steps.map((step) {
      return '{"title":${jsonEncode(step.title)},"description":${jsonEncode(step.description)}}';
    }).join(',');

    buffer.writeln('INSERT INTO public.recipes (');
    buffer.writeln('  title, category, "time", difficulty, image_url,');
    buffer.writeln('  serving, calories, background_color, ingredients, steps');
    buffer.writeln(') VALUES (');
    buffer.writeln('  ${jsonEncode(r.title)},');
    buffer.writeln('  ${jsonEncode(r.category)},');
    buffer.writeln('  ${jsonEncode(time)},');
    buffer.writeln('  ${jsonEncode(r.difficulty)},');
    buffer.writeln('  ${jsonEncode(imageUrl)},');
    buffer.writeln('  ${jsonEncode(r.servings)},');
    buffer.writeln('  ${jsonEncode(r.calories)},');
    buffer.writeln('  $bgColor,');
    buffer.writeln('  \'[$ingredientsJson]\'::jsonb,');
    buffer.writeln('  \'[$stepsJson]\'::jsonb');
    buffer.writeln(');');
    buffer.writeln('');
  }

  return buffer.toString();
}

int min(int a, int b) => a < b ? a : b;