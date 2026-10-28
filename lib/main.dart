import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'data/demo_repository.dart';
import 'data/expense_repository.dart';
import 'data/firestore_repository.dart';
import 'firebase_options.dart';
import 'main_screen.dart';
import 'screens/login_screen.dart';
import 'screens/onboarding_screen.dart';
import 'theme/app_theme.dart';

/// `flutter run --dart-define=DEMO_MODE=true` runs the whole app on sample
/// data with no sign-in. Ignored in release builds.
const bool kDemoMode =
    bool.fromEnvironment('DEMO_MODE') && !kReleaseMode;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kDemoMode) {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  }
  final prefs = await SharedPreferences.getInstance();
  final settings = AppSettings(prefs);
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  runApp(MyApp(settings: settings));
}

/// App-wide preferences stored on the device.
class AppSettings extends ChangeNotifier {
  final SharedPreferences _prefs;

  AppSettings(this._prefs);

  ThemeMode get themeMode => switch (_prefs.getString('theme_mode')) {
    'light' => ThemeMode.light,
    'dark' => ThemeMode.dark,
    _ => ThemeMode.system,
  };

  set themeMode(ThemeMode mode) {
    _prefs.setString('theme_mode', mode.name);
    notifyListeners();
  }

  bool get onboardingComplete => _prefs.getBool('onboarding_complete') ?? false;

  set onboardingComplete(bool value) {
    _prefs.setBool('onboarding_complete', value);
    notifyListeners();
  }
}

class AppSettingsScope extends InheritedNotifier<AppSettings> {
  const AppSettingsScope({
    super.key,
    required AppSettings settings,
    required super.child,
  }) : super(notifier: settings);

  static AppSettings of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppSettingsScope>()!.notifier!;
}

class MyApp extends StatefulWidget {
  final AppSettings settings;

  /// Lets tests inject a repository and skip Firebase entirely.
  final ExpenseRepository? repositoryOverride;

  const MyApp({super.key, required this.settings, this.repositoryOverride});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  /// Fixed repository for demo mode and tests; otherwise one per signed-in
  /// user, created from the auth stream.
  ExpenseRepository? get _fixedRepo =>
      widget.repositoryOverride ?? (kDemoMode ? _demoRepository : null);

  FirestoreRepository? _userRepo;
  Stream<User?>? _auth;

  @override
  void initState() {
    super.initState();
    if (_fixedRepo == null) _auth = FirebaseAuth.instance.authStateChanges();
  }

  @override
  Widget build(BuildContext context) {
    return AppSettingsScope(
      settings: widget.settings,
      child: ListenableBuilder(
        listenable: widget.settings,
        builder: (context, _) {
          final fixed = _fixedRepo;
          if (fixed != null) return _app(fixed, signedIn: true);
          return StreamBuilder<User?>(
            stream: _auth,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return _app(null, signedIn: false, loading: true);
              }
              final user = snap.data;
              if (user == null) {
                _userRepo = null;
              } else if (_userRepo?.user.uid != user.uid) {
                _userRepo = FirestoreRepository(user);
              }
              return _app(_userRepo, signedIn: user != null);
            },
          );
        },
      ),
    );
  }

  /// The repository wraps MaterialApp so pushed routes (Add, Edit,
  /// Settings) can reach it too. Keying by user resets navigation when a
  /// different person signs in.
  Widget _app(ExpenseRepository? repo, {required bool signedIn, bool loading = false}) {
    final settings = widget.settings;
    final Widget home;
    if (!settings.onboardingComplete) {
      home = OnboardingScreen(onComplete: () => settings.onboardingComplete = true);
    } else if (loading) {
      home = const Scaffold(body: Center(child: CircularProgressIndicator()));
    } else if (!signedIn || repo == null) {
      home = const LoginScreen();
    } else {
      home = const MainScreen();
    }
    final app = MaterialApp(
      key: ValueKey(repo is FirestoreRepository ? repo.user.uid : signedIn),
      title: 'Asrani Expenses',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: settings.themeMode,
      home: home,
    );
    return repo == null ? app : RepositoryScope(repository: repo, child: app);
  }
}

final DemoRepository _demoRepository = DemoRepository();
