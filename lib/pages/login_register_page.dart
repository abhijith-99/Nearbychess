import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'package:uuid/uuid.dart';
import 'package:shared_preferences/shared_preferences.dart';



void main() {
  runApp(const LoginRegisterPage());
}

class LoginRegisterPage extends StatefulWidget {
  const LoginRegisterPage({super.key});

  @override
  _LoginRegisterPageState createState() => _LoginRegisterPageState();
}

class _LoginRegisterPageState extends State<LoginRegisterPage> {
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController otpController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool showGoogleSignInButton = true; // Initially, the Google sign-in button is visible

  bool showSignInOptions = true; // Initially, show the sign-in options

  final double buttonHeight = 50.0; // Standard height for buttons


  final RoundedRectangleBorder buttonShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(30), // Example border radius
  );


  final InputDecoration sharedInputDecoration = InputDecoration(
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(30), // Consistent border radius
      borderSide: BorderSide(color: Colors.white), // Adjust border color if needed
    ),
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20), // Adjust padding to match button height
  );


  // Using a getter to access the instance member buttonHeight
  ButtonStyle get sharedButtonStyle => ElevatedButton.styleFrom(
    primary: Colors.transparent, // Transparent background for the button
    onPrimary: Colors.white, // Text color
    side: BorderSide(color: Colors.white), // Border color for the button
    elevation: 0,
    minimumSize: Size(double.infinity, buttonHeight), // Full width and consistent height
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(30), // Consistent border radius
    ),
  );



  String errorMessage = '';
  String _verificationId = '';
  bool isEmailLogin = false;
  bool showPhoneNumberField = false;
  bool showPhoneNumberInput = false;
  bool showOtpInput = false;
  bool isSignUp = false; // Default to sign up mode4
  bool _isSigningIn = false;






  @override
  void dispose() {
    phoneController.dispose();
    otpController.dispose();
    super.dispose();
  }












  String formatPhoneNumber(String number) {
    // Check if the number already starts with '+91'
    if (!number.startsWith('+91')) {
      // If not, prepend '+91' to the number
      return '+91$number';
    }
    // If the number already starts with '+91', return it as is
    return number;
  }


  void verifyPhoneNumber() async {
    String formattedNumber = formatPhoneNumber(phoneController.text);

    await _auth.verifyPhoneNumber(
      // phoneNumber: phoneController.text,
      phoneNumber: formattedNumber,
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
    setState(() {
      _isSigningIn = true; // Activate blur effect
    });

    try {
      final AuthCredential credential = PhoneAuthProvider.credential(
        verificationId: _verificationId,
        smsCode: otpController.text,
      );

      UserCredential userCredential = await _auth.signInWithCredential(credential);


      // After successful sign-in and obtaining the userCredential:
      final prefs = await SharedPreferences.getInstance();
      String newSessionToken = const Uuid().v4(); // Generate a new session token
      await prefs.setString('sessionToken', newSessionToken);

      await FirebaseFirestore.instance.collection('users').doc(userCredential.user?.uid).set({
        'sessionToken': newSessionToken,
      }, SetOptions(merge: true));




      // Check if the user exists in your Firestore database
      DocumentSnapshot userProfile = await FirebaseFirestore.instance.collection('users').doc(userCredential.user?.uid).get();

      // Navigate based on whether the user has a profile
      if (userProfile.exists) {
        // User exists, so they are a returning user. Navigate them to the home page.
        navigateToHome();
      } else {
        // User doesn't exist, so they are new. Navigate them to the profile creation page.
        navigateToProfileCreation();
      }

    } catch (error) {
      setState(() {
        errorMessage = error.toString();
      });
    } finally {
      setState(() {
        _isSigningIn = false; // Deactivate blur effect
      });
    }
  }


  Widget mobileNumberButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 0.0), // Ensure this matches other buttons
      child: Container(
        child: ElevatedButton(
          onPressed: () {
            setState(() {
              showPhoneNumberInput = true;
              showGoogleSignInButton = false;

              showSignInOptions = false;
            });
          },
          style: sharedButtonStyle.copyWith(
            minimumSize: MaterialStateProperty.all(Size(0, buttonHeight)), // Adjust the width as needed
          ),
          child: Text(isSignUp ? "Sign up with OTP" : "Sign in with OTP"),
        ),
      ),
    );
  }


  Widget submitButton(String text, VoidCallback onPressed, {double buttonHeight = 50.0}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 25.0),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color.fromARGB(255, 63, 102, 105), // Standard height
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          minimumSize: Size(double.infinity, buttonHeight * 0.9),
        ),
        child: Text(
          text,
          style: const TextStyle(color: Colors.white),
        ),
      ),
    );
  }




  Widget entryField(String hintText, TextEditingController controller, {bool isObscure = false}) {
    return TextFormField(
      controller: controller,
      obscureText: isObscure,
      decoration: sharedInputDecoration.copyWith(hintText: hintText),
    );
  }


  Widget customDividerWithText() {
    return const Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: 220, // Adjust this width to control the starting point of the divider
          child: Divider(color: Colors.grey, thickness: 1),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 20.0), // Space around 'Or' text
          child: Text(
            "Or",
            style: TextStyle(color: Colors.white),
          ),
        ),
        SizedBox(
          width: 220, // Adjust this width to control the ending point of the divider
          child: Divider(color: Colors.grey, thickness: 1),
        ),
      ],
    );
  }



  Widget toggleSignUpSignInText() {
    return GestureDetector(
      onTap: () {
        setState(() {
          isSignUp = !isSignUp; // Toggle the boolean state
        });
      },
      child: Text(
        isSignUp ? "Sign In ?" : "Sign Up ?",
        style: const TextStyle(
          color: Colors.white, // Change as per your design
          fontWeight: FontWeight.w500, // Medium weight
          fontSize: 12, // Font size set to 16px
        ),
        textAlign: TextAlign.center,
      ),
    );
  }


  Future<void> signInWithGoogle() async {

    setState(() {
      _isSigningIn = true; // Activate blur effect
    });

    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();

      if (googleUser == null) {
        setState(() {
          _isSigningIn = false; // Deactivate blur effect immediately if sign-in is cancelled
        });
        return; // User canceled the sign-in process
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      UserCredential userCredential = await _auth.signInWithCredential(credential);


      final userDocRef = FirebaseFirestore.instance.collection('users').doc(userCredential.user?.uid);
      final docSnapshot = await userDocRef.get();




      // After successful sign-in and obtaining the userCredential:
      final prefs = await SharedPreferences.getInstance();
      String newSessionToken = const Uuid().v4(); // Generate a new session token

      await prefs.setString('sessionToken', newSessionToken);




      await FirebaseFirestore.instance.collection('users').doc(userCredential.user?.uid).set({
        'sessionToken': newSessionToken,
      }, SetOptions(merge: true));  // Use merge to avoid overwriting other fields



      // Check if the user exists in your Firestore database
      DocumentSnapshot userProfile = await FirebaseFirestore.instance.collection('users').doc(userCredential.user?.uid).get();

      // Navigate based on whether the user has a profile
      if (userProfile.exists) {
        // User exists, so they are a returning user. Navigate them to the home page.
        navigateToHome();
      } else {
        // User doesn't exist, so they are new. Navigate them to the profile creation page.
        navigateToProfileCreation();
      }

    } catch (error) {
      setState(() {
        errorMessage = error.toString();
      });
    }

    finally {
      setState(() {
        _isSigningIn = false; // Deactivate blur effect
      });
    }

  }

  void navigateToHome() {
    Navigator.of(context).pushReplacementNamed('/home');
  }

  void navigateToProfileCreation() {
    Navigator.of(context).pushReplacementNamed('/profile');
  }



  Widget googleSignInButton() {
    return ElevatedButton(
      onPressed: signInWithGoogle,
      style: ElevatedButton.styleFrom(
        foregroundColor: Colors.black, backgroundColor: Colors.white, // Text color (will be overridden by TextStyle below)
        // minimumSize: Size(400, 50), // Width and height
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(50), // Rounded corners
          side: BorderSide(color: Color(0xFF747775), width: 0), // Stroke
        ),
        elevation: 5, // No shadowFa
        padding: EdgeInsets.zero, // No default padding
        minimumSize: Size(double.infinity, buttonHeight),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SvgPicture.asset('assets/google_logo.svg', height: 24, width: 24,color: null),
            const SizedBox(width: 10), // Spacing between the icon and the text
            Text(
              isSignUp ? "Sign up with Google" : "Sign in with Google",
              style: const TextStyle(
                color: Color(0xFF1F1F1F), // Font color
                fontSize: 14, // Font size
                fontWeight: FontWeight.w500, // Roboto Medium
                letterSpacing: 0.25, // Optional: Adjust letter spacing
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildTextField({
    required TextEditingController controller,
    required String hintText,
    required EdgeInsets padding,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        hintText: hintText,
        border: const OutlineInputBorder(),
        contentPadding: padding, // Apply consistent padding
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    // Define a consistent width for buttons and input fields
    double width = MediaQuery.of(context).size.width * 0.4; // 60% of screen width

    return MaterialApp(
      title: 'NearbyChess',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        fontFamily: 'Poppins',
      ),
      home: Scaffold(
        body: Stack(
          children: [
            Positioned.fill(
              child: Image.asset(
                "assets/background_knight.jpg",
                fit: BoxFit.cover,
              ),
            ),
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.7),
              ),
            ),
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Image.asset(
                      'assets/logo1.png',
                      height: 300,
                    ),
                    const SizedBox(height: 60),
                    if (!showPhoneNumberInput && !showOtpInput)
                      SizedBox(
                        width: width,
                        child: mobileNumberButton(),
                      ),
                    if (showPhoneNumberInput)
                      SizedBox(
                        width: width,
                        child: Row(
                          children: [
                            Expanded(
                              child: entryField('Enter phone number', phoneController),
                            ),
                            const SizedBox(width: 1),
                            ElevatedButton(
                              onPressed: () {
                                verifyPhoneNumber();
                                setState(() {
                                  showPhoneNumberInput = false;
                                  showOtpInput = true;

                                  showSignInOptions = false;
                                });
                              },
                              style: ElevatedButton.styleFrom(
                                primary: Colors.transparent, onPrimary: Colors.transparent,
                                shape: const CircleBorder(
                                  side: BorderSide(color: Colors.black),
                                ),
                                padding: EdgeInsets.all(12),
                                elevation: 2,
                              ),
                              child: SvgPicture.asset('assets/paper-plane-solid.svg', height: 20, width: 20),
                            ),
                          ],
                        ),
                      ),
                    if (showOtpInput)
                      Padding(
                          padding: const EdgeInsets.only(bottom: 10.0), // Add top padding
                      child:SizedBox(
                        width: width,
                        child: entryField('Enter OTP', otpController),
                      ),
                      ),
                    if (_verificationId.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 15.0), // Optional: Added to ensure consistent spacing
                        child: SizedBox(
                          width: MediaQuery.of(context).size.width * 0.427, // Increased width to 70%
                          child: submitButton('Verify OTP', signInWithOTP, buttonHeight: 60.0),
                        ),
                      ),
                    const SizedBox(height: 10),

                    Visibility(
                      visible: showSignInOptions,
                      child: customDividerWithText(),
                    ),

                    const SizedBox(height: 10),



                    Visibility(
                      visible: showGoogleSignInButton, // This controls the visibility
                      child: SizedBox(
                        width: width,
                        child: googleSignInButton(),
                      ),
                    ),

                    const SizedBox(height: 10),

                    // toggleSignUpSignInText(),
                    Visibility(
                      visible: showSignInOptions,
                      child: toggleSignUpSignInText(),
                    ),
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
            if (_isSigningIn)
              Positioned.fill(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    color: Colors.black.withOpacity(0.5),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }


}










