import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/supabase/supabase_bootstrap.dart';
import '../../../core/widgets/gradient_background.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Timer(const Duration(milliseconds: 800), () {
      if (!mounted) return;
      final hasSession =
          SupabaseBootstrap.isInitialized &&
          SupabaseBootstrap.client.auth.currentSession != null;
      Navigator.pushReplacementNamed(context, hasSession ? '/main' : '/login');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GradientBackground(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(
                Icons.graphic_eq_rounded,
                size: 92,
                color: Color(0xFF1565FF),
              ),
              SizedBox(height: 12),
              Text(
                'voicenote',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

