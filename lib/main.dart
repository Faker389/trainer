import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'auth/auth_screens.dart';
import 'data/demo.dart';
import 'data/reminders.dart';
import 'data/store.dart';
import 'data/sync.dart';
import 'firebase_options.dart';
import 'ui/home_shell.dart';
import 'ui/widgets.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  } on UnsupportedError {
    // No Firebase config for this platform (e.g. Windows): run fully offline.
    runApp(TrainerApp(offlineStore: demoStore()));
    return;
  } catch (e) {
    runApp(_SetupErrorApp('$e'));
    return;
  }
  // The app keeps its own compact local copy, so Firestore's cache would only duplicate it.
  FirebaseFirestore.instance.settings = const Settings(persistenceEnabled: false);
  await FirebaseAuth.instance.setLanguageCode('pl');
  await ReminderService.init();
  runApp(const TrainerApp());
}

ThemeData _buildTheme({required bool dark}) {
  final scheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF10B981),
    brightness: dark ? Brightness.dark : Brightness.light,
  ).copyWith(
    surface: dark ? const Color(0xFF0D1117) : const Color(0xFFF4F7F5),
    surfaceContainerLowest: dark ? const Color(0xFF0D1117) : const Color(0xFFF4F7F5),
    surfaceContainerLow: dark ? const Color(0xFF131A23) : Colors.white,
    surfaceContainer: dark ? const Color(0xFF182030) : Colors.white,
    surfaceContainerHigh: dark ? const Color(0xFF1E2838) : const Color(0xFFE9F0EC),
    surfaceContainerHighest: dark ? const Color(0xFF253245) : const Color(0xFFDCE5E0),
    primary: dark ? const Color(0xFF34D399) : const Color(0xFF0B9E6E),
    onPrimary: dark ? const Color(0xFF06281C) : Colors.white,
    secondary: dark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB),
    error: dark ? const Color(0xFFF87171) : const Color(0xFFDC2626),
  );
  final muted = scheme.onSurface.withValues(alpha: 0.6);
  final faint = scheme.onSurface.withValues(alpha: 0.38);
  const r16 = Radius.circular(16);
  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    scaffoldBackgroundColor: scheme.surface,
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
      titleTextStyle:
          TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: scheme.onSurface, letterSpacing: 0.2),
    ),
    cardTheme: CardThemeData(
      color: scheme.surfaceContainer,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(r16)),
      clipBehavior: Clip.antiAlias,
    ),
    listTileTheme: ListTileThemeData(
      iconColor: scheme.onSurface.withValues(alpha: 0.7),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(14))),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerHigh.withValues(alpha: 0.55),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: scheme.primary, width: 1.6),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: scheme.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: scheme.error, width: 1.6),
      ),
      labelStyle: TextStyle(color: muted),
      floatingLabelStyle: TextStyle(color: scheme.primary),
      hintStyle: TextStyle(color: faint),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 48),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 48),
        side: BorderSide(color: scheme.outline),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: scheme.primary,
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: scheme.surfaceContainerHigh,
      selectedColor: scheme.primary.withValues(alpha: 0.22),
      secondarySelectedColor: scheme.primary.withValues(alpha: 0.22),
      labelStyle: TextStyle(color: scheme.onSurface, fontWeight: FontWeight.w500),
      secondaryLabelStyle: TextStyle(color: scheme.primary, fontWeight: FontWeight.w700),
      side: BorderSide(color: scheme.outlineVariant),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    ),
    dividerTheme: DividerThemeData(color: scheme.outlineVariant, thickness: 1),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: dark ? scheme.surfaceContainerHighest : const Color(0xFF1E2838),
      contentTextStyle: const TextStyle(color: Colors.white),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: scheme.primary,
      foregroundColor: scheme.onPrimary,
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: scheme.surfaceContainerLow,
      indicatorColor: scheme.primary.withValues(alpha: 0.2),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (s) => TextStyle(
          fontSize: 12,
          fontWeight: s.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500,
          color: s.contains(WidgetState.selected) ? scheme.primary : scheme.onSurface.withValues(alpha: 0.54),
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (s) => IconThemeData(color: s.contains(WidgetState.selected) ? scheme.primary : scheme.onSurface.withValues(alpha: 0.54)),
      ),
    ),
    tabBarTheme: TabBarThemeData(
      labelColor: scheme.primary,
      unselectedLabelColor: scheme.onSurface.withValues(alpha: 0.54),
      labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
      unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
      indicator: UnderlineTabIndicator(
        borderSide: BorderSide(color: scheme.primary, width: 3),
        insets: const EdgeInsets.symmetric(horizontal: 16),
      ),
      indicatorSize: TabBarIndicatorSize.label,
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: scheme.primary),
    pageTransitionsTheme: const PageTransitionsTheme(builders: {
      TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
      TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
    }),
  );
}

final _darkTheme = _buildTheme(dark: true);
final _lightTheme = _buildTheme(dark: false);

Widget _materialApp({Key? key, required Widget home}) => ValueListenableBuilder<ThemeMode>(
      valueListenable: appThemeMode,
      builder: (context, mode, _) => MaterialApp(
        key: key,
        title: 'AI Trainer',
        debugShowCheckedModeBanner: false,
        theme: _lightTheme,
        darkTheme: _darkTheme,
        themeMode: mode,
        locale: const Locale('pl'),
        supportedLocales: const [Locale('pl'), Locale('en')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: home,
      ),
    );

class TrainerApp extends StatefulWidget {
  /// Skips Firebase and runs on this store only (tests).
  final AppStore? offlineStore;
  const TrainerApp({super.key, this.offlineStore});

  @override
  State<TrainerApp> createState() => _TrainerAppState();
}

class _TrainerAppState extends State<TrainerApp> {
  StreamSubscription<User?>? _authSub;
  bool _authKnown = false;
  User? _user;
  AppStore? _store;
  SyncService? _sync;

  @override
  void initState() {
    super.initState();
    if (widget.offlineStore != null) {
      _store = widget.offlineStore;
      _authKnown = true;
      appThemeMode.value = themeModeFromStore(_store!.themeMode);
      return;
    }
    _authSub = FirebaseAuth.instance.authStateChanges().listen(_onUser);
  }

  Future<void> _onUser(User? user) async {
    if (user?.uid == _user?.uid && _authKnown) return;
    _sync?.dispose();
    _sync = null;
    _store = null;
    _user = user;
    _authKnown = true;
    setState(() {});
    if (user == null) return;
    final store = await AppStore.load(user.uid);
    if (!mounted || _user?.uid != user.uid) return;
    appThemeMode.value = themeModeFromStore(store.themeMode);
    ReminderService.reschedule(store);
    store.addListener(() => ReminderService.reschedule(store));
    final sync = SyncService(store, user)..start();
    setState(() {
      _store = store;
      _sync = sync;
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _sync?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<AppStore?>(
        valueListenable: demoStoreOverride,
        builder: (context, demo, _) {
          final store = demo ?? _store;
          if (store == null) {
            if (!_authKnown || _user != null) {
              return _materialApp(
                  home: const Scaffold(body: Center(child: CircularProgressIndicator())));
            }
            return _materialApp(home: const LoginScreen());
          }
          return StoreScope(
            store: store,
            child: SyncScope(
              sync: demo == null ? _sync : null,
              child: _materialApp(
                  key: ValueKey(demo != null ? 'demo' : _user?.uid), home: const HomeShell()),
            ),
          );
        },
      );
}

class _SetupErrorApp extends StatelessWidget {
  final String error;
  const _SetupErrorApp(this.error);

  @override
  Widget build(BuildContext context) => _materialApp(
        home: Scaffold(
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.cloud_off, size: 56, color: Colors.amber),
                const SizedBox(height: 16),
                const Text('Firebase nie jest skonfigurowany', style: TextStyle(fontSize: 20)),
                const SizedBox(height: 12),
                SelectableText(error, textAlign: TextAlign.center),
              ]),
            ),
          ),
        ),
      );
}
