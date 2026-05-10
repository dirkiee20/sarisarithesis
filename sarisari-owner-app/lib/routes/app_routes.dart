import 'package:flutter/material.dart';
import '../screens/splash/splash_screen.dart';
import '../screens/login/login_screen.dart';
import '../screens/register/register_screen.dart';
import '../screens/dashboard/dashboard_screen.dart';
import '../screens/assistant/assistant_screen.dart';
import '../screens/analytics/analytics_screen.dart';
import '../screens/products/products_screen.dart';
import '../screens/staff/staff_screen.dart';
import '../screens/expenses/expenses_screen.dart';
import '../screens/expenses/add_expense_screen.dart';
import '../screens/reports/reports_screen.dart';
import '../screens/account/account_screen.dart';

class AppRoutes {
  static const String initial = '/';
  static const String login = '/login';
  static const String register = '/register';
  static const String dashboard = '/dashboard';
  static const String assistant = '/assistant';
  static const String analytics = '/analytics';
  static const String products = '/products';
  static const String staff = '/staff';
  static const String expenses = '/expenses';
  static const String addExpense = '/expenses/add';
  static const String reports = '/reports';
  static const String account = '/account';

  static Map<String, WidgetBuilder> routes = {
    initial: (_) => const SplashScreen(),
    login: (_) => const LoginScreen(),
    register: (_) => const RegisterScreen(),
    dashboard: (_) => const DashboardScreen(),
    assistant: (_) => const AssistantScreen(),
    analytics: (_) => const AnalyticsScreen(),
    products: (_) => const ProductsScreen(),
    staff: (_) => const StaffScreen(),
    expenses: (_) => const ExpensesScreen(),
    addExpense: (_) => const AddExpenseScreen(),
    reports: (_) => const ReportsScreen(),
    account: (_) => const AccountScreen(),
  };
}
