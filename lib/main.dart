import 'package:flutter/material.dart';

import 'screens/dashboard/dashboard_screen.dart';

import 'screens/appointments/appointments_screen.dart';

import 'screens/login/login_screen.dart';

import 'services/supabase_service.dart';

import 'screens/clients/clients_screen.dart';

import 'screens/services/services_screen.dart';

import 'screens/finance/finance_screen.dart';

void main() async {
  await SupabaseService.initialize();
  runApp(const AgendaAutonomosApp());
}

class AgendaAutonomosApp extends StatelessWidget {
  const AgendaAutonomosApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Agenda Autônomos',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.indigo),
      home: const AuthGate(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  final List<Widget> _screens = const [
    DashboardScreen(),
    AppointmentsScreen(),
    ClientsScreen(),
    ServicesScreen(),
    FinanceScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex],

      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,

        onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },

        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Início',
          ),

          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month),
            label: 'Agenda',
          ),

          NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people),
            label: 'Clientes',
          ),

          NavigationDestination(
            icon: Icon(Icons.work_outline),
            selectedIcon: Icon(Icons.work),
            label: 'Serviços',
          ),
        ],
      ),
    );
  }
}

class PlaceholderScreen extends StatelessWidget {
  final String titulo;
  final IconData icone;

  const PlaceholderScreen({
    super.key,
    required this.titulo,
    required this.icone,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(titulo)),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icone, size: 72),
            const SizedBox(height: 16),
            Text(
              titulo,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text('Esta tela será construída em seguida.'),
          ],
        ),
      ),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final session = SupabaseService.client.auth.currentSession;

    if (session != null) {
      return const MainScreen();
    }

    return const LoginScreen();
  }
}
