import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:encore/main.dart';
import 'package:encore/screens/announcement_detail_screen.dart';
import 'package:encore/screens/auth/create_account_screen.dart';
import 'package:encore/screens/auth/login_screen.dart';
import 'package:encore/screens/finance_screen.dart';
import 'package:encore/screens/home_shell.dart';
import 'package:encore/screens/trending_more_screen.dart';
import 'package:encore/screens/updates_screen.dart';
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

  testWidgets('Logging in leads to the home shell', (
    WidgetTester tester,
  ) async {
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
    for (final label in ['Updates', 'Messages', 'Profile', 'Finance', 'More']) {
      expect(find.text(label), findsWidgets);
    }

    // Updates is selected first: the workspace bar shows its heading/level.
    expect(find.text('Update'), findsOneWidget);
    expect(find.text('Csc 200 level'), findsOneWidget);

    // Tap the Messages tab in the bar (not the body placeholder).
    await tester.tap(find.byKey(const ValueKey('nav-Messages')));
    await tester.pumpAndSettle();

    expect(find.text('Messages'), findsNWidgets(2));
    expect(find.text('Csc 200 level'), findsNothing);
  });

  testWidgets('Updates tab shows the workspace bar, pills and announcements', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: UpdatesScreen()));

    // Workspace bar.
    expect(find.text('Update'), findsOneWidget);
    expect(find.text('Csc 200 level'), findsOneWidget);

    // Announcement section header and filter pills.
    expect(find.text('#'), findsAtLeastNWidgets(1));
    expect(find.text('Announcement'), findsOneWidget);
    for (final label in ['All', 'Unread', 'Urgent', 'Older']) {
      expect(find.text(label), findsOneWidget);
    }

    // Three announcement tiles plus the workspace logo (and trending art).
    expect(find.byKey(const ValueKey('announcement-0')), findsOneWidget);
    expect(find.byKey(const ValueKey('announcement-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('announcement-2')), findsOneWidget);
    expect(find.byType(Image), findsAtLeastNWidgets(4));

    // Priority subtitles under each sender.
    expect(find.text('Highly prior'), findsOneWidget);
    expect(find.text('General announcement'), findsOneWidget);
    expect(find.text('Less prior'), findsOneWidget);

    // Switching pills swaps the feed for the empty state.
    await tester.tap(find.byKey(const ValueKey('filter-Unread')));
    await tester.pumpAndSettle();
    expect(find.text('Nothing here yet'), findsOneWidget);
    expect(find.byKey(const ValueKey('announcement-0')), findsNothing);
  });

  testWidgets('Updates shows Trending and opens Show more', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: UpdatesScreen()));

    expect(find.text('Trending'), findsOneWidget);
    expect(find.byKey(const ValueKey('trending-0')), findsOneWidget);
    expect(find.byKey(const ValueKey('trending-show-more')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('trending-show-more')));
    await tester.pumpAndSettle();

    expect(find.byType(TrendingMoreScreen), findsOneWidget);
  });

  testWidgets('Updates shows the Upcoming Activities grid', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: UpdatesScreen()));

    await tester.drag(
      find.byKey(const ValueKey('updates-scroll')),
      const Offset(0, -500),
    );
    await tester.pumpAndSettle();

    expect(find.text('Upcoming Activities'), findsOneWidget);
    for (var i = 0; i < 6; i++) {
      expect(find.byKey(ValueKey('activity-$i')), findsOneWidget);
    }
  });

  testWidgets('Tapping an announcement opens its detail page', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: UpdatesScreen()));

    await tester.tap(find.byKey(const ValueKey('announcement-0')));
    await tester.pumpAndSettle();

    expect(find.byType(AnnouncementDetailScreen), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(AnnouncementDetailScreen),
        matching: find.text('Dr. Mensah'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(AnnouncementDetailScreen),
        matching: find.text('Highly prior'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('Home shell supports swiping between sections', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: HomeShell()));
    final pages = find.byType(PageView);

    // Swipe right to move from Updates to Messages.
    await tester.fling(pages, const Offset(-300, 0), 1000);
    await tester.pumpAndSettle();

    expect(find.text('Messages'), findsNWidgets(2));
    expect(find.text('Csc 200 level'), findsNothing);

    // Swipe back to Updates.
    await tester.fling(pages, const Offset(300, 0), 1000);
    await tester.pumpAndSettle();

    expect(find.text('Csc 200 level'), findsOneWidget);
    expect(find.text('Messages'), findsOneWidget);
  });

  testWidgets('Finance expenditure filter opens and selects', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: FinanceScreen())),
    );
    await tester.pumpAndSettle();

    // The pill starts on the default option.
    expect(find.text('All Expenditures'), findsOneWidget);

    // Tapping it opens the dropdown with every option.
    await tester.tap(find.text('All Expenditures'));
    await tester.pumpAndSettle();

    for (final option in [
      'All Expenditures',
      'Manuals',
      'Registration Dues',
      'Other Expenses',
    ]) {
      expect(find.widgetWithText(MenuItemButton, option), findsOneWidget);
    }

    // Selecting an option closes the menu and updates the pill label.
    await tester.tap(find.widgetWithText(MenuItemButton, 'Registration Dues'));
    await tester.pumpAndSettle();

    expect(find.text('Registration Dues'), findsOneWidget);
    expect(find.widgetWithText(MenuItemButton, 'Manuals'), findsNothing);
  });
}
