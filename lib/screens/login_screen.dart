import 'package:ainme_vault/main.dart';
import 'package:ainme_vault/screens/forgot_password_screen.dart';
import 'package:ainme_vault/services/notification_service.dart';
import 'package:flutter/material.dart';
import 'package:ainme_vault/theme/app_theme.dart';
import 'package:ainme_vault/screens/signup_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/services.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _submitted = false;
  AuthCredential? _pendingGoogleCredential;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    setState(() {
      _submitted = true;
    });

    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      TextInput.finishAutofillContext();

      final user = FirebaseAuth.instance.currentUser;

      // 🔗 LINK GOOGLE CREDENTIAL IF IT EXISTS
      if (_pendingGoogleCredential != null && user != null) {
        await user.linkWithCredential(_pendingGoogleCredential!);
        _pendingGoogleCredential = null;
      }

      if (user != null && !user.emailVerified) {
        await FirebaseAuth.instance.signOut();

        _showSnackBar(
          message: "Please verify your email before logging in",
          isError: true,
        );
        return;
      }

      _showSnackBar(message: "Login successful", isError: false);

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const MainScreen()),
        (route) => false, // Remove all previous routes
      );
    } on FirebaseAuthException catch (e) {
      String message = "Incorrect email or password";

      if (e.code == 'invalid-credential') {
        message = "Invalid email or password";
      } else if (e.code == 'user-disabled') {
        message = "This account has been disabled";
      } else {
        message = "Login failed. Please try again";
      }

      _showSnackBar(message: message, isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);

    final GoogleSignIn googleSignIn = GoogleSignIn();

    try {
      // 🔥 (1) Clear stale Google session FIRST
      await googleSignIn.signOut();

      // 🔐 Start Google Sign-In
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();

      if (googleUser == null) {
        // User cancelled
        return;
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // 🔐 Firebase Sign-In
      await FirebaseAuth.instance.signInWithCredential(credential);
      await NotificationService.init();

      // 🔥 (2) Clear pending credential after success
      _pendingGoogleCredential = null;

      _showSnackBar(message: "Signed in with Google", isError: false);

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const MainScreen()),
        (route) => false, // Remove all previous routes
      );
    } on FirebaseAuthException catch (e) {
      if (e.code == 'account-exists-with-different-credential') {
        await _handleAccountLinking(e);
      } else {
        _showSnackBar(
          message: e.message ?? "Google sign-in failed",
          isError: true,
        );
      }
    } catch (e) {
      _showSnackBar(
        message: "Google sign-in cancelled or interrupted",
        isError: true,
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleAccountLinking(FirebaseAuthException e) async {
    final email = e.email;
    final pendingCredential = e.credential;

    if (email == null || pendingCredential == null) return;

    // Store Google credential temporarily
    _pendingGoogleCredential = pendingCredential;

    // Ask user to login manually with email/password
    _showSnackBar(
      message: "This email is already registered. Login to link Google.",
      isError: true,
    );

    // Autofill email for convenience
    _emailController.text = email;
  }

  void _showSnackBar({required String message, required bool isError}) {
    ScaffoldMessenger.of(context).clearSnackBars();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        backgroundColor: isError ? Colors.redAccent : Colors.green,
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isError
                    ? Icons.error_outline_rounded
                    : Icons.check_circle_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Get the size of the screen
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: AppTheme.lightTheme.scaffoldBackgroundColor,
      // Use a Stack to layer the background and the content
      body: Stack(
        children: [
          // 1. Purple Header Background (Fixed at Top)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: size.height * 0.25, // Increased height (25%)
            child: Container(
              decoration: const BoxDecoration(
                image: DecorationImage(
                  image: AssetImage('assets/logban.png'),
                  fit: BoxFit.cover,
                ),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
              ),
            ),
          ),

          // 2. Centered Scrollable Content
          Positioned.fill(
            child: Center(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                  horizontal: 25,
                ), // Increased horizontal padding for smaller container
                child: Container(
                  width: double.infinity,
                  margin: EdgeInsets.only(top: size.height * 0.25),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 23, // Reduced padding
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: AutofillGroup(
                    child: Form(
                      key: _formKey,
                      autovalidateMode: _submitted
                          ? AutovalidateMode.onUserInteraction
                          : AutovalidateMode.disabled,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Title
                          const Text(
                            "Welcome to",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 16, // Reduced size
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            "AniFlux Login Now!",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 22, // Reduced size
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 24), // Reduced spacing
                          // Email Field
                          _buildLabel("Email"),
                          const SizedBox(height: 6),
                          _buildTextField(
                            controller: _emailController,
                            hintText: "example@gmail.com",
                            autofillHints: const [AutofillHints.email],
                            keyboardType: TextInputType.emailAddress,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return "Email is required";
                              }
                              if (!RegExp(
                                r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                              ).hasMatch(value.trim())) {
                                return "Enter a valid email";
                              }
                              return null;
                            },
                          ),

                          const SizedBox(height: 16), // Reduced spacing
                          // Password Field
                          _buildLabel("Password"),
                          const SizedBox(height: 8),
                          _buildTextField(
                            controller: _passwordController,
                            hintText: "• • • • • • • •",
                            autofillHints: const [AutofillHints.password],
                            obscureText: _obscurePassword,
                            showToggle: true,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return "Password is required";
                              }
                              if (value.length < 8) {
                                return "Password must be at least 8 characters";
                              }
                              return null;
                            },
                          ),

                          // Forgot Password
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        const ForgotPasswordScreen(),
                                  ),
                                );
                              },

                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.fromLTRB(0, 4, 0, 4),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: Text(
                                "Forgot Password?",
                                style: TextStyle(
                                  color: AppTheme.primary.withOpacity(0.9),
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13, // Reduced size
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 20), // Reduced spacing
                          // Login Button
                          ElevatedButton(
                            onPressed: _isLoading ? null : _login,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primary,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(50),
                              ),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text(
                                    "Login",
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                          const SizedBox(height: 24),

                          // "Or Sign in with"
                          const Text(
                            "Or Sign in with",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.black54,
                              fontSize: 13, // Reduced size
                              fontWeight: FontWeight.w500,
                            ),
                          ),

                          const SizedBox(height: 20), // Reduced spacing
                          // Social Buttons
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _buildSocialButton(
                                label: "Google",
                                image: "assets/Google__G__logo.png",
                                onTap: _isLoading
                                    ? () {
                                        HapticFeedback.lightImpact();
                                      }
                                    : _signInWithGoogle,
                              ),
                              const SizedBox(width: 20),
                              _buildSocialButton(
                                label: "Apple",
                                image: "assets/Apple_logo_black.png",
                                onTap: () {
                                  HapticFeedback.lightImpact();
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text(
                                "Don't have a Account ",
                                style: TextStyle(
                                  color: Colors.black87,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              GestureDetector(
                                onTap: () {
                                  Navigator.pushReplacement(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const SignupScreen(),
                                    ),
                                  );
                                },
                                child: const Text(
                                  "Signup",
                                  style: TextStyle(
                                    color: AppTheme.primary,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 14, // Reduced size
        fontWeight: FontWeight.w600,
        color: Colors.black87,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    bool obscureText = false,
    bool showToggle = false,
    TextInputType keyboardType = TextInputType.text,
    List<String>? autofillHints,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      autofillHints: autofillHints,
      validator: validator,
      autocorrect: false,
      enableSuggestions: false,

      onChanged: (_) {
        if (_submitted && _formKey.currentState != null) {
          _formKey.currentState!.validate();
        }
      },
      style: const TextStyle(fontSize: 14, color: Colors.black87),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),

        filled: true,
        fillColor: Colors.grey.shade100,

        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 16,
        ),

        // 👁️ PASSWORD TOGGLE
        suffixIcon: showToggle
            ? IconButton(
                splashRadius: 20,
                icon: Icon(
                  obscureText
                      ? Icons.visibility_off_rounded
                      : Icons.visibility_rounded,
                  size: 20,
                  color: Colors.grey.shade600,
                ),
                onPressed: () {
                  setState(() {
                    _obscurePassword = !_obscurePassword;
                  });
                },
              )
            : null,

        // NORMAL
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey.shade100),
        ),

        // FOCUSED
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: AppTheme.primary, width: 1.6),
        ),

        // ERROR
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1.4),
        ),

        // FOCUSED ERROR
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1.6),
        ),

        errorStyle: const TextStyle(
          fontSize: 11,
          height: 1.3,
          color: Colors.redAccent,
        ),
      ),
    );
  }

  Widget _buildSocialButton({
    required String label,
    required String image,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(12),
        width: 55, // Reduced size
        height: 55, // Reduced size
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: Image.asset(
            image,
            width: 32,
            height: 32,
            errorBuilder: (context, error, stackTrace) =>
                const Icon(Icons.error_outline),
          ),
        ),
      ),
    );
  }
}
