import 'package:firebase_auth/firebase_auth.dart';

/// Envoltura delgada sobre Firebase Auth. No contiene lógica de UI.
class AuthService {
  AuthService({FirebaseAuth? auth}) : _auth = auth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;

  Stream<User?> get cambiosDeSesion => _auth.authStateChanges();

  User? get usuarioActual => _auth.currentUser;

  Future<UserCredential> iniciarSesion(String correo, String contrasena) =>
      _auth.signInWithEmailAndPassword(email: correo.trim().toLowerCase(), password: contrasena);

  Future<void> recuperarContrasena(String correo) => _auth.sendPasswordResetEmail(email: correo.trim().toLowerCase());

  Future<void> cerrarSesion() => _auth.signOut();
}
