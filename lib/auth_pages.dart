import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LoginPage extends StatefulWidget {
  final VoidCallback onLoginSuccess;
  const LoginPage({super.key, required this.onLoginSuccess});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final supabase = Supabase.instance.client;
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  String? error;
  bool isLoading = false;

  Future<void> signIn() async {
    setState(() {
      error = null;
      isLoading = true;
    });

    final email = emailController.text.trim();
    final password = passwordController.text.trim();

    try {
      final res = await supabase.auth.signInWithPassword(email: email, password: password);
      if (res.session != null) {
        widget.onLoginSuccess();
      } else {
        setState(() {
          error = 'Login failed. Please check your credentials.';
        });
      }
    } catch (e) {
      setState(() {
        if (e.toString().toLowerCase().contains('failed host lookup')) {
          error = 'Network error. Please check your internet connection.';
        } else if (e.toString().toLowerCase().contains('invalid login credentials')) {
          error = 'Incorrect username or password.';
        } else if (e.toString().toLowerCase().contains('missing email')) {
          error = 'Please enter email and/or password';
        } else if (e.toString().toLowerCase().contains('email not confirmed')) {
          error = 'Please confirm email using the email sent to you';
        } else {
          error = 'Login failed. Please try again.';
        }
      });
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  void goToSignUp() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => SignUpPage(onSignUpSuccess: widget.onLoginSuccess)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: emailController,
              decoration: const InputDecoration(labelText: 'Email'),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: passwordController,
              decoration: const InputDecoration(labelText: 'Password'),
              obscureText: true,
            ),
            if (error != null) ...[
              const SizedBox(height: 12),
              Text(error!, style: const TextStyle(color: Colors.red)),
            ],
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: isLoading ? null : signIn,
              child: isLoading ? const CircularProgressIndicator() : const Text('Login'),
            ),
            const SizedBox(height: 20),
            TextButton(
              onPressed: goToSignUp,
              child: const Text('Don\'t have an account? Sign up'),
            ),
          ],
        ),
      ),
    );
  }
}

class SignUpPage extends StatefulWidget {
  final VoidCallback onSignUpSuccess;
  const SignUpPage({super.key, required this.onSignUpSuccess});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final supabase = Supabase.instance.client;
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  String? error;
  bool isLoading = false;

  Future<void> signUp() async {
    setState(() {
      error = null;
      isLoading = true;
    });

    final email = emailController.text.trim();
    final password = passwordController.text.trim();

    try {
      final res = await supabase.auth.signUp(email: email, password: password);
      if (res.user != null) {
        widget.onSignUpSuccess();
        Navigator.pop(context); // go back to login after sign up success
      } else {
        setState(() {
          error = 'Signup failed. Try again.';
        });
      }
    } catch (e) {
      setState(() {
      String err = e.toString().toLowerCase();

			if (err.contains('failed host lookup')) {
				error = 'Network error. Please check your internet connection.';
			} else if (err.contains('password should be at least')) {
				error = 'Password must be at least 6 characters';
			} else if (err.contains('email address') && err.contains('is invalid')) {
				error = 'Invalid email address.';
			} else if (err.contains('anonymous sign-ins are disabled')) {
				error = 'Please enter an email address';
			} else if (err.contains('signup requires a valid password')) {
				error = 'Please enter a password.';
			} else if (err.contains('unable to validate email address: invalid format')) {
				error = 'Please enter a valid email address.';
			} else {
				error = 'Signup failed. Please try again.';
			}
      });
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  void goToLogin() {
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sign Up')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: emailController,
              decoration: const InputDecoration(labelText: 'Email'),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: passwordController,
              decoration: const InputDecoration(labelText: 'Password'),
              obscureText: true,
            ),
            if (error != null) ...[
              const SizedBox(height: 12),
              Text(error!, style: const TextStyle(color: Colors.red)),
            ],
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: isLoading ? null : signUp,
              child: isLoading ? const CircularProgressIndicator() : const Text('Sign Up'),
            ),
            const SizedBox(height: 20),
            TextButton(
              onPressed: goToLogin,
              child: const Text('Already have an account? Login'),
            ),
          ],
        ),
      ),
    );
  }
}