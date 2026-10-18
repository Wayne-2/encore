import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:encore/main.dart';
import 'package:encore/models/announcement.dart';
import 'package:encore/screens/announcement_detail_screen.dart';
import 'package:encore/screens/announcements_screen.dart';
import 'package:encore/screens/auth/create_account_screen.dart';
import 'package:encore/screens/auth/login_screen.dart';
import 'package:encore/screens/finance_screen.dart';
import 'package:encore/screens/home_shell.dart';
import 'package:encore/screens/messages_screen.dart';
import 'package:encore/screens/more_screen.dart';
import 'package:encore/screens/profile_screen.dart';
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
    await tester.enterText(school.at(0), '20211234567');
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
    expect(find.text('Email'), findsOneWidget);
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
    await tester.enterText(fields.at(0), 'john@university.edu');
    await tester.enterText(fields.at(1), 'secret1');

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

  testWidgets('Updates tab shows the workspace bar, header and announcements', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: UpdatesScreen()));

    // Workspace bar.
    expect(find.text('Update'), findsOneWidget);
    expect(find.text('Csc 200 level'), findsOneWidget);

    // Announcement section header.
    expect(find.text('#'), findsAtLeastNWidgets(1));
    expect(find.text('Announcement'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('announcement-show-more')),
      findsOneWidget,
    );

    // Three announcement tiles plus the workspace logo (and trending art).
    expect(find.byKey(const ValueKey('announcement-0')), findsOneWidget);
    expect(find.byKey(const ValueKey('announcement-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('announcement-2')), findsOneWidget);
    expect(find.byType(Image), findsAtLeastNWidgets(4));

    // Priority subtitles under each sender.
    expect(find.text('Highly prior'), findsOneWidget);
    expect(find.text('General announcement'), findsOneWidget);
    expect(find.text('Less prior'), findsOneWidget);
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

  testWidgets('Announcement Show more opens the full announcements list', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: UpdatesScreen()));

    await tester.tap(find.byKey(const ValueKey('announcement-show-more')));
    await tester.pumpAndSettle();

    expect(find.byType(AnnouncementsScreen), findsOneWidget);
    expect(find.byKey(const ValueKey('all-announcement-0')), findsOneWidget);
    expect(find.byKey(const ValueKey('all-announcement-1')), findsOneWidget);

    // Tapping a tile in the full list opens its detail page.
    await tester.tap(find.byKey(const ValueKey('all-announcement-0')));
    await tester.pumpAndSettle();
    expect(find.byType(AnnouncementDetailScreen), findsOneWidget);
  });

  testWidgets('Announcement detail supports posting a comment', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: AnnouncementDetailScreen(
          announcement: Announcement(
            author: 'Dr. Mensah',
            time: '9:41 AM',
            tag: 'Highly prior',
            tagColor: Color(0xFFE8A33D),
            body: 'The lab report is due this Friday before 5:00 PM.',
          ),
        ),
      ),
    );

    expect(find.text('Comments'), findsOneWidget);
    expect(find.text('Ama Boateng'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Noted, thank you!');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('comment-send-button')));
    await tester.pumpAndSettle();

    expect(find.text('Noted, thank you!'), findsOneWidget);
    expect(find.text('Odeh Solomon'), findsOneWidget);
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

  testWidgets('Finance due tile options follow the paid state', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: FinanceScreen())),
    );
    await tester.pumpAndSettle();

    // Paid due (GST 212) offers receipt actions.
    final paidOptions = find.byKey(
      const ValueKey('due-options-GST 212 - Philosophy and Logic'),
    );
    await tester.ensureVisible(paidOptions);
    await tester.tap(paidOptions);
    await tester.pumpAndSettle();
    expect(find.text('Save Details'), findsOneWidget);
    expect(find.text('View Receipt'), findsOneWidget);
    expect(find.text('Draft Invoice'), findsNothing);

    // Dismiss, then open an unpaid due (MATH 202).
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();

    final unpaidOptions = find.byKey(
      const ValueKey('due-options-MATH 202 - Differential Calculus'),
    );
    await tester.ensureVisible(unpaidOptions);
    await tester.tap(unpaidOptions);
    await tester.pumpAndSettle();
    expect(find.text('Draft Invoice'), findsOneWidget);
    expect(find.text('View Details'), findsOneWidget);
    expect(find.text('View Receipt'), findsNothing);
  });

  testWidgets('Updates compose button reveals quick actions', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: UpdatesScreen()));

    expect(find.byIcon(Icons.add), findsOneWidget);
    expect(find.text('New Announcement'), findsNothing);
    expect(find.text('Post Trends'), findsNothing);
    expect(find.text('Add Activity'), findsNothing);

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();

    expect(find.text('New Announcement'), findsOneWidget);
    expect(find.text('Post Trends'), findsOneWidget);
    expect(find.text('Add Activity'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();

    expect(find.text('New Announcement'), findsNothing);
    expect(find.text('Post Trends'), findsNothing);
    expect(find.text('Add Activity'), findsNothing);
  });

  testWidgets('Messages compose button reveals quick actions', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: MessagesScreen())),
    );

    expect(find.byIcon(Icons.add), findsOneWidget);
    expect(find.text('Add Story'), findsNothing);
    expect(find.text('New DM'), findsNothing);
    expect(find.text('New Group'), findsNothing);

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();

    expect(find.text('Add Story'), findsOneWidget);
    expect(find.text('New DM'), findsOneWidget);
    expect(find.text('New Group'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();

    expect(find.text('Add Story'), findsNothing);
    expect(find.text('New DM'), findsNothing);
    expect(find.text('New Group'), findsNothing);
  });

  testWidgets('Profile shows the hero, handle and details banner', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: ProfileScreen())),
    );

    expect(find.byType(Image), findsOneWidget);
    expect(find.text('Odeh\nSolomon'), findsOneWidget);
    expect(find.text('_wayne'), findsOneWidget);
    expect(find.text('sodeh138@gmail.com'), findsOneWidget);
    expect(find.textContaining('user-centered'), findsOneWidget);
    expect(find.text('Edit Profile'), findsOneWidget);
    expect(find.text('See profile'), findsOneWidget);
    expect(find.text('Student'), findsOneWidget);
    expect(find.text('20241426282'), findsOneWidget);
    expect(find.text('Computer Science'), findsOneWidget);
    expect(find.text('300 Level'), findsOneWidget);
    expect(find.text('SICT'), findsOneWidget);
    expect(find.text('Privacy Mode'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('profile-privacy-toggle')));
    await tester.pump();
    expect(find.text('Profile is private'), findsOneWidget);
  });

  testWidgets('More tab shows its workspace bar', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: MoreScreen())),
    );

    expect(find.text('More'), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
    expect(find.text('Profile'), findsNothing);
    expect(find.text('Library'), findsOneWidget);
    expect(find.text('CGPA Tracker'), findsOneWidget);
    expect(find.text('Student Agents'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
  });
}
