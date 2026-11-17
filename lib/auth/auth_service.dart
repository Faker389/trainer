import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Web OAuth client id for Google sign-in. Leave empty when google-services.json provides it.
const _googleServerClientId = String.fromEnvironment('GOOGLE_WEB_CLIENT_ID');

class AuthCancelled implements Exception {}

abstract final class AuthService {
  static FirebaseAuth get _auth => FirebaseAuth.instance;
  static bool _googleReady = false;

  static User? get currentUser => _auth.currentUser;

  static bool get usesPassword => currentUser?.providerData.any((p) => p.providerId == 'password') ?? false;

  static Future<void> signIn(String email, String password) =>
      _auth.signInWithEmailAndPassword(email: email.trim(), password: password);

  static Future<void> register(String name, String email, String password) async {
    final cred = await _auth.createUserWithEmailAndPassword(email: email.trim(), password: password);
    final user = cred.user!;
    if (name.trim().isNotEmpty) await user.updateDisplayName(name.trim());
    await user.sendEmailVerification();
  }

  static Future<void> sendPasswordReset(String email) => _auth.sendPasswordResetEmail(email: email.trim());

  static Future<GoogleSignInAccount> _googleAccount() async {
    if (!_googleReady) {
      await GoogleSignIn.instance.initialize(serverClientId: _googleServerClientId.isEmpty ? null : _googleServerClientId);
      _googleReady = true;
    }
    try {
      return await GoogleSignIn.instance.authenticate();
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) throw AuthCancelled();
      rethrow;
    }
  }

  static Future<AuthCredential> _googleCredential() async {
    final account = await _googleAccount();
    return GoogleAuthProvider.credential(idToken: account.authentication.idToken);
  }

  static Future<void> signInWithGoogle() async => _auth.signInWithCredential(await _googleCredential());

  static Future<void> resendVerification() async => currentUser?.sendEmailVerification();

  /// Reloads the user and reports whether the e-mail is verified now.
  static Future<bool> refreshVerified() async {
    await currentUser?.reload();
    return _auth.currentUser?.emailVerified ?? false;
  }

  /// Needed before sensitive operations (password change, account deletion).
  static Future<void> reauthenticate({String? password}) async {
    final user = currentUser!;
    final credential = usesPassword
        ? EmailAuthProvider.credential(email: user.email!, password: password ?? '')
        : await _googleCredential();
    await user.reauthenticateWithCredential(credential);
  }

  static Future<void> changePassword(String current, String next) async {
    await reauthenticate(password: current);
    await currentUser!.updatePassword(next);
  }

  static Future<void> signOut() async {
    if (_googleReady) await GoogleSignIn.instance.signOut().catchError((_) {});
    await _auth.signOut();
  }

  static Future<void> deleteUser() async {
    await currentUser!.delete();
    if (_googleReady) await GoogleSignIn.instance.disconnect().catchError((_) {});
  }

  static String message(Object e) {
    if (e is FirebaseAuthException) {
      return switch (e.code) {
        'invalid-email' => 'Nieprawidłowy adres e-mail.',
        'user-disabled' => 'To konto zostało zablokowane.',
        'user-not-found' || 'wrong-password' || 'invalid-credential' => 'Nieprawidłowy e-mail lub hasło.',
        'email-already-in-use' => 'Konto z tym adresem e-mail już istnieje. Zaloguj się albo zresetuj hasło.',
        'weak-password' => 'Hasło jest za słabe. Użyj co najmniej 6 znaków.',
        'too-many-requests' => 'Za dużo prób. Spróbuj ponownie za chwilę.',
        'network-request-failed' => 'Brak połączenia z internetem.',
        'requires-recent-login' => 'Ze względów bezpieczeństwa zaloguj się ponownie i powtórz operację.',
        'operation-not-allowed' => 'Ta metoda logowania nie jest włączona w konsoli Firebase.',
        'account-exists-with-different-credential' =>
          'Konto z tym e-mailem istnieje i używa innej metody logowania.',
        _ => e.message ?? 'Błąd logowania (${e.code}).',
      };
    }
    if (e is GoogleSignInException) return 'Logowanie Google nie powiodło się: ${e.description ?? e.code.name}';
    return '$e';
  }
}
