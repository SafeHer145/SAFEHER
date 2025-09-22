import 'package:flutter/material.dart';

class LocaleController {
  LocaleController._();
  static final LocaleController instance = LocaleController._();

  // null means system locale
  final ValueNotifier<Locale?> locale = ValueNotifier<Locale?>(null);

  void setLocale(Locale? newLocale) {
    locale.value = newLocale;
  }
}
