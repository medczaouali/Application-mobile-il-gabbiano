import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ilgabbiano/localization/app_localizations.dart';
import 'package:ilgabbiano/providers/locale_provider.dart';
import 'package:ilgabbiano/providers/theme_provider.dart';
import 'package:ilgabbiano/widgets/custom_app_bar.dart';
import 'package:ilgabbiano/providers/biometric_provider.dart';
import 'package:ilgabbiano/services/session_manager.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      appBar: CustomAppBar(title: AppLocalizations.of(context).t('settings')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle(
              context,
              AppLocalizations.of(context).t('app_language'),
              isDarkMode,
            ),
            const SizedBox(height: 12),
            _buildLanguageSelector(context, isDarkMode),
            const SizedBox(height: 32),
            _buildSectionTitle(
              context,
              AppLocalizations.of(context).t('appearance'),
              isDarkMode,
            ),
            const SizedBox(height: 12),
            _buildThemeSelector(context, isDarkMode),
            const SizedBox(height: 32),
            _buildSectionTitle(
              context,
              AppLocalizations.of(context).t('biometric_unlock'),
              isDarkMode,
            ),
            const SizedBox(height: 12),
            _buildBiometricToggle(context, isDarkMode),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title, bool isDarkMode) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: isDarkMode ? Colors.white : Theme.of(context).primaryColor,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildLanguageSelector(BuildContext context, bool isDarkMode) {
    final localeProvider = Provider.of<LocaleProvider>(context);
    final currentLocale = localeProvider.locale.languageCode;

    final languages = [
      {
        'code': 'en',
        'name': AppLocalizations.of(context).t('language_english'),
        'flag': '🇬🇧',
      },
      {
        'code': 'fr',
        'name': AppLocalizations.of(context).t('language_french'),
        'flag': '🇫🇷',
      },
      {
        'code': 'it',
        'name': AppLocalizations.of(context).t('language_italian'),
        'flag': '🇮🇹',
      },
      {
        'code': 'de',
        'name': AppLocalizations.of(context).t('language_german'),
        'flag': '🇩🇪',
      },
      {
        'code': 'pt',
        'name': AppLocalizations.of(context).t('language_portuguese'),
        'flag': '🇵🇹',
      },
      {
        'code': 'ar',
        'name': AppLocalizations.of(context).t('language_arabic'),
        'flag': '🇸🇦',
      },
    ];

    return Card(
      elevation: isDarkMode ? 4 : 2,
      color: isDarkMode ? Colors.grey[850] : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Icon(
                  Icons.language,
                  color: Theme.of(context).primaryColor,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppLocalizations.of(context).t('app_language'),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: isDarkMode ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        AppLocalizations.of(context).t('select_language'),
                        style: TextStyle(
                          fontSize: 12, 
                          color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: isDarkMode ? Colors.grey[700] : Colors.grey[300]),
          ...languages.map((lang) {
            final isSelected = currentLocale == lang['code'];
            return InkWell(
              onTap: () async {
                if (!isSelected) {
                  await localeProvider.setLocale(
                    Locale(lang['code'] as String),
                  );
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          AppLocalizations.of(context).t('language_changed'),
                        ),
                        duration: const Duration(seconds: 2),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
          color: isSelected
            ? Theme.of(context).primaryColor.withValues(alpha: 0.12)
            : null,
                  border: Border(
                    bottom: languages.last == lang
                        ? BorderSide.none
                        : BorderSide(
                            color: isDarkMode ? Colors.grey[700]! : Colors.grey[200]!, 
                            width: 1,
                          ),
                  ),
                  borderRadius: languages.last == lang
                      ? const BorderRadius.only(
                          bottomLeft: Radius.circular(12),
                          bottomRight: Radius.circular(12),
                        )
                      : null,
                ),
                child: Row(
                  children: [
                    Text(
                      lang['flag'] as String,
                      style: const TextStyle(fontSize: 32),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        lang['name'] as String,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.w400,
                          color: isSelected
                              ? Theme.of(context).primaryColor
                              : (isDarkMode ? Colors.white : Colors.black87),
                        ),
                      ),
                    ),
                    if (isSelected)
                      Icon(
                        Icons.check_circle,
                        color: Theme.of(context).primaryColor,
                        size: 24,
                      )
                    else
                      Icon(
                        Icons.circle_outlined,
                        color: isDarkMode ? Colors.grey[600] : Colors.grey[400],
                        size: 24,
                      ),
                  ],
                ),
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildThemeSelector(BuildContext context, bool isDarkMode) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final currentTheme = themeProvider.themeMode;

    final themes = [
      {
        'mode': ThemeMode.light,
        'name': AppLocalizations.of(context).t('light_mode'),
        'icon': Icons.light_mode,
        'color': Colors.orange,
      },
      {
        'mode': ThemeMode.dark,
        'name': AppLocalizations.of(context).t('dark_mode'),
        'icon': Icons.dark_mode,
        'color': Colors.indigo,
      },
      {
        'mode': ThemeMode.system,
        'name': AppLocalizations.of(context).t('system_mode'),
        'icon': Icons.settings_suggest,
        'color': Colors.grey,
      },
    ];

    return Card(
      elevation: isDarkMode ? 4 : 2,
      color: isDarkMode ? Colors.grey[850] : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Icon(
                  Icons.palette,
                  color: Theme.of(context).primaryColor,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppLocalizations.of(context).t('theme_mode'),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: isDarkMode ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        AppLocalizations.of(context).t('select_theme'),
                        style: TextStyle(
                          fontSize: 12, 
                          color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: isDarkMode ? Colors.grey[700] : Colors.grey[300]),
          ...themes.map((theme) {
            final isSelected = currentTheme == theme['mode'];
            return InkWell(
              onTap: () async {
                if (!isSelected) {
                  await themeProvider.setThemeMode(theme['mode'] as ThemeMode);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          AppLocalizations.of(context).t('theme_changed'),
                        ),
                        duration: const Duration(seconds: 2),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
          color: isSelected
            ? Theme.of(context).primaryColor.withValues(alpha: 0.12)
            : null,
                  border: Border(
                    bottom: themes.last == theme
                        ? BorderSide.none
                        : BorderSide(
                            color: isDarkMode ? Colors.grey[700]! : Colors.grey[200]!, 
                            width: 1,
                          ),
                  ),
                  borderRadius: themes.last == theme
                      ? const BorderRadius.only(
                          bottomLeft: Radius.circular(12),
                          bottomRight: Radius.circular(12),
                        )
                      : null,
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: (theme['color'] as Color).withValues(alpha: isDarkMode ? 0.2 : 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        theme['icon'] as IconData,
                        color: theme['color'] as Color,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        theme['name'] as String,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.w400,
                          color: isSelected
                              ? Theme.of(context).primaryColor
                              : (isDarkMode ? Colors.white : Colors.black87),
                        ),
                      ),
                    ),
                    if (isSelected)
                      Icon(
                        Icons.check_circle,
                        color: Theme.of(context).primaryColor,
                        size: 24,
                      )
                    else
                      Icon(
                        Icons.circle_outlined,
                        color: isDarkMode ? Colors.grey[600] : Colors.grey[400],
                        size: 24,
                      ),
                  ],
                ),
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildBiometricToggle(BuildContext context, bool isDarkMode) {
    return Consumer<BiometricProvider>(
      builder: (context, bio, _) {
        final available = bio.available;
        final colorSubtitle = isDarkMode ? Colors.grey[400] : Colors.grey[600];
        return Card(
          elevation: isDarkMode ? 4 : 2,
          color: isDarkMode ? Colors.grey[850] : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Icon(Icons.fingerprint, color: Theme.of(context).primaryColor, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppLocalizations.of(context).t('enable_biometrics'),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: isDarkMode ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        available
                            ? AppLocalizations.of(context).t('enable_biometrics_hint')
                            : AppLocalizations.of(context).t('biometric_not_available'),
                        style: TextStyle(fontSize: 12, color: colorSubtitle),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: bio.enabled && available,
                  onChanged: available
                      ? (v) async {
                          if (v) {
                            final ok = await bio.enable();
                            if (context.mounted) {
                              final code = bio.lastErrorCode;
                              String key = 'biometric_enabled';
                              if (!ok) {
                                switch (code) {
                                  case 'notEnrolled':
                                  case 'NotEnrolled':
                                  case 'noBiometrics':
                                  case 'NoBiometrics':
                                    key = 'biometric_no_enrollment';
                                    break;
                                  case 'passcodeNotSet':
                                  case 'PasscodeNotSet':
                                    key = 'biometric_passcode_not_set';
                                    break;
                                  case 'lockedOut':
                                  case 'LockedOut':
                                    key = 'biometric_locked';
                                    break;
                                  case 'permanentlyLockedOut':
                                  case 'PermanentlyLockedOut':
                                    key = 'biometric_perm_locked';
                                    break;
                                  case 'notAvailable':
                                  case 'NotAvailable':
                                    key = 'biometric_not_available';
                                    break;
                                  default:
                                    key = 'biometric_failed';
                                }
                              }
                              // If enabled successfully, link current session user so fingerprint can log in from the login screen.
                              if (ok) {
                                final session = await SessionManager().getUserSession();
                                if (session != null) {
                                  await bio.linkCurrentUser(userId: session['id'], role: session['role']);
                                }
                              }
                              final msg = AppLocalizations.of(context).t(key) + (ok || code == null ? '' : ' (code: $code)');
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
                            }
                          } else {
                            await bio.disable();
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(AppLocalizations.of(context).t('biometric_disabled'))),
                              );
                            }
                          }
                        }
                      : null,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
