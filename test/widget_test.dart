import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image/image.dart' as img;

import 'package:encore/main.dart';
import 'package:encore/models/announcement.dart';
import 'package:encore/models/trend.dart';
import 'package:encore/screens/announcement_detail_screen.dart';
import 'package:encore/screens/announcements_screen.dart';
import 'package:encore/screens/auth/create_account_screen.dart';
import 'package:encore/screens/auth/login_screen.dart';
import 'package:encore/screens/finance_screen.dart';
import 'package:encore/screens/home_shell.dart';
import 'package:encore/screens/messages_screen.dart';
import 'package:encore/screens/more_screen.dart';
import 'package:encore/screens/profile_screen.dart';
import 'package:encore/screens/trending_detail_screen.dart';
import 'package:encore/screens/trending_more_screen.dart';
import 'package:encore/screens/updates_screen.dart';
import 'package:encore/screens/view_history_screen.dart';
import 'package:encore/screens/welcome_screen.dart';
import 'package:encore/services/activity_store.dart';
import 'package:encore/services/announcement_store.dart';
import 'package:encore/services/comment_store.dart';
import 'package:encore/services/reaction_store.dart';
import 'package:encore/services/trend_store.dart';
import 'package:encore/theme/spotify_colors.dart';
import 'package:encore/widgets/compose_announcement_sheet.dart';
import 'package:encore/widgets/edit_profile_sheet.dart';
import 'package:encore/widgets/trend_cover.dart';
import 'package:encore/widgets/user_avatar.dart';

/// Fills the in-memory feed for tests that need announcements to exist.
void seedAnnouncements() {
  final store = AnnouncementStore.instance;
  store.clear();
  store.post(
    author: 'Prof. Adeyemi',
    authorId: 'seed-adeyemi',
    tag: 'Less prior',
    tagColor: SpotifyColors.tagMuted,
    body:
        'Continuous assessment scores are out. Check the department notice '
        'board for your marks and reach out if anything looks off.',
  );
  store.post(
    author: 'Course Rep',
    authorId: 'seed-rep',
    tag: 'General announcement',
    tagColor: SpotifyColors.tagInfo,
    body:
        "Today's lecture has been moved to the main auditorium. We start at "
        '10:00 AM instead.',
  );
  store.post(
    author: 'Dr. Mensah',
    authorId: 'seed-mensah',
    tag: 'Highly prior',
    tagColor: SpotifyColors.tagUrgent,
    body:
        'Good morning. The Csc 200 lab report is due this Friday — please '
        'submit before 5:00 PM.',
  );
}

/// Fills the in-memory activities grid for tests that need cards to exist.
void seedActivities() {
  final store = ActivityStore.instance;
  store.clear();
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  const titles = [
    'Matriculation',
    'Sports Week',
    'Career Fair',
    'Hostel Ballot',
    'Library Tour',
    'Exam Timetable',
  ];

  for (var i = 0; i < titles.length; i++) {
    store.add(
      title: titles[i],
      date: today.add(Duration(days: i)),
      authorId: 'seed-author',
    );
  }
}

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
    expect(find.text('SICT'), findsOneWidget);
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

    await tester.tap(find.byKey(const ValueKey('role-dropdown')));
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

    await tester.tap(find.byKey(const ValueKey('role-dropdown')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Student').last);
    await tester.pumpAndSettle();

    expect(find.text('Level'), findsOneWidget);

    // The level dropdown offers the full set.
    await tester.tap(find.byKey(const ValueKey('level-dropdown')));
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

    // The faculty is fixed and not editable.
    expect(find.text('SICT'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('department-dropdown')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('CSC').last);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('role-dropdown')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Student').last);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('level-dropdown')));
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
    await tester.tap(find.byIcon(LucideIcons.chevronLeft));
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
    seedAnnouncements();
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

    // Three announcement tiles, each falling back to the poster's initials.
    expect(find.byKey(const ValueKey('announcement-0')), findsOneWidget);
    expect(find.byKey(const ValueKey('announcement-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('announcement-2')), findsOneWidget);
    expect(find.text('PA'), findsOneWidget);
    expect(find.text('CR'), findsOneWidget);
    expect(find.text('DM'), findsOneWidget);

    // Priority subtitles under each sender.
    expect(find.text('Highly prior'), findsOneWidget);
    expect(find.text('General announcement'), findsOneWidget);
    expect(find.text('Less prior'), findsOneWidget);
  });

  testWidgets('Updates shows an empty announcement state', (
    WidgetTester tester,
  ) async {
    AnnouncementStore.instance.clear();
    await tester.pumpWidget(const MaterialApp(home: UpdatesScreen()));

    expect(find.text('No announcement posted yet'), findsOneWidget);
    expect(find.byKey(const ValueKey('announcement-empty')), findsOneWidget);
    expect(find.byIcon(LucideIcons.megaphone), findsOneWidget);
    expect(find.byKey(const ValueKey('announcement-0')), findsNothing);
  });

  testWidgets('Updates keeps pull-to-refresh without an app-bar button', (
    WidgetTester tester,
  ) async {
    AnnouncementStore.instance.clear();
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: UpdatesScreen())),
    );

    expect(find.byKey(const ValueKey('updates-refresh')), findsNothing);
    expect(
      find.byKey(const ValueKey('updates-refresh-indicator')),
      findsOneWidget,
    );
    expect(find.text('No announcement posted yet'), findsOneWidget);
  });

  testWidgets('Announcement section keeps a three-row height when empty', (
    WidgetTester tester,
  ) async {
    AnnouncementStore.instance.clear();
    await tester.pumpWidget(const MaterialApp(home: UpdatesScreen()));

    final section = find.byKey(const ValueKey('announcement-section'));
    final emptyHeight = tester.getSize(section).height;

    seedAnnouncements();
    await tester.pumpAndSettle();

    // Three announcements fit exactly in the space reserved for an empty feed.
    expect(tester.getSize(section).height, emptyHeight);
    expect(emptyHeight, greaterThan(250));
  });

  testWidgets('Updates shows Trending and opens Show more', (
    WidgetTester tester,
  ) async {
    TrendStore.instance.clear();
    await tester.pumpWidget(const MaterialApp(home: UpdatesScreen()));

    expect(find.text('Trending'), findsOneWidget);
    expect(find.text('No Trending news available'), findsOneWidget);
    expect(find.byKey(const ValueKey('trending-empty')), findsOneWidget);
    expect(find.byIcon(LucideIcons.trendingUp), findsOneWidget);
    expect(find.byKey(const ValueKey('trending-show-more')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('trending-show-more')));
    await tester.pumpAndSettle();

    expect(find.byType(TrendingMoreScreen), findsOneWidget);
  });

  testWidgets('All trending topics feed opens the full trend page', (
    WidgetTester tester,
  ) async {
    TrendStore.instance.clear();
    TrendStore.instance.post(
      title: 'Library hours',
      body: 'The library is now open until 10 PM through the exam period.',
      author: 'Ama Boateng',
    );

    await tester.pumpWidget(const MaterialApp(home: TrendingMoreScreen()));
    await tester.pumpAndSettle();

    expect(find.text('All trending topics'), findsOneWidget);
    expect(find.byKey(const ValueKey('trend-feed-list')), findsOneWidget);
    expect(find.byKey(const ValueKey('trend-feed-0')), findsOneWidget);
    expect(find.text('Library hours'), findsOneWidget);
    expect(find.text('Ama Boateng'), findsOneWidget);
    expect(find.text('View info'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('trend-feed-0')));
    await tester.pumpAndSettle();

    expect(find.byType(TrendingDetailScreen), findsOneWidget);
    expect(find.text('Comments'), findsOneWidget);
    expect(find.text('Library hours'), findsOneWidget);

    TrendStore.instance.clear();
  });

  testWidgets('Empty trending feed uses the same icon as Updates', (
    WidgetTester tester,
  ) async {
    TrendStore.instance.clear();

    await tester.pumpWidget(const MaterialApp(home: TrendingMoreScreen()));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('trend-feed-empty')), findsOneWidget);
    expect(find.byIcon(LucideIcons.trendingUp), findsOneWidget);
    expect(find.byIcon(LucideIcons.sparkles), findsNothing);
    expect(find.text('No trending stories yet'), findsOneWidget);
  });

  testWidgets('Trend cover keeps the local thumbnail when the URL fails', (
    WidgetTester tester,
  ) async {
    final source = img.Image(width: 8, height: 8);
    img.fill(source, color: img.ColorRgb8(37, 161, 12));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 100,
            height: 100,
            child: TrendCover(
              media: [
                TrendMedia(
                  thumbnail: img.encodeJpg(source),
                  url: 'https://example.invalid/missing.jpg',
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byWidgetPredicate(
        (widget) => widget is Image && widget.image is MemoryImage,
      ),
      findsOneWidget,
    );
  });

  testWidgets('Trending keeps its height while empty and after a post', (
    WidgetTester tester,
  ) async {
    // The gallery plugin is unavailable on the test host; pretend this is a
    // desktop platform so the composer skips loading device media.
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;

    TrendStore.instance.clear();
    await tester.pumpWidget(const MaterialApp(home: UpdatesScreen()));

    final emptyHeight = tester
        .getSize(find.byKey(const ValueKey('trending-section')))
        .height;

    await tester.tap(find.byIcon(LucideIcons.plus));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Post Trends'));
    await tester.pumpAndSettle();

    // The composer only checks the platform when it opens.
    debugDefaultTargetPlatformOverride = null;

    expect(find.text('Post Trend'), findsOneWidget);
    expect(find.byKey(const ValueKey('trend-add-media')), findsOneWidget);
    expect(find.byKey(const ValueKey('trend-media-section')), findsNothing);

    await tester.enterText(
      find.byKey(const ValueKey('trend-title')),
      'Library hours',
    );
    await tester.enterText(
      find.byKey(const ValueKey('trend-body')),
      'The library is now open until 10 PM through the exam period.',
    );
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('post-trend-button')));
    await tester.pumpAndSettle();

    expect(find.text('No Trending news available'), findsNothing);
    expect(find.text('Library hours'), findsOneWidget);
    expect(find.byKey(const ValueKey('trending-0')), findsOneWidget);

    // The row keeps the same height after the post.
    final postedHeight = tester
        .getSize(find.byKey(const ValueKey('trending-section')))
        .height;
    expect(postedHeight, emptyHeight);
    expect(emptyHeight, 200);
  });

  testWidgets('Updates shows the Upcoming Activities grid', (
    WidgetTester tester,
  ) async {
    seedActivities();
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

  testWidgets('Upcoming activities shows a floating empty state', (
    WidgetTester tester,
  ) async {
    ActivityStore.instance.clear();
    await tester.pumpWidget(const MaterialApp(home: UpdatesScreen()));
    await tester.drag(
      find.byKey(const ValueKey('updates-scroll')),
      const Offset(0, -900),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('activity-empty')), findsOneWidget);
    expect(find.text('No upcoming activities yet'), findsOneWidget);
    expect(find.byIcon(LucideIcons.calendarCheck), findsOneWidget);
  });

  testWidgets('Adding an activity opens the composer and updates the grid', (
    WidgetTester tester,
  ) async {
    ActivityStore.instance.clear();
    await tester.pumpWidget(const MaterialApp(home: UpdatesScreen()));

    await tester.tap(find.byIcon(LucideIcons.plus));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add Activity'));
    await tester.pumpAndSettle();

    expect(find.text('New Activity'), findsOneWidget);
    expect(find.byKey(const ValueKey('activity-title')), findsOneWidget);
    expect(find.byKey(const ValueKey('activity-date')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('activity-date')));
    await tester.pumpAndSettle();
    expect(find.byType(DatePickerDialog), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('activity-title')),
      'Alumni Meetup',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('add-activity-button')));
    await tester.pumpAndSettle();

    expect(find.text('New Activity'), findsNothing);
    expect(
      ActivityStore.instance.items.any(
        (activity) => activity.title == 'Alumni Meetup',
      ),
      isTrue,
    );
    final added = ActivityStore.instance.items.firstWhere(
      (activity) => activity.title == 'Alumni Meetup',
    );
    expect(
      tester
          .widget<ColoredBox>(find.byKey(ValueKey('activity-bar-${added.id}')))
          .color,
      SpotifyColors.accent,
    );
    expect(find.text('Alumni Meetup'), findsOneWidget);

    ActivityStore.instance.clear();
  });

  testWidgets('Past activities use a grey sidebar', (
    WidgetTester tester,
  ) async {
    ActivityStore.instance.clear();
    final past = ActivityStore.instance.add(
      title: 'Old Event',
      date: DateTime.now().subtract(const Duration(days: 3)),
    );

    await tester.pumpWidget(const MaterialApp(home: UpdatesScreen()));
    await tester.drag(
      find.byKey(const ValueKey('updates-scroll')),
      const Offset(0, -900),
    );
    await tester.pumpAndSettle();

    expect(find.text('Old Event'), findsOneWidget);
    final bar = tester.widget<ColoredBox>(
      find.byKey(ValueKey('activity-bar-${past.id}')),
    );
    expect(bar.color, SpotifyColors.tagMuted);

    ActivityStore.instance.clear();
  });

  testWidgets('The activity author can double-tap and remove it', (
    WidgetTester tester,
  ) async {
    ActivityStore.instance.clear();
    final activity = ActivityStore.instance.add(
      title: 'Team Sync',
      date: DateTime.now().add(const Duration(days: 1)),
      authorId: 'author-1',
    );

    await tester.pumpWidget(
      const MaterialApp(home: UpdatesScreen(viewerId: 'author-1')),
    );
    await tester.drag(
      find.byKey(const ValueKey('updates-scroll')),
      const Offset(0, -900),
    );
    await tester.pumpAndSettle();

    final card = find.byKey(const ValueKey('activity-0'));
    expect(card, findsOneWidget);
    final delete = find.byKey(ValueKey('activity-delete-${activity.id}'));
    expect(delete, findsNothing);

    await tester.tap(card);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(card);
    await tester.pumpAndSettle();

    expect(delete, findsOneWidget);

    await tester.tap(delete);
    await tester.pumpAndSettle();

    expect(ActivityStore.instance.items, isEmpty);
    expect(find.text('No upcoming activities yet'), findsOneWidget);
    expect(find.byKey(const ValueKey('activity-empty')), findsOneWidget);

    ActivityStore.instance.clear();
  });

  testWidgets('Tapping an announcement opens its detail page', (
    WidgetTester tester,
  ) async {
    seedAnnouncements();
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
    seedAnnouncements();
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

  testWidgets('Only the author can delete an announcement', (
    WidgetTester tester,
  ) async {
    final store = AnnouncementStore.instance;
    store.clear();
    final announcement = store.post(
      author: 'Dr. Mensah',
      authorId: 'author-1',
      tag: 'Highly prior',
      tagColor: SpotifyColors.tagUrgent,
      body: 'Bring your lab report on Friday.',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: AnnouncementDetailScreen(
          announcement: announcement,
          viewerId: 'author-2',
        ),
      ),
    );
    expect(find.byTooltip('Delete announcement'), findsNothing);

    await tester.pumpWidget(
      MaterialApp(
        home: AnnouncementDetailScreen(
          announcement: announcement,
          viewerId: 'author-1',
        ),
      ),
    );
    await tester.pump();
    expect(find.byTooltip('Delete announcement'), findsOneWidget);

    await tester.tap(find.byTooltip('Delete announcement'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(store.items, isEmpty);
  });

  testWidgets('Only the announcement author can swipe it away', (
    WidgetTester tester,
  ) async {
    final store = AnnouncementStore.instance;
    store.clear();
    final announcement = store.post(
      author: 'Dr. Mensah',
      authorId: 'author-1',
      tag: 'Highly prior',
      tagColor: SpotifyColors.tagUrgent,
      body: 'Bring your lab report on Friday.',
    );
    final deleteBackground = find.byKey(
      ValueKey('announcement-delete-bg-${announcement.id}'),
    );

    await tester.pumpWidget(
      const MaterialApp(home: UpdatesScreen(viewerId: 'author-2')),
    );
    expect(deleteBackground, findsNothing);
    await tester.drag(
      find.byKey(const ValueKey('announcement-0')),
      const Offset(-400, 0),
    );
    await tester.pumpAndSettle();
    expect(store.items, hasLength(1));

    await tester.pumpWidget(
      const MaterialApp(home: UpdatesScreen(viewerId: 'author-1')),
    );
    await tester.pumpAndSettle();
    expect(find.byType(Dismissible), findsOneWidget);

    final partial = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey('announcement-0'))),
    );
    await partial.moveBy(const Offset(-60, 0));
    await tester.pump(const Duration(milliseconds: 16));
    await partial.moveBy(const Offset(-60, 0));
    await tester.pump(const Duration(milliseconds: 16));
    expect(deleteBackground, findsOneWidget);
    final background = tester.widget<Container>(deleteBackground);
    expect(background.color, SpotifyColors.accent);
    await partial.up();
    await tester.pumpAndSettle();

    await tester.drag(
      find.byKey(const ValueKey('announcement-0')),
      const Offset(-400, 0),
    );
    await tester.pumpAndSettle();

    expect(store.items, isEmpty);
    expect(find.text('Bring your lab report on Friday.'), findsNothing);

    store.clear();
  });

  testWidgets('Announcement detail supports posting a comment', (
    WidgetTester tester,
  ) async {
    CommentStore.instance.clear();
    await tester.pumpWidget(
      const MaterialApp(
        home: AnnouncementDetailScreen(
          announcement: Announcement(
            id: 'test-announcement-comment',
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
    expect(find.text('No comments yet'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Noted, thank you!');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('comment-send-button')));
    await tester.pumpAndSettle();

    expect(find.text('Noted, thank you!'), findsOneWidget);
    expect(find.text('You'), findsOneWidget);
  });

  testWidgets('Long pressing a comment starts a reply', (
    WidgetTester tester,
  ) async {
    CommentStore.instance.clear();
    await tester.pumpWidget(
      const MaterialApp(
        home: AnnouncementDetailScreen(
          announcement: Announcement(
            id: 'test-announcement-reply',
            author: 'Dr. Mensah',
            time: '9:41 AM',
            tag: 'Highly prior',
            tagColor: Color(0xFFE8A33D),
            body: 'The lab report is due this Friday before 5:00 PM.',
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), 'When is the deadline?');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('comment-send-button')));
    await tester.pumpAndSettle();

    await tester.longPress(find.text('When is the deadline?'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('comment-reply-preview')), findsOneWidget);
    expect(find.text('Replying to You'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Friday at 5 PM.');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('comment-send-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('comment-reply-preview')), findsNothing);
    expect(find.text('Friday at 5 PM.'), findsOneWidget);
    expect(find.text('Replying to You'), findsOneWidget);
  });

  testWidgets('Trending detail supports posting a comment', (
    WidgetTester tester,
  ) async {
    TrendStore.instance.clear();
    TrendStore.instance.post(
      title: 'Library hours',
      body: 'The library is now open until 10 PM through the exam period.',
      author: 'Ama Boateng',
    );
    final trend = TrendStore.instance.items.first;

    await tester.pumpWidget(
      MaterialApp(home: TrendingDetailScreen(trend: trend)),
    );

    expect(find.text('Comments'), findsOneWidget);
    expect(find.text('No comments yet'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'See you there!');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('comment-send-button')));
    await tester.pumpAndSettle();

    expect(find.text('See you there!'), findsOneWidget);
    expect(find.text('You'), findsOneWidget);

    TrendStore.instance.clear();
  });

  testWidgets('Trending reactions toggle and tally', (
    WidgetTester tester,
  ) async {
    TrendStore.instance.clear();
    ReactionStore.instance.clear();
    TrendStore.instance.post(
      title: 'Library hours',
      body: 'The library is now open until 10 PM through the exam period.',
      author: 'Ama Boateng',
    );
    final trend = TrendStore.instance.items.first;

    await tester.pumpWidget(
      MaterialApp(home: TrendingDetailScreen(trend: trend)),
    );

    await tester.tap(find.byIcon(LucideIcons.smilePlus));
    await tester.pumpAndSettle();

    // The picker offers a broader emoji set than the old nine reactions.
    expect(find.text('😍'), findsOneWidget);
    expect(find.text('💯'), findsOneWidget);
    expect(find.text('🙏'), findsOneWidget);
    expect(find.text('🚀'), findsOneWidget);

    await tester.tap(find.text('🔥').last);
    await tester.pumpAndSettle();

    expect(find.text('1'), findsOneWidget);

    // Tapping the tally again removes the reaction.
    await tester.tap(find.text('🔥'));
    await tester.pumpAndSettle();
    expect(find.text('1'), findsNothing);

    TrendStore.instance.clear();
    ReactionStore.instance.clear();
  });

  testWidgets('Only the trend author can delete a trend', (
    WidgetTester tester,
  ) async {
    TrendStore.instance.clear();
    final trend = TrendStore.instance.post(
      title: 'Library hours',
      body: 'The library is now open until 10 PM through the exam period.',
      author: 'Ama Boateng',
      authorId: 'author-1',
    );
    const deleteButton = ValueKey('delete-trend-button');

    await tester.pumpWidget(
      MaterialApp(
        home: TrendingDetailScreen(trend: trend, viewerId: 'author-2'),
      ),
    );
    expect(find.byKey(deleteButton), findsNothing);

    await tester.pumpWidget(
      MaterialApp(
        home: TrendingDetailScreen(trend: trend, viewerId: 'author-1'),
      ),
    );
    await tester.pump();
    expect(find.byKey(deleteButton), findsOneWidget);

    await tester.tap(find.byKey(deleteButton));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('delete-trend-confirm')));
    await tester.pumpAndSettle();

    expect(TrendStore.instance.items, isEmpty);
    TrendStore.instance.clear();
  });

  testWidgets('Home shell supports swiping between sections', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: HomeShell()));
    final pages = find.byType(PageView);
    expect(pages, findsOneWidget);

    // Swipe right to move from Updates to Messages. Start near the top so the
    // drag does not land on an inner horizontal list (trending/stories).
    await tester.flingFrom(const Offset(400, 30), const Offset(-300, 0), 1000);
    await tester.pumpAndSettle();

    expect(find.text('Messages'), findsNWidgets(2));
    expect(find.text('Csc 200 level'), findsNothing);

    // Swipe back to Updates.
    await tester.flingFrom(const Offset(400, 30), const Offset(300, 0), 1000);
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

  testWidgets('Finance Add Funds shows account details and copies', (
    WidgetTester tester,
  ) async {
    final calls = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') calls.add(call);
        return null;
      },
    );
    addTearDown(() {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      );
    });

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: FinanceScreen())),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('add-funds-button')));
    await tester.pumpAndSettle();

    expect(find.text('Add Funds'), findsWidgets);
    expect(find.text('Account name'), findsOneWidget);
    expect(find.text('Odeh Solomon'), findsNWidgets(2));
    expect(find.text('4267438338'), findsNWidgets(2));
    expect(find.text('Kuda Bank'), findsNWidgets(2));
    expect(find.text('Student details'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('copy-funds-account')));
    await tester.pump();

    expect(calls, isNotEmpty);
    expect(calls.last.arguments['text'], '4267438338');
    expect(find.text('Account number copied'), findsOneWidget);
  });

  testWidgets('Finance copy icon copies the account number', (
    WidgetTester tester,
  ) async {
    final calls = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') calls.add(call);
        return null;
      },
    );
    addTearDown(() {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      );
    });

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: FinanceScreen())),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('copy-account-number')));
    await tester.pump();

    expect(calls, isNotEmpty);
    expect(calls.last.arguments['text'], '4267438338');
    expect(find.text('Account number copied'), findsOneWidget);
  });

  testWidgets('Finance adds an expenditure from the add action', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: FinanceScreen())),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('finance-add-button')));
    await tester.pumpAndSettle();
    expect(find.text('Add Expenditure'), findsOneWidget);

    await tester.tap(find.text('Add Expenditure'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('expenditure-title')), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('expenditure-title')),
      'Lab coat',
    );
    await tester.enterText(
      find.byKey(const ValueKey('expenditure-amount')),
      '7500',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('add-expenditure-button')));
    await tester.pumpAndSettle();

    await tester.drag(find.byType(ListView).first, const Offset(0, -600));
    await tester.pumpAndSettle();

    expect(find.text('Lab coat'), findsWidgets);
    expect(find.text('₦7,500.00'), findsOneWidget);
  });

  testWidgets('Finance View History opens the empty history page', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: FinanceScreen())),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('view-history-button')));
    await tester.pumpAndSettle();

    expect(find.byType(ViewHistoryScreen), findsOneWidget);
    expect(find.byKey(const ValueKey('no-history-message')), findsOneWidget);
    expect(find.text('No history yet'), findsOneWidget);
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
    await tester.drag(find.byType(ListView).first, const Offset(0, -140));
    await tester.pumpAndSettle();
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
    await tester.drag(find.byType(ListView).first, const Offset(0, -140));
    await tester.pumpAndSettle();
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

    expect(find.byIcon(LucideIcons.plus), findsOneWidget);
    expect(find.text('New Announcement'), findsNothing);
    expect(find.text('Post Trends'), findsNothing);
    expect(find.text('Add Activity'), findsNothing);

    await tester.tap(find.byIcon(LucideIcons.plus));
    await tester.pumpAndSettle();

    expect(find.text('New Announcement'), findsOneWidget);
    expect(find.text('Post Trends'), findsOneWidget);
    expect(find.text('Add Activity'), findsOneWidget);

    await tester.tap(find.byIcon(LucideIcons.plus));
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

    expect(find.byIcon(LucideIcons.plus), findsOneWidget);
    expect(find.text('Add Story'), findsNothing);
    expect(find.text('New DM'), findsNothing);
    expect(find.text('New Group'), findsNothing);

    await tester.tap(find.byIcon(LucideIcons.plus));
    await tester.pumpAndSettle();

    expect(find.text('Add Story'), findsOneWidget);
    expect(find.text('New DM'), findsOneWidget);
    expect(find.text('New Group'), findsOneWidget);
    expect(
      tester.widget<Widget>(find.byKey(const ValueKey('compose-icon-New DM'))),
      isA<SvgPicture>(),
    );
    expect(find.byIcon(LucideIcons.pencil), findsNothing);

    await tester.tap(find.byIcon(LucideIcons.plus));
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
    expect(find.text('Edit your profile to add your bio'), findsOneWidget);
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

  testWidgets('Edit profile shows an error when saving is unavailable', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: EditProfileSheet(username: 'wayne', bio: ''),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('edit-profile-save')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('edit-profile-error')), findsOneWidget);
    expect(
      find.text('You need to be signed in to save changes.'),
      findsOneWidget,
    );
  });

  testWidgets('More tab shows its workspace bar', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: MoreScreen())),
    );

    expect(find.text('More'), findsOneWidget);
    expect(find.byType(UserAvatar), findsOneWidget);
    expect(find.text('Profile'), findsNothing);
    expect(find.text('Library'), findsOneWidget);
    expect(find.text('CGPA Tracker'), findsOneWidget);
    expect(find.text('Student Agents'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
  });

  testWidgets('Posting an announcement adds it to the feed', (
    WidgetTester tester,
  ) async {
    AnnouncementStore.instance.clear();
    await tester.pumpWidget(const MaterialApp(home: UpdatesScreen()));

    await tester.tap(find.byIcon(LucideIcons.plus));
    await tester.pumpAndSettle();

    await tester.tap(find.text('New Announcement'));
    await tester.pumpAndSettle();

    final sheet = find.byType(ComposeAnnouncementSheet);
    expect(sheet, findsOneWidget);
    expect(find.text('Post announcement'), findsOneWidget);

    await tester.tap(
      find.descendant(of: sheet, matching: find.text('Highly prior')),
    );
    await tester.pump();

    const body = 'Midweek check-in moved to 4 PM';
    await tester.enterText(
      find.descendant(of: sheet, matching: find.byType(TextField)),
      body,
    );
    await tester.pump();

    await tester.tap(find.text('Post announcement'));
    await tester.pumpAndSettle();

    expect(sheet, findsNothing);
    expect(find.text(body), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('announcement-0')),
        matching: find.text('Highly prior'),
      ),
      findsOneWidget,
    );
  });
}
