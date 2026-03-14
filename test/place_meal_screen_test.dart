import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_desk/screens/place_meal_screen.dart';

void main() {
  group('PlaceMealScreen', () {
    Widget buildTestWidget() {
      return MaterialApp(
        home: const PlaceMealScreen(),
      );
    }

    testWidgets('shows Place a Meal in app bar', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pump(); // one frame; may still be loading
      expect(find.text('Place a Meal'), findsOneWidget);
      expect(find.byType(AppBar), findsOneWidget);
    });

    testWidgets('shows loading or error state (no main form before load)', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pump();
      // Either loading indicator or error message; main form (Date, Meal type) not yet visible
      final hasLoading = find.byType(CircularProgressIndicator).evaluate().isNotEmpty;
      final hasError = find.text('Could not load meals').evaluate().isNotEmpty;
      expect(hasLoading || hasError, isTrue);
    });

    testWidgets('shows error state when meals fail to load', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle(const Duration(seconds: 5));
      // Without Firebase, _loadProducts fails and sets _loadError
      expect(find.text('Could not load meals'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('error state has Retry button that can be tapped', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle(const Duration(seconds: 5));
      final retry = find.text('Retry');
      expect(retry, findsOneWidget);
      await tester.tap(retry);
      await tester.pump();
      // After tap, loading is shown again briefly or we settle back to error
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Place a Meal'), findsOneWidget);
    });

    testWidgets('screen uses a Scaffold', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pump();
      expect(find.byType(Scaffold), findsOneWidget);
    });
  });

  group('Place meal meal-type filtering (unit)', () {
    // Mirror of screen logic: filter products by selected meal type.
    // Products with no mealTypes or empty list appear for all types.
    List<Map<String, dynamic>> filterByMealType(
      List<Map<String, dynamic>> products,
      String? mealType,
    ) {
      if (mealType == null) return products;
      return products.where((p) {
        final types = p['mealTypes'];
        if (types == null || types is! List || (types as List).isEmpty) return true;
        return (types as List).contains(mealType);
      }).toList();
    }

    test('returns all products when mealType is null', () {
      final products = [
        {'id': '1', 'name': 'A', 'mealTypes': ['Breakfast']},
        {'id': '2', 'name': 'B', 'mealTypes': ['Lunch']},
      ];
      expect(filterByMealType(products, null), equals(products));
    });

    test('filters products by Breakfast', () {
      final products = [
        {'id': '1', 'name': 'A', 'mealTypes': ['Breakfast']},
        {'id': '2', 'name': 'B', 'mealTypes': ['Lunch']},
        {'id': '3', 'name': 'C', 'mealTypes': ['Breakfast', 'Lunch']},
      ];
      final out = filterByMealType(products, 'Breakfast');
      expect(out.length, 2);
      expect(out.map((p) => p['id']).toList(), containsAll(['1', '3']));
    });

    test('filters products by Lunch', () {
      final products = [
        {'id': '1', 'name': 'A', 'mealTypes': ['Breakfast']},
        {'id': '2', 'name': 'B', 'mealTypes': ['Lunch']},
      ];
      final out = filterByMealType(products, 'Lunch');
      expect(out.length, 1);
      expect(out.first['id'], '2');
    });

    test('includes products with empty mealTypes for any meal type', () {
      final products = [
        {'id': '1', 'name': 'A', 'mealTypes': []},
        {'id': '2', 'name': 'B'}, // no mealTypes key
      ];
      expect(filterByMealType(products, 'Breakfast').length, 2);
      expect(filterByMealType(products, 'Lunch').length, 2);
      expect(filterByMealType(products, 'Dinner').length, 2);
    });

    test('returns empty list when no products match meal type', () {
      final products = [
        {'id': '1', 'name': 'A', 'mealTypes': ['Breakfast']},
      ];
      expect(filterByMealType(products, 'Dinner'), isEmpty);
    });
  });

  group('Place meal constants', () {
    test('kMealTypes contains Breakfast, Lunch, Dinner', () {
      expect(kMealTypes, contains('Breakfast'));
      expect(kMealTypes, contains('Lunch'));
      expect(kMealTypes, contains('Dinner'));
      expect(kMealTypes.length, 3);
    });
  });
}
