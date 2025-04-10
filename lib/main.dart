import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'providers/auth_provider.dart';
import 'screens/login_screen.dart';
import 'screens/admin_screen.dart';
import 'screens/driver_home_screen.dart';
import 'screens/operator_screen.dart';
import 'screens/driver_trips_screen.dart';
import 'screens/operator_trips_screen.dart';
import 'screens/driver_balance_history_screen.dart';
import 'screens/operator_management_screen.dart';
import 'screens/driver_map_screen.dart';
import 'screens/general_reports_screen.dart';
import 'package:permission_handler/permission_handler.dart';
import 'screens/admin_driver_balances.dart';
import 'screens/create_driver_screen.dart';
import 'screens/create_operator_screen.dart';
import 'screens/driver_management_screen.dart';
import 'screens/driver_reports_screen.dart';
import 'screens/drivers_list_screen.dart';
import 'screens/driver_trips_analytics_screen.dart';
import 'screens/edit_driver_screen.dart';
import 'screens/edit_operator_screen.dart';
import 'services/api.dart';
import 'screens/operators_list_screen.dart';
import 'providers/trip_provider.dart';
import 'screens/operator_reports_screen.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Primero inicializar Supabase
  await Supabase.initialize(
    url: 'https://gunevwlqmwhwsykpvfqi.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imd1bmV2d2xxbXdod3N5a3B2ZnFpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3MzkyOTAwMTksImV4cCI6MjA1NDg2NjAxOX0.FR-CGD6ZUPSh5_0MKUYiUgYuKcyi96ACjwrmYFVJqoE',
  );

  // Inicializar datos de formato para español
  await initializeDateFormatting('es_MX', null);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => TripProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mi Aplicación',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.red,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.red),
      ),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('es', 'MX'),
        Locale('es', 'ES'),
        Locale('en', 'US'),
      ],
      locale: const Locale('es', 'MX'),
      home: AuthWrapper(),
      routes: {
        // Rutas comunes para todas las pantallas
        '/login': (context) => LoginScreen(),
      },
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    // Mostrar indicador de carga mientras se verifica la autenticación
    if (authProvider.loading) {
      return Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // Decidir qué pantalla mostrar según el estado de autenticación
    if (authProvider.user == null) {
      return LoginScreen();
    } else {
      // Navegar según el rol del usuario
      switch (authProvider.user!.role) {
        case 'admin':
          return AdminTabs();
        case 'chofer':
          return DriverTabs();
        case 'operador':
          return OperatorTabs();
        default:
          return LoginScreen();
      }
    }
  }
}

class AdminTabs extends StatelessWidget {
  const AdminTabs({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: DefaultTabController(
        length: 2,
        child: Scaffold(
          bottomNavigationBar: Container(
            height: 55.0,
            child: TabBar(
              tabs: [
                Tab(
                  icon: Icon(Icons.people, color: Colors.red),
                  text: 'Panel Admin',
                ),
                Tab(
                  icon: Icon(Icons.assignment, color: Colors.red),
                  text: 'Mis Viajes',
                ),
              ],
            ),
          ),
          body: TabBarView(
            children: [
              AdminScreen(),
              // Placeholder para OperatorTripsScreen
              OperatorTripsScreen(),
            ],
          ),
        ),
      ),
      routes: {
        // Rutas para admin
        '/adminTabs': (context) => AdminTabs(),
        '/driverManagementScreen': (context) => DriverManagementScreen(),
        '/operatorManagementScreen': (context) => OperatorManagementScreen(),
        '/operatorScreen': (context) => OperatorScreen(),
        '/driverMapScreen': (context) => DriverMapScreen(),
        '/generalReportsScreen': (context) => GeneralReportsScreen(),
        '/adminDriverBalances': (context) => AdminDriverBalances(),
        '/createDriverScreen': (context) => CreateDriverScreen(),
        '/createOperatorScreen': (context) => CreateOperatorScreen(),
        '/driversListScreen': (context) => DriversListScreen(),
        '/driverReports': (context) => DriverReportsScreen(),
        '/driverTripsAnalytics': (context) {
          final args = ModalRoute.of(context)!.settings.arguments as String?;
          return DriverTripsAnalyticsScreen(driverId: args);
        },
        '/operatorTrips': (context) => OperatorTripsScreen(),
        '/editDriverScreen': (context) {
          final driver =
              ModalRoute.of(context)!.settings.arguments as DriverProfile?;
          return EditDriverScreen(driver: driver);
        },
        '/editOperatorScreen': (context) {
          final operator =
              ModalRoute.of(context)!.settings.arguments as OperatorProfile?;
          return EditOperatorScreen(operator: operator);
        },
        '/operatorsListScreen': (context) => OperatorsListScreen(),
        '/operatorReportsScreen': (context) => OperatorReportsScreen(),
      },
    );
  }
}

class DriverTabs extends StatelessWidget {
  const DriverTabs({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: DefaultTabController(
        length: 2,
        child: Scaffold(
          bottomNavigationBar: Container(
            height: 55.0,
            child: TabBar(
              tabs: [
                Tab(
                  icon: Icon(Icons.directions_car, color: Colors.red),
                  text: 'Inicio',
                ),
                Tab(
                  icon: Icon(Icons.assignment, color: Colors.red),
                  text: 'Mis Viajes',
                ),
              ],
            ),
          ),
          body: TabBarView(
            physics: const NeverScrollableScrollPhysics(),
            children: [DriverHomeScreen(), DriverTripsScreen()],
          ),
        ),
      ),
      routes: {
        // Rutas para driver
        '/driverTabs': (context) => DriverTabs(),
        '/driverTrips': (context) => DriverTripsScreen(),
        '/driverBalanceHistory': (context) => DriverBalanceHistoryScreen(),
      },
    );
  }
}

class OperatorTabs extends StatelessWidget {
  const OperatorTabs({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: DefaultTabController(
        length: 2,
        child: Scaffold(
          bottomNavigationBar: Container(
            height: 55.0,
            child: TabBar(
              tabs: [
                Tab(icon: Icon(Icons.people, color: Colors.red), text: 'Panel'),
                Tab(
                  icon: Icon(Icons.assignment, color: Colors.red),
                  text: 'Viajes',
                ),
              ],
            ),
          ),
          body: TabBarView(
            children: [
              // Usar OperatorScreen en lugar del placeholder
              OperatorScreen(),
              // Placeholder para OperatorTripsScreen
              Center(child: Text('Pantalla de Viajes del Operador')),
            ],
          ),
        ),
      ),
      routes: {
        // Rutas para operator
        '/operatorTabs': (context) => OperatorTabs(),
        '/operatorTrips': (context) => OperatorTripsScreen(),
      },
    );
  }
}

Future<void> requestPermissions() async {
  // Solicitar permiso de ubicación
  var locationStatus = await Permission.location.request();

  // Solicitar permiso de notificaciones
  var notificationStatus = await Permission.notification.request();

  // Verificar si los permisos fueron concedidos
  if (locationStatus.isGranted && notificationStatus.isGranted) {
    // Todos los permisos concedidos, continuar con la funcionalidad
  } else {
    // Manejar el caso en que los permisos no fueron concedidos
    // Por ejemplo, mostrar un diálogo explicando por qué se necesitan
  }
}
