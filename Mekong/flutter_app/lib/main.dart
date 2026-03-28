import 'package:flutter/material.dart';
import 'screens/login.dart';
import 'screens/home.dart';
import 'screens/profile.dart';
import 'screens/products.dart';
import 'screens/users.dart';
import 'screens/charges.dart';
import 'screens/tables.dart';
import 'screens/orders.dart';
import 'screens/deliveries.dart';
import 'screens/livreur.dart';
import 'screens/serveur_home.dart';
import 'theme_controller.dart';
// splash removed
import 'screens/forgot_password.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ThemeController.instance.load();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  ThemeData get _light => ThemeData(
        brightness: Brightness.light,
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFD43B3B)),
        scaffoldBackgroundColor: const Color(0xFFF4F5FF),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFD43B3B),
            foregroundColor: Colors.white,
            textStyle: const TextStyle(color: Colors.white),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(foregroundColor: Colors.white),
        ),
        inputDecorationTheme: const InputDecorationTheme(
          labelStyle: TextStyle(color: Colors.white),
          hintStyle: TextStyle(color: Colors.white70),
        ),
      );

  ThemeData get _dark => ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFFD43B3B), brightness: Brightness.dark),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFD43B3B),
            foregroundColor: Colors.white,
            textStyle: const TextStyle(color: Colors.white),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(foregroundColor: Colors.white),
        ),
        inputDecorationTheme: const InputDecorationTheme(
          labelStyle: TextStyle(color: Colors.white),
          hintStyle: TextStyle(color: Colors.white70),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: ThemeController.instance.isDark,
      builder: (_, isDark, __) => MaterialApp(
        title: 'LE MEKONG',
        theme: _light,
        darkTheme: _dark,
        themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
        initialRoute: '/login',
        routes: {
          '/login': (context) => const LoginScreen(),
          '/forgot': (context) => const ForgotPasswordScreen(),
          '/home': (context) => const HomeScreen(),
          // '/admin' route removed (admin_dashboard.dart deleted)
          '/profile': (context) => const ProfileScreen(),
          '/products': (context) => const ProductsScreen(),
          '/users': (context) => const UsersScreen(),
          '/charges': (context) => const ChargesScreen(),
          '/orders': (context) => const CommandesJourScreen(),
          '/deliveries': (context) => const LivraisonsScreen(),
          '/livreur': (context) => const LivreurScreen(),
          '/tables': (context) => const RestaurantTablesScreen(),
          '/home_serveur': (context) => const ServeurHomeScreen(),
        },
      ),
    );
  }
}
