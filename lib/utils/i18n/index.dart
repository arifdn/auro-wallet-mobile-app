import 'dart:async';
import 'package:auro_wallet/utils/i18n/ledger.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show SynchronousFuture;
import 'main.dart';
import 'staking.dart';
import 'home.dart';
import 'settings.dart';

class AppLocalizationsDelegate extends LocalizationsDelegate<I18n> {
  const AppLocalizationsDelegate(this.overriddenLocale);

  final Locale overriddenLocale;

  @override
  bool isSupported(Locale locale) => ['en', 'zh', 'tr'].contains(locale.languageCode);

  @override
  Future<I18n> load(Locale locale) {
    return SynchronousFuture<I18n>(I18n(overriddenLocale));
  }

  @override
  bool shouldReload(AppLocalizationsDelegate old) => true;
}

class I18n {
  I18n(this.locale);

  final Locale locale;

  static I18n of(BuildContext context) {
    return Localizations.of<I18n>(context, I18n)!;
  }

  static String getLanguageDisplay(localeCode) {
    switch (localeCode) {
      case 'zh':
        return '中文（简体）';
      case 'tr':
        return 'Türkçe';
      default:
        return 'English';
    }
  }

  static Map<String, Map<String, Map<String, String>>> _localizedValues = {
    'en': {
      'main': enMain,
      'home': enHome,
      'settings': enSettings,
      'staking': enStaking,
      'ledger': enLedger
    },
    'zh': {
      'main': zhMain,
      'home': zhHome,
      'settings': zhSettings,
      'staking': zhStaking,
      'ledger': zhLedger,
    },
    'tr': {
      'main': trMain,
      'home': trHome,
      'settings': trSettings,
      'staking': trStaking,
      'ledger': trLedger,
    },
  };

  Map<String, String> get main {
    return _localizedValues[locale.languageCode]!['main']!;
  }

  Map<String, String> get home {
    return _localizedValues[locale.languageCode]!['home']!;
  }

  Map<String, String> get settings {
    return _localizedValues[locale.languageCode]!['settings']!;
  }

  Map<String, String> get staking {
    return _localizedValues[locale.languageCode]!['staking']!;
  }

  Map<String, String> get ledger {
    return _localizedValues[locale.languageCode]!['ledger']!;
  }
}
