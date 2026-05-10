import 'package:flutter/material.dart';
import '../presentation/splash_screen/splash_screen.dart';
import '../presentation/login_screen/login_screen.dart';
import '../presentation/register_screen/register_screen.dart';
import '../presentation/onboarding_screen/onboarding_screen.dart';
import '../presentation/products_tab/products.dart';
import '../presentation/add_product_screen/add_product_screen.dart';
import '../presentation/edit_product_screen/edit_product_screen.dart';
import '../presentation/stock_management_tab/stock_management_tab.dart';
import '../presentation/analytics_tab/analytics_tab.dart';
import '../presentation/assistant/cashier_assistant_screen.dart';
import '../presentation/checkout_screen/checkout_screen.dart';
import '../presentation/expenses_screen/expenses_screen.dart';
import '../presentation/account_screen/account_screen.dart';

class AppRoutes {
  static const String initial = '/';
  static const String splash = '/splash';
  static const String login = '/login';
  static const String register = '/register';
  static const String onboarding = '/onboarding';
  static const String productsTab = '/products-tab';
  static const String addProduct = '/add-product-screen';
  static const String editProduct = '/edit-product';
  static const String stockManagementTab = '/stock-management-tab';
  static const String analyticsTab = '/analytics-tab';
  static const String cashierAssistant = '/cashier-assistant';
  static const String checkout = '/checkout';
  static const String expenses = '/expenses';
  static const String account = '/account';

  static Map<String, WidgetBuilder> routes = {
    initial: (context) => const SplashScreen(),
    splash: (context) => const SplashScreen(),
    login: (context) => const LoginScreen(),
    register: (context) => const RegisterScreen(),
    onboarding: (context) => const OnboardingScreen(),
    productsTab: (context) => const ProductsTab(),
    addProduct: (context) => const AddProductScreen(),
    stockManagementTab: (context) => const StockManagementTab(),
    analyticsTab: (context) => const AnalyticsTab(),
    cashierAssistant: (context) => const CashierAssistantScreen(),
    expenses: (context) => const ExpensesScreen(),
    account: (context) => const AccountScreen(),
    editProduct: (context) {
      final product =
          ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      if (product == null) return const ProductsTab();
      return EditProductScreen(product: product);
    },
    checkout: (context) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Map<String, dynamic>) {
        final product = args['product'] as Map<String, dynamic>?;
        final cartOnly = args['cartOnly'] as bool? ?? false;
        final cartItems = args['cartItems'] as List<Map<String, dynamic>>?;
        return CheckoutScreen(
          product: product,
          cartOnly: cartOnly,
          cartItems: cartItems,
        );
      }
      return const CheckoutScreen(cartOnly: true);
    },
  };
}
