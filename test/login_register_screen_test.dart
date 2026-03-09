import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_desk/screens/login_register_screen.dart';

void main() {
  group('LoginRegisterScreen', () {
    Widget buildTestWidget() {
      return MaterialApp(
        routes: {
          '/forgot-password': (context) => const Scaffold(body: Text('Forgot Password')),
          '/customer-home': (context) => const Scaffold(body: Text('Customer Home')),
          '/supplier-dashboard': (context) => const Scaffold(body: Text('Supplier Dashboard')),
          '/admin-dashboard': (context) => const Scaffold(body: Text('Admin Dashboard')),
        },
        home: const LoginRegisterScreen(),
      );
    }

    testWidgets('shows Login mode by default with Welcome Back and Login button',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Welcome Back!'), findsOneWidget);
      expect(find.text('Login'), findsOneWidget);
      expect(find.text('Register'), findsOneWidget);
      expect(find.text('Forgot password?'), findsOneWidget);
    });

    testWidgets('shows Email and Password fields in Login mode', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.byType(TextFormField), findsNWidgets(2));
      expect(find.text('Email'), findsWidgets);
      expect(find.text('Password'), findsWidgets);
    });

    testWidgets('does not show Name field or Role dropdown in Login mode',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Full Name'), findsNothing);
      expect(find.text('Select Role'), findsNothing);
    });

    testWidgets('tapping Register link switches to Create Account mode',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Register'));
      await tester.pumpAndSettle();

      expect(find.text('Create Account'), findsOneWidget);
      expect(find.text('Register'), findsWidgets);
      expect(find.text('Full Name'), findsOneWidget);
      expect(find.text('Select Role'), findsOneWidget);
      expect(find.byType(TextFormField), findsNWidgets(3));
    });

    testWidgets('tapping Login link in Register mode switches back to Login',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Register'));
      await tester.pumpAndSettle();
      expect(find.text('Create Account'), findsOneWidget);

      await tester.tap(find.text('Login'));
      await tester.pumpAndSettle();

      expect(find.text('Welcome Back!'), findsOneWidget);
      expect(find.byType(TextFormField), findsNWidgets(2));
    });

    testWidgets('form validation: empty email shows error', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Login'));
      await tester.pumpAndSettle();

      expect(find.text('Please enter your email'), findsOneWidget);
    });

    testWidgets('form validation: invalid email format shows error',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).first, 'notanemail');
      await tester.enterText(find.byType(TextFormField).last, 'password123');
      await tester.tap(find.text('Login'));
      await tester.pumpAndSettle();

      expect(find.text('Please enter a valid email'), findsOneWidget);
    });

    testWidgets('form validation: empty password shows error', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).first, 'test@example.com');
      await tester.enterText(find.byType(TextFormField).last, '');
      await tester.tap(find.text('Login'));
      await tester.pumpAndSettle();

      expect(find.text('Please enter your password'), findsOneWidget);
    });

    testWidgets('email and password fields accept input', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).first, 'test@example.com');
      await tester.enterText(find.byType(TextFormField).last, 'password123');
      await tester.pump();

      expect(find.text('test@example.com'), findsOneWidget);
      expect(find.text('password123'), findsOneWidget);
    });

    testWidgets('Register mode: empty name shows error', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Register'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).at(0), '');
      await tester.enterText(find.byType(TextFormField).at(1), 'test@example.com');
      await tester.enterText(find.byType(TextFormField).at(2), 'password123');
      await tester.tap(find.text('Register'));
      await tester.pumpAndSettle();

      expect(find.text('Please enter your name'), findsOneWidget);
    });

    testWidgets('Register mode: password less than 6 characters shows error',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Register'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).at(0), 'Test User');
      await tester.enterText(find.byType(TextFormField).at(1), 'test@example.com');
      await tester.enterText(find.byType(TextFormField).at(2), '12345');
      await tester.tap(find.text('Register'));
      await tester.pumpAndSettle();

      expect(find.text('Password must be at least 6 characters'), findsOneWidget);
    });

    testWidgets('Register mode: role dropdown has Customer, Supplier, Admin',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Register'));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();

      expect(find.text('Supplier'), findsOneWidget);
      expect(find.text('Admin'), findsOneWidget);
    });

    testWidgets('Forgot password button is present in Login mode', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Forgot password?'), findsOneWidget);
    });

    testWidgets('Forgot password is not shown in Register mode', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Register'));
      await tester.pumpAndSettle();

      expect(find.text('Forgot password?'), findsNothing);
    });

    testWidgets('password field has visibility toggle button', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.byType(IconButton), findsOneWidget);
    });

    testWidgets('screen has a Form and submit button', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.byType(Form), findsOneWidget);
      expect(find.byType(ElevatedButton), findsOneWidget);
    });
  });

  group('Sign up page', () {
    Widget buildTestWidget() {
      return MaterialApp(
        routes: {
          '/forgot-password': (context) => const Scaffold(body: Text('Forgot Password')),
          '/customer-home': (context) => const Scaffold(body: Text('Customer Home')),
          '/supplier-dashboard': (context) => const Scaffold(body: Text('Supplier Dashboard')),
          '/admin-dashboard': (context) => const Scaffold(body: Text('Admin Dashboard')),
        },
        home: const LoginRegisterScreen(),
      );
    }

    Future<void> openSignUpPage(WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Register'));
      await tester.pumpAndSettle();
    }

    testWidgets('shows Create Account title and Register button', (WidgetTester tester) async {
      await openSignUpPage(tester);
      expect(find.text('Create Account'), findsOneWidget);
      expect(find.text('Register'), findsWidgets);
      expect(find.widgetWithText(ElevatedButton, 'Register'), findsOneWidget);
    });

    testWidgets('shows all sign up fields: Full Name, Email, Password, Select Role',
        (WidgetTester tester) async {
      await openSignUpPage(tester);
      expect(find.text('Full Name'), findsOneWidget);
      expect(find.text('Email'), findsWidgets);
      expect(find.text('Password'), findsWidgets);
      expect(find.text('Select Role'), findsOneWidget);
      expect(find.byType(TextFormField), findsNWidgets(3));
      expect(find.byType(DropdownButtonFormField<String>), findsOneWidget);
    });

    testWidgets('shows Already have an account? Login link', (WidgetTester tester) async {
      await openSignUpPage(tester);
      expect(find.text('Already have an account? '), findsOneWidget);
      expect(find.text('Login'), findsWidgets);
    });

    testWidgets('does not show Forgot password on sign up page', (WidgetTester tester) async {
      await openSignUpPage(tester);
      expect(find.text('Forgot password?'), findsNothing);
    });

    testWidgets('Name field accepts input', (WidgetTester tester) async {
      await openSignUpPage(tester);
      await tester.enterText(find.byType(TextFormField).at(0), 'Jane Doe');
      await tester.pump();
      expect(find.text('Jane Doe'), findsOneWidget);
    });

    testWidgets('Email field is second and accepts valid email', (WidgetTester tester) async {
      await openSignUpPage(tester);
      await tester.enterText(find.byType(TextFormField).at(1), 'jane@example.com');
      await tester.pump();
      expect(find.text('jane@example.com'), findsOneWidget);
    });

    testWidgets('Password field is third and accepts input', (WidgetTester tester) async {
      await openSignUpPage(tester);
      await tester.enterText(find.byType(TextFormField).at(2), 'securePass123');
      await tester.pump();
      expect(find.text('securePass123'), findsOneWidget);
    });

    testWidgets('sign up validation: empty name shows error', (WidgetTester tester) async {
      await openSignUpPage(tester);
      await tester.enterText(find.byType(TextFormField).at(0), '');
      await tester.enterText(find.byType(TextFormField).at(1), 'user@test.com');
      await tester.enterText(find.byType(TextFormField).at(2), 'password1');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Register'));
      await tester.pumpAndSettle();
      expect(find.text('Please enter your name'), findsOneWidget);
    });

    testWidgets('sign up validation: empty email shows error', (WidgetTester tester) async {
      await openSignUpPage(tester);
      await tester.enterText(find.byType(TextFormField).at(0), 'Test User');
      await tester.enterText(find.byType(TextFormField).at(1), '');
      await tester.enterText(find.byType(TextFormField).at(2), 'password1');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Register'));
      await tester.pumpAndSettle();
      expect(find.text('Please enter your email'), findsOneWidget);
    });

    testWidgets('sign up validation: invalid email format shows error', (WidgetTester tester) async {
      await openSignUpPage(tester);
      await tester.enterText(find.byType(TextFormField).at(0), 'Test User');
      await tester.enterText(find.byType(TextFormField).at(1), 'invalid-email');
      await tester.enterText(find.byType(TextFormField).at(2), 'password1');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Register'));
      await tester.pumpAndSettle();
      expect(find.text('Please enter a valid email'), findsOneWidget);
    });

    testWidgets('sign up validation: empty password shows error', (WidgetTester tester) async {
      await openSignUpPage(tester);
      await tester.enterText(find.byType(TextFormField).at(0), 'Test User');
      await tester.enterText(find.byType(TextFormField).at(1), 'user@test.com');
      await tester.enterText(find.byType(TextFormField).at(2), '');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Register'));
      await tester.pumpAndSettle();
      expect(find.text('Please enter your password'), findsOneWidget);
    });

    testWidgets('sign up validation: password under 6 characters shows error',
        (WidgetTester tester) async {
      await openSignUpPage(tester);
      await tester.enterText(find.byType(TextFormField).at(0), 'Test User');
      await tester.enterText(find.byType(TextFormField).at(1), 'user@test.com');
      await tester.enterText(find.byType(TextFormField).at(2), '12345');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Register'));
      await tester.pumpAndSettle();
      expect(find.text('Password must be at least 6 characters'), findsOneWidget);
    });

    testWidgets('sign up validation: valid 6-char password passes', (WidgetTester tester) async {
      await openSignUpPage(tester);
      await tester.enterText(find.byType(TextFormField).at(0), 'Test User');
      await tester.enterText(find.byType(TextFormField).at(1), 'user@test.com');
      await tester.enterText(find.byType(TextFormField).at(2), '123456');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Register'));
      await tester.pump();
      expect(find.text('Password must be at least 6 characters'), findsNothing);
    });

    testWidgets('role dropdown defaults to Customer', (WidgetTester tester) async {
      await openSignUpPage(tester);
      expect(find.text('Customer'), findsWidgets);
    });

    testWidgets('role dropdown opens and shows Customer, Supplier, Admin',
        (WidgetTester tester) async {
      await openSignUpPage(tester);
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      expect(find.text('Customer'), findsWidgets);
      expect(find.text('Supplier'), findsOneWidget);
      expect(find.text('Admin'), findsOneWidget);
    });

    testWidgets('tapping Login link from sign up returns to login page',
        (WidgetTester tester) async {
      await openSignUpPage(tester);
      expect(find.text('Create Account'), findsOneWidget);
      // Find the TextButton that contains "Login" (the "Already have an account? Login" link)
      final loginLink = find.ancestor(
        of: find.text('Login'),
        matching: find.byType(TextButton),
      );
      expect(loginLink, findsOneWidget);
      await tester.ensureVisible(loginLink.first);
      await tester.tap(loginLink.first);
      await tester.pumpAndSettle();
      expect(find.text('Welcome Back!'), findsOneWidget);
      expect(find.text('Create Account'), findsNothing);
    });

    testWidgets('sign up form has one submit button', (WidgetTester tester) async {
      await openSignUpPage(tester);
      expect(find.byType(ElevatedButton), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Register'), findsOneWidget);
    });
  });
}
