import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/auth_provider.dart';
import 'providers/ideas_provider.dart';
import 'screens/auth_gate_screen.dart';

void main() {
  runApp(const IdeasBoardApp());
}

class IdeasBoardApp extends StatelessWidget {
  const IdeasBoardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProxyProvider<AuthProvider, IdeasProvider>(
          create: (_) => IdeasProvider(),
          update: (_, auth, ideas) {
            final provider = ideas ?? IdeasProvider();
            provider.updateAuth(
              token: auth.token,
              userId: auth.userId,
            );
            return provider;
          },
        ),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Ideas Board',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
          useMaterial3: true,
        ),
        home: const AuthGateScreen(),
      ),
    );
  }
}
