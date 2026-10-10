/// Central list of named routes + path builders.
class Routes {
  const Routes._();

  static const splash = '/';
  static const onboarding = '/onboarding';

  static const home = '/home';
  static const kitchen = '/kitchen';
  static const recipes = '/recipes';

  static const scan = '/scan';

  static const manualAdd = '/kitchen/add';
  static String itemDetails(String id) => '/kitchen/item/$id';
  static const itemDetailsPattern = '/kitchen/item/:id';

  static String recipeDetails(String id) => '/recipes/detail/$id';
  static const recipeDetailsPattern = '/recipes/detail/:id';
  static const cookUpdate = '/recipes/cook-update';
  static const rescue = '/recipes/rescue';

  static const shoppingList = '/shopping';
  static const receiptHistory = '/receipts';
  static String receiptDetails(String id) => '/receipts/$id';
  static const receiptDetailsPattern = '/receipts/:id';

  static const preferences = '/settings/preferences';
  static const settings = '/settings';

  static const assistant = '/assistant';
}
