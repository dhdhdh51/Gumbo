import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'providers/app_providers.dart';
import 'services/billing_service.dart';
import 'services/data_repository.dart';
import 'services/database.dart';
import 'services/entitlement_service.dart';
import 'services/export_service.dart';
import 'services/notification_service.dart';
import 'services/prefs_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Everything here is local: bundled JSON, shared preferences and SQLite.
  final repository = await DataRepository.load();
  final prefs = await PrefsService.load();
  final db = await AppDatabase.open();
  final notifications = await NotificationService.create();

  final entitlements = EntitlementService(prefs);
  final billing = BillingService(entitlements);

  final services = AppServices(
    repository: repository,
    prefs: prefs,
    db: db,
    notifications: notifications,
    entitlements: entitlements,
    billing: billing,
    export: ExportService(prefs, db),
  );

  // Re-check the Premium entitlement on every launch. This runs in the
  // background so a slow or absent store never delays first paint.
  billing.initialize();

  runApp(
    ProviderScope(
      overrides: [servicesProvider.overrideWithValue(services)],
      child: const TrainerApp(),
    ),
  );
}
