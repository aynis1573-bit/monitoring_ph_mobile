import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'data/repositories/sensor_repository.dart';
import 'data/services/firebase_sensor_service.dart';
import 'viewmodels/home_view_model.dart';
import 'views/home_page.dart';
import 'views/login_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MonitoringPhApp());
}

class MonitoringPhApp extends StatelessWidget {
  const MonitoringPhApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Monitoring pH Air',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF147DCE)),
        useMaterial3: true,
      ),
      home: const AuthGate(),
    );
  }
}

/// Menampilkan halaman login jika belum masuk, dan memeriksa profil role
/// sebelum membuka dashboard.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _AuthLoadingPage(message: 'Memeriksa sesi login...');
        }
        if (snapshot.hasError) {
          return _AuthProblemPage(
            message: 'Tidak dapat memeriksa sesi login. Periksa koneksi dan konfigurasi Firebase.',
          );
        }
        final user = snapshot.data;
        if (user == null) return const LoginPage();
        return RoleGate(user: user);
      },
    );
  }
}

class RoleGate extends StatefulWidget {
  final User user;

  const RoleGate({super.key, required this.user});

  @override
  State<RoleGate> createState() => _RoleGateState();
}

class _RoleGateState extends State<RoleGate> {
  late Future<DocumentSnapshot<Map<String, dynamic>>> _profileFuture;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void didUpdateWidget(covariant RoleGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.user.uid != widget.user.uid) _loadProfile();
  }

  void _loadProfile() {
    _profileFuture = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.user.uid)
        .get();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: _profileFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _AuthLoadingPage(message: 'Memuat hak akses akun...');
        }
        if (snapshot.hasError) {
          return _AuthProblemPage(
            message: 'Login berhasil, tetapi profil hak akses tidak dapat dibaca. Pastikan dokumen users/${widget.user.uid} tersedia dan aturan Firestore mengizinkan pengguna membaca profilnya sendiri.',
            canSignOut: true,
          );
        }

        final profile = snapshot.data?.data();
        final role = profile?['role']?.toString().trim().toLowerCase();
        if (role != 'pengelola' && role != 'maintenance') {
          return _AuthProblemPage(
            message: 'Akun ini belum memiliki role yang valid. Minta administrator mengisi field role dengan "pengelola" atau "maintenance" pada dokumen users/${widget.user.uid}.',
            canSignOut: true,
          );
        }
        return AuthenticatedHome(role: role!);
      },
    );
  }
}

class AuthenticatedHome extends StatefulWidget {
  final String role;

  const AuthenticatedHome({super.key, required this.role});

  @override
  State<AuthenticatedHome> createState() => _AuthenticatedHomeState();
}

class _AuthenticatedHomeState extends State<AuthenticatedHome> {
  late final HomeViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    final service = FirebaseSensorService();
    final repository = SensorRepository(service);
    _viewModel = HomeViewModel(repository);
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return HomePage(viewModel: _viewModel, currentRole: widget.role);
  }
}

class _AuthLoadingPage extends StatelessWidget {
  final String message;

  const _AuthLoadingPage({required this.message});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F8FC),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 14),
            Text(message, style: const TextStyle(color: Color(0xFF123B65))),
          ],
        ),
      ),
    );
  }
}

class _AuthProblemPage extends StatelessWidget {
  final String message;
  final bool canSignOut;

  const _AuthProblemPage({required this.message, this.canSignOut = false});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F8FC),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.lock_outline, size: 42, color: Color(0xFF147DCE)),
                    const SizedBox(height: 12),
                    const Text('Akses akun belum siap', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    SelectableText(message, textAlign: TextAlign.center),
                    const SizedBox(height: 18),
                    if (canSignOut)
                      FilledButton.icon(
                        onPressed: () => FirebaseAuth.instance.signOut(),
                        icon: const Icon(Icons.logout),
                        label: const Text('Keluar dari akun'),
                      )
                    else
                      OutlinedButton(
                        onPressed: () => Navigator.of(context).pushReplacement(
                          MaterialPageRoute<void>(builder: (_) => const LoginPage()),
                        ),
                        child: const Text('Kembali ke login'),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
