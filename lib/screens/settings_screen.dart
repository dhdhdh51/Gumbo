import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../l10n/gen/app_localizations.dart';
import '../models/enums.dart';
import '../providers/app_providers.dart';
import '../services/prefs_service.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'onboarding_screen.dart';
import 'paywall_screen.dart';
import 'privacy_screen.dart';
import 'questionnaire_screen.dart';
import 'sources_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  String? _version;

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform()
        .then((info) {
          if (mounted) {
            setState(() => _version = '${info.version} (${info.buildNumber})');
          }
        })
        .onError((_, _) => null);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final settings = ref.watch(settingsProvider);
    final premium = ref.watch(isPremiumProvider);
    final services = ref.watch(servicesProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: Gap.xl),
          children: [
            _Group(
              title: l10n.settingsLanguage,
              children: [
                RadioGroup<String>(
                  groupValue: settings.locale?.languageCode ?? 'en',
                  onChanged:
                      (code) => ref
                          .read(settingsProvider.notifier)
                          .setLocale(Locale(code ?? 'en')),
                  child: Column(
                    children: [
                      RadioListTile<String>(
                        value: 'en',
                        title: Text(l10n.languageEnglish),
                      ),
                      RadioListTile<String>(
                        value: 'hi',
                        title: Text(l10n.languageHindi),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            _Group(
              title: l10n.settingsTheme,
              children: [
                RadioGroup<ThemeMode>(
                  groupValue: settings.themeMode,
                  onChanged:
                      (mode) => ref
                          .read(settingsProvider.notifier)
                          .setThemeMode(mode ?? ThemeMode.system),
                  child: Column(
                    children: [
                      RadioListTile<ThemeMode>(
                        value: ThemeMode.system,
                        title: Text(l10n.settingsThemeSystem),
                      ),
                      RadioListTile<ThemeMode>(
                        value: ThemeMode.light,
                        title: Text(l10n.settingsThemeLight),
                      ),
                      RadioListTile<ThemeMode>(
                        value: ThemeMode.dark,
                        title: Text(l10n.settingsThemeDark),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            _Group(
              title: l10n.settingsUnits,
              children: [
                RadioGroup<WeightUnit>(
                  groupValue: settings.weightUnit,
                  onChanged:
                      (unit) => ref
                          .read(settingsProvider.notifier)
                          .setWeightUnit(unit ?? WeightUnit.kg),
                  child: Column(
                    children: [
                      RadioListTile<WeightUnit>(
                        value: WeightUnit.kg,
                        title: Text(l10n.settingsUnitKg),
                      ),
                      RadioListTile<WeightUnit>(
                        value: WeightUnit.lb,
                        title: Text(l10n.settingsUnitLb),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            _Group(
              title: l10n.settingsReminders,
              children: [
                if (!premium)
                  Padding(
                    padding: const EdgeInsets.all(Gap.m),
                    child: PremiumLock(
                      onUpgrade:
                          () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const PaywallScreen(),
                            ),
                          ),
                    ),
                  )
                else ...[
                  _ReminderTile(
                    title: l10n.settingsWorkoutReminder,
                    setting: services.prefs.workoutReminder,
                    onChanged: (next) async {
                      await services.prefs.setWorkoutReminder(next);
                      if (next.enabled) {
                        final granted =
                            await services.notifications.requestPermission();
                        if (!granted) {
                          await services.prefs.setWorkoutReminder(
                            const ReminderSetting.disabled(),
                          );
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                l10n.settingsReminderPermissionDenied,
                              ),
                            ),
                          );
                          setState(() {});
                          return;
                        }
                      }
                      await services.notifications.scheduleWorkoutReminder(
                        setting: next,
                        title: l10n.appTitle,
                        body: l10n.homeStartWorkout,
                      );
                      if (mounted) setState(() {});
                    },
                  ),
                  _ReminderTile(
                    title: l10n.settingsWaterReminder,
                    subtitle: l10n.settingsWaterReminderNote,
                    setting: services.prefs.waterReminder,
                    onChanged: (next) async {
                      await services.prefs.setWaterReminder(next);
                      if (next.enabled) {
                        final granted =
                            await services.notifications.requestPermission();
                        if (!granted) {
                          await services.prefs.setWaterReminder(
                            const ReminderSetting.disabled(),
                          );
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                l10n.settingsReminderPermissionDenied,
                              ),
                            ),
                          );
                          setState(() {});
                          return;
                        }
                      }
                      await services.notifications.scheduleWaterReminders(
                        setting: next,
                        title: l10n.dietWaterHeading,
                        body: l10n.dietWaterGlass,
                      );
                      if (mounted) setState(() {});
                    },
                  ),
                ],
              ],
            ),

            _Group(
              title: l10n.settingsProfile,
              children: [
                ListTile(
                  leading: const Icon(Icons.person_outline),
                  title: Text(l10n.settingsEditProfile),
                  trailing: const Icon(Icons.chevron_right),
                  onTap:
                      () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const OnboardingScreen(editing: true),
                        ),
                      ),
                ),
                ListTile(
                  leading: const Icon(Icons.health_and_safety_outlined),
                  title: Text(l10n.questionnaireTitle),
                  trailing: const Icon(Icons.chevron_right),
                  onTap:
                      () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder:
                              (_) => const QuestionnaireScreen(editing: true),
                        ),
                      ),
                ),
              ],
            ),

            _Group(
              title: l10n.settingsSubscription,
              children: [
                ListTile(
                  leading: const Icon(Icons.workspace_premium_outlined),
                  title: Text(l10n.paywallTitle),
                  subtitle: Text(
                    premium
                        ? l10n.paywallAlreadyPremium
                        : l10n.paywallFreeHeading,
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap:
                      () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const PaywallScreen(),
                        ),
                      ),
                ),
              ],
            ),

            _Group(
              title: l10n.settingsData,
              children: [
                ListTile(
                  leading: const Icon(Icons.download_outlined),
                  title: Text(l10n.settingsExport),
                  subtitle: Text(l10n.settingsExportNote),
                  onTap: () async {
                    try {
                      await services.export.shareExport(
                        subject: l10n.settingsExport,
                      );
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(l10n.settingsExportDone)),
                      );
                    } on Object {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(l10n.errorGeneric)),
                      );
                    }
                  },
                ),
                ListTile(
                  leading: Icon(
                    Icons.delete_forever_outlined,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  title: Text(
                    l10n.settingsDeleteAll,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                  subtitle: Text(l10n.settingsDeleteAllNote),
                  onTap: _confirmDelete,
                ),
              ],
            ),

            _Group(
              title: l10n.settingsAbout,
              children: [
                ListTile(
                  leading: const Icon(Icons.menu_book_outlined),
                  title: Text(l10n.settingsSourcesAndDisclaimer),
                  trailing: const Icon(Icons.chevron_right),
                  onTap:
                      () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const SourcesScreen(),
                        ),
                      ),
                ),
                ListTile(
                  leading: const Icon(Icons.privacy_tip_outlined),
                  title: Text(l10n.settingsPrivacy),
                  trailing: const Icon(Icons.chevron_right),
                  onTap:
                      () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const PrivacyScreen(),
                        ),
                      ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    Gap.m,
                    Gap.s,
                    Gap.m,
                    Gap.m,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.settingsAboutBody,
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(height: 1.4),
                      ),
                      if (_version != null) ...[
                        Gap.h8,
                        Text(
                          l10n.settingsVersion(_version!),
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(l10n.settingsDeleteConfirmTitle),
            content: Text(l10n.settingsDeleteConfirmBody),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(l10n.actionCancel),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                ),
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(l10n.settingsDeleteConfirmAction),
              ),
            ],
          ),
    );

    if (!(confirmed ?? false)) return;

    final services = ref.read(servicesProvider);
    await services.notifications.cancelAll();
    await services.export.deleteAllData();

    if (!mounted) return;
    ref.read(profileProvider.notifier).clear();
    ref.invalidate(settingsProvider);
    invalidateRecords(ref);

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.settingsDeleted)));
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(Gap.m, Gap.l, Gap.m, Gap.s),
        child: Text(
          title,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: Theme.of(context).colorScheme.primary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      ...children,
      const Divider(),
    ],
  );
}

class _ReminderTile extends StatelessWidget {
  const _ReminderTile({
    required this.title,
    required this.setting,
    required this.onChanged,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final ReminderSetting setting;
  final Future<void> Function(ReminderSetting) onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final time = TimeOfDay(hour: setting.hour, minute: setting.minute);

    return Column(
      children: [
        SwitchListTile(
          value: setting.enabled,
          title: Text(title),
          subtitle: subtitle == null ? null : Text(subtitle!),
          onChanged:
              (v) => onChanged(
                ReminderSetting(
                  enabled: v,
                  hour: setting.hour,
                  minute: setting.minute,
                ),
              ),
        ),
        if (setting.enabled)
          ListTile(
            leading: const Icon(Icons.schedule),
            title: Text(l10n.settingsReminderTime),
            trailing: Text(time.format(context)),
            onTap: () async {
              final picked = await showTimePicker(
                context: context,
                initialTime: time,
              );
              if (picked == null) return;
              await onChanged(
                ReminderSetting(
                  enabled: true,
                  hour: picked.hour,
                  minute: picked.minute,
                ),
              );
            },
          ),
      ],
    );
  }
}
