import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _hidePassword = true;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      // AuthGate akan berpindah otomatis berdasarkan authStateChanges().
    } on FirebaseAuthException catch (error) {
      setState(() => _errorMessage = _messageForAuthError(error.code));
    } catch (_) {
      setState(() => _errorMessage = 'Login belum berhasil. Periksa koneksi dan coba lagi.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _messageForAuthError(String code) {
    switch (code) {
      case 'invalid-email':
        return 'Format email tidak valid.';
      case 'user-disabled':
        return 'Akun ini dinonaktifkan. Hubungi administrator.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Email atau kata sandi tidak sesuai.';
      case 'too-many-requests':
        return 'Terlalu banyak percobaan. Tunggu sebentar lalu coba lagi.';
      case 'network-request-failed':
        return 'Koneksi internet bermasalah. Periksa jaringan kamu.';
      case 'operation-not-allowed':
        return 'Login Email/Password belum diaktifkan di Firebase Authentication.';
      default:
        return 'Login gagal ($code). Periksa konfigurasi Firebase Authentication.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFEAF4FC), Color(0xFFF7FAFD), Color(0xFFDCECF9)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(22),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: width < 600 ? 440 : 460),
              child: Card(
                elevation: 8,
                shadowColor: const Color(0x22123B65),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(28, 30, 28, 28),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                          child: Container(
                            width: 72,
                            height: 72,
                            decoration: const BoxDecoration(
                              color: Color(0xFF147DCE),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.water_drop, color: Colors.white, size: 38),
                          ),
                        ),
                        const SizedBox(height: 18),
                        const Text(
                          'Monitoring pH Air',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold, color: Color(0xFF123B65)),
                        ),
                        const SizedBox(height: 7),
                        const Text(
                          'Masuk untuk melihat pemantauan kualitas air',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.blueGrey, height: 1.45),
                        ),
                        const SizedBox(height: 28),
                        const Text('Email', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF123B65))),
                        const SizedBox(height: 7),
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          autofillHints: const [AutofillHints.username, AutofillHints.email],
                          decoration: InputDecoration(
                            hintText: 'nama@email.com',
                            prefixIcon: const Icon(Icons.email_outlined),
                            filled: true,
                            fillColor: const Color(0xFFF7FAFD),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          ),
                          validator: (value) {
                            final email = value?.trim() ?? '';
                            if (email.isEmpty || !email.contains('@')) return 'Masukkan email yang valid.';
                            return null;
                          },
                        ),
                        const SizedBox(height: 17),
                        const Text('Kata sandi', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF123B65))),
                        const SizedBox(height: 7),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _hidePassword,
                          autofillHints: const [AutofillHints.password],
                          onFieldSubmitted: (_) => _login(),
                          decoration: InputDecoration(
                            hintText: 'Masukkan kata sandi',
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              tooltip: _hidePassword ? 'Tampilkan kata sandi' : 'Sembunyikan kata sandi',
                              onPressed: () => setState(() => _hidePassword = !_hidePassword),
                              icon: Icon(_hidePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                            ),
                            filled: true,
                            fillColor: const Color(0xFFF7FAFD),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          ),
                          validator: (value) => (value == null || value.isEmpty) ? 'Kata sandi wajib diisi.' : null,
                        ),
                        if (_errorMessage != null) ...[
                          const SizedBox(height: 14),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(color: const Color(0xFFFFF0EE), borderRadius: BorderRadius.circular(10)),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.error_outline, color: Color(0xFFB93B32), size: 20),
                                const SizedBox(width: 8),
                                Expanded(child: Text(_errorMessage!, style: const TextStyle(color: Color(0xFF9F3029), fontSize: 12, height: 1.4))),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 22),
                        SizedBox(
                          height: 49,
                          child: FilledButton.icon(
                            onPressed: _isLoading ? null : _login,
                            icon: _isLoading
                                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Icon(Icons.login),
                            label: Text(_isLoading ? 'Memeriksa akun...' : 'Masuk'),
                            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF147DCE), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Akun dibuat oleh administrator. Jika belum memiliki akses, hubungi pengelola sistem.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 11, color: Colors.blueGrey, height: 1.5),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
