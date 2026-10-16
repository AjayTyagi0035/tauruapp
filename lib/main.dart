import 'package:flutter/material.dart';
import 'screens/login_screen.dart';
import 'screens/survey_screen.dart';
import 'services/auth_service.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const TauruApp());
}

class TauruApp extends StatelessWidget {
  const TauruApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tauru App',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: FutureBuilder<Map<String, dynamic>?>(
        future: AuthService.getSavedUser(),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          final user = snapshot.data;
          if (user != null) {
            return SurveyScreen(user: user);
          }

          return const LoginScreen();
        },
      ),
    );
  }
}
