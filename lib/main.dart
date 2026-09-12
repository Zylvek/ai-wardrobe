import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';

import 'data/options_store.dart';
import 'data/outfit_builder.dart';
import 'data/settings_store.dart';
import 'data/wardrobe_store.dart';
import 'ui/settings_page.dart';
import 'ui/theme/app_theme.dart';
import 'ui/today_page.dart';
import 'ui/update_dialog.dart';
import 'ui/wardrobe_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await WardrobeStore.load();
  await OptionsStore.load();
  await OutfitHistory.load();
  await SettingsStore.load();
  runApp(const WardrobeApp());
}

/// Позволяет «листать» мышкой, как пальцем на телефоне.
class AppScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => PointerDeviceKind.values.toSet();
}

class WardrobeApp extends StatelessWidget {
  const WardrobeApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Переключение темы «на лету»: слушаем themeModeNotifier.
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeModeNotifier,
      builder: (context, mode, _) => MaterialApp(
        title: 'AI Wardrobe',
        debugShowCheckedModeBanner: false,
        scrollBehavior: AppScrollBehavior(),
        theme: buildAppTheme(Brightness.light),
        darkTheme: buildAppTheme(Brightness.dark),
        themeMode: mode,
        home: const HomePage(),
      ),
    );
  }
}

/// Корневой экран: стеклянная плавающая панель + три раздела.
/// IndexedStack сохраняет состояние страниц при переключении вкладок.
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    // Автопроверка обновлений на Android: даём приложению открыться,
    // и через 4 секунды тихо спрашиваем GitHub.
    if (Platform.isAndroid) {
      Future.delayed(const Duration(seconds: 4), () {
        if (mounted) maybeShowUpdateDialog(context);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: IndexedStack(
        index: _tab,
        children: const [
          TodayPage(),
          WardrobePage(),
          SettingsPage(),
        ],
      ),
      bottomNavigationBar: GlassNavBar(
        selectedIndex: _tab,
        onSelected: (i) => setState(() => _tab = i),
      ),
    );
  }
}

/// Плавающая «стеклянная» панель навигации: скруглённая, с блюром фона.
class GlassNavBar extends StatelessWidget {
  const GlassNavBar({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest.withValues(alpha: 0.75),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: scheme.outlineVariant.withValues(alpha: 0.5),
              ),
            ),
            child: NavigationBar(
              selectedIndex: selectedIndex,
              onDestinationSelected: onSelected,
              labelBehavior:
                  NavigationDestinationLabelBehavior.alwaysShow,
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.wb_sunny_outlined),
                  selectedIcon: Icon(Icons.wb_sunny),
                  label: 'Сегодня',
                ),
                NavigationDestination(
                  icon: Icon(Icons.checkroom_outlined),
                  selectedIcon: Icon(Icons.checkroom),
                  label: 'Гардероб',
                ),
                NavigationDestination(
                  icon: Icon(Icons.settings_outlined),
                  selectedIcon: Icon(Icons.settings),
                  label: 'Настройки',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}