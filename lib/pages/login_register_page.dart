//login_register_page

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:firebase_auth/firebase_auth.dart';

void main() {
  runApp(const LoginRegisterPage());
}

class LoginRegisterPage extends StatefulWidget {
  const LoginRegisterPage({super.key});

  @override
  _LoginRegisterPageState createState() => _LoginRegisterPageState();
}

class _LoginRegisterPageState extends State<LoginRegisterPage> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController otpController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String errorMessage = '';
  String _verificationId = '';
  bool isEmailLogin = true;
  bool isLoginMode = false;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    phoneController.dispose();
    otpController.dispose();
    super.dispose();
  }


  Future<void> signInWithEmailAndPassword() async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: emailController.text,
        password: passwordController.text,
      );
      // Navigate to your home page if sign-in is successful
    } catch (error) {
      setState(() {
        errorMessage = error.toString();
      });
    }
  }

  Future<void> createUserWithEmailAndPassword() async {
    try {
      await _auth.createUserWithEmailAndPassword(
        email: emailController.text,
        password: passwordController.text,
      );
      // Navigate to your home page if registration is successful
    } catch (error) {
      setState(() {
        errorMessage = error.toString();
      });
    }
  }

  void verifyPhoneNumber() async {
    await _auth.verifyPhoneNumber(
      phoneNumber: phoneController.text,
      verificationCompleted: (PhoneAuthCredential credential) async {
        await _auth.signInWithCredential(credential);
        // Navigate to the home page on automatic verification success
      },
      verificationFailed: (FirebaseAuthException e) {
        setState(() {
          errorMessage = e.message ?? 'Verification failed';
        });
      },
      codeSent: (String verificationId, int? resendToken) {
        setState(() {
          _verificationId = verificationId;
          // Show a field to enter OTP
        });
      },
      codeAutoRetrievalTimeout: (String verificationId) {
        setState(() {
          _verificationId = verificationId;
        });
      },
    );
  }

  void signInWithOTP() async {
    try {
      final AuthCredential credential = PhoneAuthProvider.credential(
        verificationId: _verificationId,
        smsCode: otpController.text,
      );
      await _auth.signInWithCredential(credential);
      // Navigate to the home page on manual verification success
    } catch (e) {
      setState(() {
        errorMessage = e.toString();
      });
    }
  }


  Widget entryField(String title, TextEditingController controller, bool isPassword, {double bottomPadding = 10}) {
    return Padding(
      padding: EdgeInsets.only(bottom: bottomPadding),
      child: TextFormField(
        controller: controller,
        obscureText: isPassword,
        decoration: InputDecoration(
          labelText: title,
          border: OutlineInputBorder(),
        ),
      ),
    );
  }

  Widget submitButton(String text, VoidCallback onPressed) {
    return ElevatedButton(
      onPressed: onPressed,
      child: Text(text),
      style: ElevatedButton.styleFrom(
        primary: Color.fromARGB(255, 63, 102, 105),
        minimumSize: const Size(double.infinity, 50),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Account Creation',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        fontFamily: 'Poppins',
      ),
      home: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black),
            onPressed: () {
              if (Navigator.canPop(context)) {
                Navigator.pop(context);
              }
            },
          ),
          actions: [
            TextButton(
              onPressed: () {
                setState(() {
                  isLoginMode = !isLoginMode;
                });
              },
              child: Text(
                isLoginMode ? 'Sign Up' : 'Log In',
                style: const TextStyle(color: Colors.black),
              ),
            ),
          ],
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 32),
                const Text(
                  'Create Auki Chess Account', // Heading text added back
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),




                const SizedBox(height: 32),
                SvgPicture.asset(
                  'assets/chess_logo.svg',
                  height: 100,
                ),
                const SizedBox(height: 32),
                if (isLoginMode) ...[
                  entryField('Email', emailController, false),
                  entryField('Password', passwordController, true),
                  const SizedBox(height: 20),
                  submitButton('Log In', signInWithEmailAndPassword),
                ] else ...[
                  if (isEmailLogin) ...[
                    entryField('Email', emailController, false),
                    entryField('Password', passwordController, true),
                    const SizedBox(height: 20),
                    submitButton('Sign Up with Email', createUserWithEmailAndPassword),
                  ] else ...[
                    entryField('Phone Number', phoneController, false),
                    if (_verificationId.isNotEmpty)
                      entryField('OTP', otpController, false),
                    const SizedBox(height: 20),
                    if (_verificationId.isEmpty)
                      submitButton('Send OTP', verifyPhoneNumber),
                    if (_verificationId.isNotEmpty)
                      submitButton('Verify OTP', signInWithOTP),
                  ],
                ],
                const SizedBox(height: 16),
                if (!isLoginMode)
                  const Text(
                    'OR',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                const SizedBox(height: 16),
                if (!isLoginMode && !isEmailLogin)
                  submitButton('Continue with Email', () {
                    setState(() {
                      isEmailLogin = true;
                    });
                  }),
                if (!isLoginMode && isEmailLogin)
                  submitButton('Continue with Phone', () {
                    setState(() {
                      isEmailLogin = false;
                    });
                  }),
                if (errorMessage.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 20),
                    child: Text(
                      errorMessage,
                      style: const TextStyle(color: Colors.red),
                      textAlign: TextAlign.center,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
