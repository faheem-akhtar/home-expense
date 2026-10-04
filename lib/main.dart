import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'models/app_user.dart';
import 'screens/home_shell.dart';
import 'screens/login_screen.dart';
import 'screens/setup_screen.dart';
import 'services/auth_service.dart';
import 'state/app_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const HomeExpenseApp());
}

class HomeExpenseApp extends StatelessWidget {
  const HomeExpenseApp({super.key});

  @override
  Widget build(BuildContext context) {
    ThemeData theme(Brightness b) => ThemeData(
          colorSchemeSeed: const Color(0xFF00796B),
          brightness: b,
          useMaterial3: true,
          inputDecorationTheme: const InputDecorationTheme(border: OutlineInputBorder()),
        );

    return MaterialApp(
      title: 'Home Expenses',
      debugShowCheckedModeBanner: false,
      theme: theme(Brightness.light),
      darkTheme: theme(Brightness.dark),
      home: const _AuthGate(),
    );
  }
}

/// Signed out → login. Signed in without a household → setup. Otherwise the app.
class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: AuthService.instance.authChanges(),
      builder: (context, authSnap) {
        if (authSnap.connectionState == ConnectionState.waiting) return const _Splash();
        final user = authSnap.data;
        if (user == null) return const LoginScreen();
        return _ProfileGate(key: ValueKey(user.uid), uid: user.uid);
      },
    );
  }
}

class _ProfileGate extends StatefulWidget {
  const _ProfileGate({super.key, required this.uid});

  final String uid;

  @override
  State<_ProfileGate> createState() => _ProfileGateState();
}

class _ProfileGateState extends State<_ProfileGate> {
  late final Stream<AppUser?> _profile = AuthService.instance.profile(widget.uid);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AppUser?>(
      stream: _profile,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) return const _Splash();
        final profile = snap.data;
        if (profile == null) return const SetupScreen();
        return ChangeNotifierProvider(
          key: ValueKey('${profile.uid}/${profile.householdId}/${profile.displayName}'),
          create: (_) => AppState(user: profile)..start(),
          child: const HomeShell(),
        );
      },
    );
  }
}

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: CircularProgressIndicator()));
}
