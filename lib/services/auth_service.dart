import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // iOS requires the CLIENT_ID from GoogleService-Info.plist
  // Web requires the web client ID
  // Android uses google-services.json automatically
  late final GoogleSignIn _googleSignIn;

  AuthService() {
    String? clientId;

    if (kIsWeb) {
      // Web client ID from Firebase Console
      clientId =
          '423024582059-8buucbs9j9nttes047f8tostbrpobdvt.apps.googleusercontent.com';
    } else if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      // iOS CLIENT_ID from GoogleService-Info.plist
      clientId =
          '423024582059-58golj4v958c0gfierouqbbf2jf68vb9.apps.googleusercontent.com';
    }
    // Android: clientId should be null, it uses google-services.json automatically

    _googleSignIn = GoogleSignIn(
      clientId: clientId,
      scopes: ['email', 'profile'],
    );
  }

  // Auth State Stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Get Current User
  User? get currentUser => _auth.currentUser;

  // Sign In with Google
  Future<UserCredential?> signInWithGoogle() async {
    // Trigger the authentication flow
    final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
    if (googleUser == null) return null; // The user canceled the sign-in

    // Obtain the auth details from the request
    final GoogleSignInAuthentication googleAuth =
        await googleUser.authentication;

    // Create a new credential
    final OAuthCredential credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    // Once signed in, return the UserCredential
    return await _auth.signInWithCredential(credential);
  }

  // Sign Out
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }
}
