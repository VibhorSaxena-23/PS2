import 'package:flutter/foundation.dart';

/// Lightweight event bus for nutrition actions.
/// Any widget can listen to [foodLogged] and react (e.g. refresh summary cards).
class NutritionEvents {
  NutritionEvents._();

  /// Incremented whenever the user successfully logs or edits a food entry.
  static final foodLogged = ValueNotifier<int>(0);

  static void notifyFoodLogged() => foodLogged.value++;
}
