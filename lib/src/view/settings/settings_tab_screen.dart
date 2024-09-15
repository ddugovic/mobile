import 'package:app_settings/app_settings.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lichess_mobile/src/constants.dart';
import 'package:lichess_mobile/src/db/database.dart';
import 'package:lichess_mobile/src/model/auth/auth_controller.dart';
import 'package:lichess_mobile/src/model/auth/auth_session.dart';
import 'package:lichess_mobile/src/model/settings/board_preferences.dart';
import 'package:lichess_mobile/src/model/settings/general_preferences.dart';
import 'package:lichess_mobile/src/navigation.dart';
import 'package:lichess_mobile/src/styles/lichess_icons.dart';
import 'package:lichess_mobile/src/styles/styles.dart';
import 'package:lichess_mobile/src/utils/l10n.dart';
import 'package:lichess_mobile/src/utils/l10n_context.dart';
import 'package:lichess_mobile/src/utils/navigation.dart';
import 'package:lichess_mobile/src/utils/package_info.dart';
import 'package:lichess_mobile/src/utils/system.dart';
import 'package:lichess_mobile/src/view/account/profile_screen.dart';
import 'package:lichess_mobile/src/view/settings/app_background_mode_screen.dart';
import 'package:lichess_mobile/src/view/settings/theme_screen.dart';
import 'package:lichess_mobile/src/widgets/adaptive_action_sheet.dart';
import 'package:lichess_mobile/src/widgets/adaptive_choice_picker.dart';
import 'package:lichess_mobile/src/widgets/feedback.dart';
import 'package:lichess_mobile/src/widgets/list.dart';
import 'package:lichess_mobile/src/widgets/misc.dart';
import 'package:lichess_mobile/src/widgets/platform.dart';
import 'package:lichess_mobile/src/widgets/settings.dart';
import 'package:lichess_mobile/src/widgets/user_full_name.dart';
import 'package:url_launcher/url_launcher.dart';

import 'account_preferences_screen.dart';
import 'board_settings_screen.dart';
import 'sound_settings_screen.dart';

class SettingsTabScreen extends ConsumerWidget {
  const SettingsTabScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ConsumerPlatformWidget(
      ref: ref,
      androidBuilder: _androidBuilder,
      iosBuilder: _iosBuilder,
    );
  }

  Widget _androidBuilder(BuildContext context, WidgetRef ref) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, _) {
        if (!didPop) {
          ref.read(currentBottomTabProvider.notifier).state = BottomTab.home;
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(context.l10n.settingsSettings),
        ),
        body: SafeArea(child: _Body()),
      ),
    );
  }

  Widget _iosBuilder(BuildContext context, WidgetRef ref) {
    return CupertinoPageScaffold(
      child: CustomScrollView(
        slivers: [
          CupertinoSliverNavigationBar(
            largeTitle: Text(context.l10n.settingsSettings),
          ),
          SliverSafeArea(
            top: false,
            sliver: _Body(),
          ),
        ],
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(currentBottomTabProvider, (prev, current) {
      if (prev != BottomTab.settings && current == BottomTab.settings) {
        _refreshData(ref);
      }
    });

    final generalPrefs = ref.watch(generalPreferencesProvider);
    final boardPrefs = ref.watch(boardPreferencesProvider);
    final authController = ref.watch(authControllerProvider);
    final userSession = ref.watch(authSessionProvider);
    final packageInfo = ref.watch(packageInfoProvider);
    final dbSize = ref.watch(getDbSizeInBytesProvider);

    final androidVersionAsync = ref.watch(androidVersionProvider);

    final Widget? donateButton =
        userSession == null || userSession.user.isPatron != true
            ? PlatformListTile(
                leading: Icon(
                  LichessIcons.patron,
                  semanticLabel: context.l10n.patronLichessPatron,
                  color: context.lishogiColors.brag,
                ),
                title: Text(
                  context.l10n.patronDonate,
                  style: TextStyle(color: context.lishogiColors.brag),
                ),
                trailing: Theme.of(context).platform == TargetPlatform.iOS
                    ? const CupertinoListTileChevron()
                    : null,
                onTap: () {
                  launchUrl(Uri.parse('https://lishogi.org/patron'));
                },
              )
            : null;

    final List<Widget> content = [
      ListSection(
        header: userSession != null
            ? UserFullNameWidget(user: userSession.user)
            : null,
        hasLeading: true,
        showDivider: true,
        children: [
          if (userSession != null) ...[
            PlatformListTile(
              leading: const Icon(Icons.person),
              title: Text(context.l10n.profile),
              trailing: Theme.of(context).platform == TargetPlatform.iOS
                  ? const CupertinoListTileChevron()
                  : null,
              onTap: () {
                pushPlatformRoute(
                  context,
                  title: context.l10n.profile,
                  builder: (context) => const ProfileScreen(),
                );
              },
            ),
            PlatformListTile(
              leading: const Icon(Icons.manage_accounts),
              title: Text(context.l10n.preferencesPreferences),
              trailing: Theme.of(context).platform == TargetPlatform.iOS
                  ? const CupertinoListTileChevron()
                  : null,
              onTap: () {
                pushPlatformRoute(
                  context,
                  title: context.l10n.preferencesPreferences,
                  builder: (context) => const AccountPreferencesScreen(),
                );
              },
            ),
            if (authController.isLoading)
              const PlatformListTile(
                leading: Icon(Icons.logout),
                title: Center(child: ButtonLoadingIndicator()),
              )
            else
              PlatformListTile(
                leading: const Icon(Icons.logout),
                title: Text(context.l10n.logOut),
                onTap: () {
                  _showSignOutConfirmDialog(context, ref);
                },
              ),
          ] else ...[
            if (authController.isLoading)
              const PlatformListTile(
                leading: Icon(Icons.login),
                title: Center(child: ButtonLoadingIndicator()),
              )
            else
              PlatformListTile(
                leading: const Icon(Icons.login),
                title: Text(context.l10n.signIn),
                onTap: () {
                  ref.read(authControllerProvider.notifier).signIn();
                },
              ),
          ],
          if (Theme.of(context).platform == TargetPlatform.android &&
              donateButton != null)
            donateButton,
        ],
      ),
      ListSection(
        hasLeading: true,
        showDivider: true,
        children: [
          SettingsListTile(
            icon: const Icon(Icons.music_note),
            settingsLabel: Text(context.l10n.sound),
            settingsValue:
                '${soundThemeL10n(context, generalPrefs.soundTheme)} (${volumeLabel(generalPrefs.masterVolume)})',
            onTap: () {
              pushPlatformRoute(
                context,
                title: context.l10n.sound,
                builder: (context) => const SoundSettingsScreen(),
              );
            },
          ),
          if (Theme.of(context).platform == TargetPlatform.android)
            androidVersionAsync.maybeWhen(
              data: (version) => version != null && version.sdkInt >= 31
                  ? SwitchSettingTile(
                      leading: const Icon(Icons.colorize),
                      title: Text(context.l10n.mobileSystemColors),
                      value: generalPrefs.systemColors,
                      onChanged: (value) {
                        ref
                            .read(generalPreferencesProvider.notifier)
                            .toggleSystemColors();
                      },
                    )
                  : const SizedBox.shrink(),
              orElse: () => const SizedBox.shrink(),
            ),
          SettingsListTile(
            icon: const Icon(Icons.brightness_medium),
            settingsLabel: Text(context.l10n.background),
            settingsValue: AppBackgroundModeScreen.themeTitle(
              context,
              generalPrefs.themeMode,
            ),
            onTap: () {
              if (Theme.of(context).platform == TargetPlatform.android) {
                showChoicePicker(
                  context,
                  choices: ThemeMode.values,
                  selectedItem: generalPrefs.themeMode,
                  labelBuilder: (t) =>
                      Text(AppBackgroundModeScreen.themeTitle(context, t)),
                  onSelectedItemChanged: (ThemeMode? value) => ref
                      .read(generalPreferencesProvider.notifier)
                      .setThemeMode(value ?? ThemeMode.system),
                );
              } else {
                pushPlatformRoute(
                  context,
                  title: context.l10n.background,
                  builder: (context) => const AppBackgroundModeScreen(),
                );
              }
            },
          ),
          SettingsListTile(
            icon: const Icon(Icons.palette),
            settingsLabel: const Text('Theme'),
            settingsValue:
                '${boardPrefs.boardTheme.label} / ${boardPrefs.pieceSet.label}',
            onTap: () {
              pushPlatformRoute(
                context,
                title: 'Theme',
                builder: (context) => const ThemeScreen(),
              );
            },
          ),
          PlatformListTile(
            leading: const Icon(LichessIcons.chess_board),
            title: Text(context.l10n.board),
            trailing: Theme.of(context).platform == TargetPlatform.iOS
                ? const CupertinoListTileChevron()
                : null,
            onTap: () {
              pushPlatformRoute(
                context,
                title: context.l10n.board,
                builder: (context) => const BoardSettingsScreen(),
              );
            },
          ),
          SettingsListTile(
            icon: const Icon(Icons.language),
            settingsLabel: Text(context.l10n.language),
            settingsValue: localeToLocalizedName(
              generalPrefs.locale ?? Localizations.localeOf(context),
            ),
            onTap: () {
              if (Theme.of(context).platform == TargetPlatform.android) {
                showChoicePicker<Locale>(
                  context,
                  choices: kSupportedLocales,
                  selectedItem:
                      generalPrefs.locale ?? Localizations.localeOf(context),
                  labelBuilder: (t) => Text(localeToLocalizedName(t)),
                  onSelectedItemChanged: (Locale? locale) => ref
                      .read(generalPreferencesProvider.notifier)
                      .setLocale(locale),
                );
              } else {
                AppSettings.openAppSettings();
              }
            },
          ),
        ],
      ),
      ListSection(
        hasLeading: true,
        showDivider: true,
        children: [
          PlatformListTile(
            leading: const Icon(Icons.info),
            title: Text(context.l10n.aboutX('Lichess')),
            trailing: const _OpenInNewIcon(),
            onTap: () {
              launchUrl(Uri.parse('https://lishogi.org/about'));
            },
          ),
          PlatformListTile(
            leading: const Icon(Icons.feedback),
            title: Text(context.l10n.mobileFeedbackButton),
            trailing: const _OpenInNewIcon(),
            onTap: () {
              launchUrl(Uri.parse('https://lishogi.org/contact'));
            },
          ),
          PlatformListTile(
            leading: const Icon(Icons.article),
            title: Text(context.l10n.termsOfService),
            trailing: const _OpenInNewIcon(),
            onTap: () {
              launchUrl(Uri.parse('https://lishogi.org/terms-of-service'));
            },
          ),
          PlatformListTile(
            leading: const Icon(Icons.privacy_tip),
            title: Text(context.l10n.privacyPolicy),
            trailing: const _OpenInNewIcon(),
            onTap: () {
              launchUrl(Uri.parse('https://lishogi.org/privacy'));
            },
          ),
        ],
      ),
      ListSection(
        hasLeading: true,
        showDivider: true,
        children: [
          PlatformListTile(
            leading: const Icon(Icons.code),
            title: Text(context.l10n.sourceCode),
            trailing: const _OpenInNewIcon(),
            onTap: () {
              launchUrl(Uri.parse('https://lishogi.org/source'));
            },
          ),
          PlatformListTile(
            leading: const Icon(Icons.bug_report),
            title: Text(context.l10n.contribute),
            trailing: const _OpenInNewIcon(),
            onTap: () {
              launchUrl(Uri.parse('https://lishogi.org/help/contribute'));
            },
          ),
          PlatformListTile(
            leading: const Icon(Icons.star),
            title: Text(context.l10n.thankYou),
            trailing: const _OpenInNewIcon(),
            onTap: () {
              launchUrl(Uri.parse('https://lishogi.org/thanks'));
            },
          ),
        ],
      ),
      ListSection(
        hasLeading: true,
        showDivider: true,
        children: [
          PlatformListTile(
            leading: const Icon(Icons.storage),
            title: const Text('Local database size'),
            subtitle: Theme.of(context).platform == TargetPlatform.iOS
                ? null
                : Text(_getSizeString(dbSize.value)),
            additionalInfo:
                dbSize.hasValue ? Text(_getSizeString(dbSize.value)) : null,
          ),
        ],
      ),
      Padding(
        padding: Styles.bodySectionPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LichessMessage(style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 10),
            Text(
              'v${packageInfo.version}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    ];

    return Theme.of(context).platform == TargetPlatform.iOS
        ? SliverList(delegate: SliverChildListDelegate(content))
        : ListView(children: content);
  }

  Future<void> _showSignOutConfirmDialog(BuildContext context, WidgetRef ref) {
    if (Theme.of(context).platform == TargetPlatform.iOS) {
      return showCupertinoActionSheet(
        context: context,
        actions: [
          BottomSheetAction(
            makeLabel: (context) => Text(context.l10n.logOut),
            isDestructiveAction: true,
            onPressed: (context) async {
              await ref.read(authControllerProvider.notifier).signOut();
            },
          ),
        ],
      );
    } else {
      return showDialog<void>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text(context.l10n.logOut),
            actions: <Widget>[
              TextButton(
                style: TextButton.styleFrom(
                  textStyle: Theme.of(context).textTheme.labelLarge,
                ),
                child: Text(context.l10n.cancel),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
              TextButton(
                style: TextButton.styleFrom(
                  textStyle: Theme.of(context).textTheme.labelLarge,
                ),
                child: Text(context.l10n.mobileOkButton),
                onPressed: () async {
                  Navigator.of(context).pop();
                  await ref.read(authControllerProvider.notifier).signOut();
                },
              ),
            ],
          );
        },
      );
    }
  }

  String _getSizeString(int? bytes) =>
      '${_bytesToMB(bytes ?? (0)).toStringAsFixed(2)}MB';

  double _bytesToMB(int bytes) => bytes * 0.000001;

  void _refreshData(WidgetRef ref) {
    ref.invalidate(getDbSizeInBytesProvider);
  }
}

class _OpenInNewIcon extends StatelessWidget {
  const _OpenInNewIcon();

  @override
  Widget build(BuildContext context) {
    return Icon(
      Icons.open_in_new,
      color: Theme.of(context).platform == TargetPlatform.iOS
          ? CupertinoColors.systemGrey2.resolveFrom(context)
          : null,
    );
  }
}
