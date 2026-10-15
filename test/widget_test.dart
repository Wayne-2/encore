import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:encore/main.dart';
import 'package:encore/screens/auth/create_account_screen.dart';
import 'package:encore/screens/auth/login_screen.dart';
import 'package:encore/screens/home_shell.dart';
import 'package:encore/screens/welcome_screen.dart';

void main() {
  testWidgets('Splash leads to the welcome screen', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp());

    // Splash logo is shown immediately.
    expect(find.byType(Image), findsOneWidget);

    // Step through the splash + fade transition until the welcome screen
    // appears. We can't use pumpAndSettle because the FadingCube loops.
    var tries = 0;
    while (find.byType(WelcomeScreen).evaluate().isEmpty && tries < 40) {
      await tester.pump(const Duration(milliseconds: 200));
      tries++;
    }

    expect(find.byType(WelcomeScreen), findsOneWidget);
    // The welcome screen renders the background with a frosted-glass overlay.
    expect(find.byType(BackdropFilter), findsWidgets);

    // Dispose the tree so the welcome carousel's auto-play timer is cancelled.
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Create account shows personal then school details', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: CreateAccountScreen()));

    // Step 1 — account details (Full Name first).
    expect(find.text('Full Name'), findsOneWidget);
    expect(find.text('Username'), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Confirm Password'), findsNothing);
    expect(find.text('Continue'), findsOneWidget);

    // Fill step 1 so validation passes.
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'John Doe');
    await tester.enterText(fields.at(1), 'johndoe');
    await tester.enterText(fields.at(2), 'john@university.edu');
    await tester.enterText(fields.at(3), 'secret1');

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    // Step 2 — academics.
    expect(find.text('Registration Number'), findsOneWidget);
    expect(find.text('Department'), findsOneWidget);
    expect(find.text('Faculty'), findsOneWidget);
    expect(find.text('Role'), findsOneWidget);
    expect(find.text('Create Account'), findsOneWidget);
  });

  testWidgets('Choosing Admin reveals the admin ID field', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: CreateAccountScreen()));

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'John Doe');
    await tester.enterText(fields.at(1), 'johndoe');
    await tester.enterText(fields.at(2), 'john@university.edu');
    await tester.enterText(fields.at(3), 'secret1');
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    // No admin ID field until the Admin role is picked.
    expect(find.text('Admin ID'), findsNothing);

    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Admin').last);
    await tester.pumpAndSettle();

    expect(find.text('Admin ID'), findsOneWidget);
  });

  testWidgets('Choosing Student reveals the level options', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: CreateAccountScreen()));

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'John Doe');
    await tester.enterText(fields.at(1), 'johndoe');
    await tester.enterText(fields.at(2), 'john@university.edu');
    await tester.enterText(fields.at(3), 'secret1');
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(find.text('Level'), findsNothing);

    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Student').last);
    await tester.pumpAndSettle();

    expect(find.text('Level'), findsOneWidget);

    // The level dropdown offers the full set.
    await tester.tap(find.byType(DropdownButtonFormField<String>).last);
    await tester.pumpAndSettle();
    for (final level in [
      '100 Level',
      '200 Level',
      '300 Level',
      '400 Level',
      '500 Level',
      'Extras',
      'Alumni',
    ]) {
      expect(find.text(level), findsOneWidget);
    }
  });

  testWidgets('Create account ends on the getting-ready loading screen', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: CreateAccountScreen()));

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'John Doe');
    await tester.enterText(fields.at(1), 'johndoe');
    await tester.enterText(fields.at(2), 'john@university.edu');
    await tester.enterText(fields.at(3), 'secret1');
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    // School details.
    final school = find.byType(TextFormField);
    await tester.enterText(school.at(0), '21/12345');
    await tester.enterText(school.at(1), 'Computer Science');
    await tester.enterText(school.at(2), 'Faculty of Science');

    await tester.tap(find.byType(DropdownButtonFormField<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Student').last);
    await tester.pumpAndSettle();

    await tester.tap(find.byType(DropdownButtonFormField<String>).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('400 Level').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Create Account'));
    await tester.pumpAndSettle();

    // Step 3 — email verification.
    expect(find.text('Verify your email'), findsOneWidget);
    expect(find.text('Resend email'), findsOneWidget);
    // The email the link was sent to is shown.
    expect(find.textContaining('john@university.edu'), findsOneWidget);

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    // Step 4 — profile picture.
    expect(find.text('Add a profile picture'), findsOneWidget);

    // Finish leads to the final "getting you ready" loading screen.
    await tester.tap(find.text('Finish'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('Getting you ready'), findsOneWidget);

    // ...which then reveals the home shell with the bottom navigation.
    var tries = 0;
    while (find.byType(HomeShell).evaluate().isEmpty && tries < 40) {
      await tester.pump(const Duration(milliseconds: 200));
      tries++;
    }
    await tester.pumpAndSettle();
    expect(find.byType(HomeShell), findsOneWidget);
  });

  testWidgets('Create account top bar shows the step heading and goes back', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: CreateAccountScreen()));

    // The step heading lives in the top bar, replacing the Encore wordmark.
    expect(find.text('Create your account'), findsOneWidget);
    expect(find.text('Encore'), findsNothing);

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'John Doe');
    await tester.enterText(fields.at(1), 'johndoe');
    await tester.enterText(fields.at(2), 'john@university.edu');
    await tester.enterText(fields.at(3), 'secret1');
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    // Step 2 heading replaces the app name/logo.
    expect(find.text('School details'), findsOneWidget);

    // The return arrow steps back to the personal details.
    await tester.tap(find.byIcon(Icons.arrow_back_ios_new));
    await tester.pumpAndSettle();
    expect(find.text('Create your account'), findsOneWidget);
  });

  testWidgets('Login screen shows its fields and links to sign up', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));

    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Full Name'), findsOneWidget);
    expect(find.text('Registration Number'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Forgot password?'), findsOneWidget);
    expect(find.text('Log In'), findsOneWidget);

    await tester.tap(find.text('Create an account'));
    await tester.pumpAndSettle();
    expect(find.byType(CreateAccountScreen), findsOneWidget);
  });

  testWidgets('Logging in leads to the home shell', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'John Doe');
    await tester.enterText(fields.at(1), '21/12345');
    await tester.enterText(fields.at(2), 'secret1');

    await tester.tap(find.text('Log In'));
    await tester.pumpAndSettle();

    expect(find.byType(HomeShell), findsOneWidget);
  });

  testWidgets('Home shell shows the bottom navigation and switches tabs', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: HomeShell()));

    // All five sections are labelled in the bar.
    for (final label in [
      'Updates',
      'Messages',
      'Profile',
      'Finance',
      'More',
    ]) {
      expect(find.text(label), findsWidgets);
    }

    // Updates is selected first: its label shows in the bar and the body.
    expect(find.text('Updates'), findsNWidgets(2));

    // Tap the Messages tab in the bar (not the body placeholder).
    await tester.tap(find.byKey(const ValueKey('nav-Messages')));
    await tester.pumpAndSettle();

    expect(find.text('Messages'), findsNWidgets(2));
    expect(find.text('Updates'), findsOneWidget);
  });
}
