import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:vasan_health/core/widgets/app_shell.dart';
import 'package:vasan_health/features/dashboard/dashboard_screen.dart';
import 'package:vasan_health/features/vault/vault_screen.dart';
import 'package:vasan_health/features/vault/diagnoses_screen.dart';
import 'package:vasan_health/features/vault/labs_screen.dart';
import 'package:vasan_health/features/vault/imaging_screen.dart';
import 'package:vasan_health/features/vault/body_comp_screen.dart';
import 'package:vasan_health/features/vault/wearable_screen.dart';
import 'package:vasan_health/features/nutrition/nutrition_screen.dart';
import 'package:vasan_health/features/fitness/fitness_screen.dart';
import 'package:vasan_health/features/sleep/sleep_screen.dart';
import 'package:vasan_health/features/strength/strength_screen.dart';
import 'package:vasan_health/features/symptoms/symptoms_screen.dart';
import 'package:vasan_health/features/stack/stack_screen.dart';
import 'package:vasan_health/features/ai_coach/ai_coach_screen.dart';
import 'package:vasan_health/features/library/library_screen.dart';
import 'package:vasan_health/features/import/import_screen.dart';
import 'package:vasan_health/features/settings/settings_screen.dart';
import 'package:vasan_health/features/reminders/reminders_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    ShellRoute(
      builder: (context, state, child) => AppShell(child: child),
      routes: [
        GoRoute(path: '/', builder: (c, s) => const DashboardScreen()),
        GoRoute(
          path: '/vault',
          builder: (c, s) => const VaultScreen(),
          routes: [
            GoRoute(path: 'diagnoses', builder: (c, s) => const DiagnosesScreen()),
            GoRoute(path: 'labs', builder: (c, s) => const LabsScreen()),
            GoRoute(path: 'imaging', builder: (c, s) => const ImagingScreen()),
            GoRoute(path: 'body-comp', builder: (c, s) => const BodyCompScreen()),
            GoRoute(path: 'wearable', builder: (c, s) => const WearableScreen()),
          ],
        ),
        GoRoute(path: '/nutrition', builder: (c, s) => const NutritionScreen()),
        GoRoute(path: '/fitness', builder: (c, s) => const FitnessScreen()),
        GoRoute(path: '/sleep', builder: (c, s) => const SleepScreen()),
        GoRoute(path: '/strength', builder: (c, s) => const StrengthScreen()),
        GoRoute(path: '/symptoms', builder: (c, s) => const SymptomsScreen()),
        GoRoute(path: '/stack', builder: (c, s) => const StackScreen()),
        GoRoute(path: '/ai-coach', builder: (c, s) => const AiCoachScreen()),
        GoRoute(path: '/library', builder: (c, s) => const LibraryScreen()),
        GoRoute(path: '/import', builder: (c, s) => const ImportScreen()),
        GoRoute(path: '/reminders', builder: (c, s) => const RemindersScreen()),
        GoRoute(path: '/settings', builder: (c, s) => const SettingsScreen()),
      ],
    ),
  ],
);
