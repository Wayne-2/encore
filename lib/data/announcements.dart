import '../models/announcement.dart';
import '../theme/spotify_colors.dart';

/// Sample announcement feed shared by the Updates feed (first three) and the
/// full [AnnouncementsScreen] list.
const List<Announcement> kAnnouncements = [
  Announcement(
    author: 'Dr. Mensah',
    time: '9:41 AM',
    tag: 'Highly prior',
    tagColor: SpotifyColors.tagUrgent,
    unread: true,
    body:
        'Good morning. The Csc 200 lab report is due this Friday — please '
        'submit before 5:00 PM. Late submissions will not be graded.',
  ),
  Announcement(
    author: 'Course Rep',
    time: '8:15 AM',
    tag: 'General announcement',
    tagColor: SpotifyColors.tagInfo,
    unread: true,
    body:
        "Today's lecture has been moved to the main auditorium. We start at "
        '10:00 AM instead, so no need to rush for the 8 o\'clock slot.',
  ),
  Announcement(
    author: 'Prof. Adeyemi',
    time: 'Yesterday',
    tag: 'Less prior',
    tagColor: SpotifyColors.tagMuted,
    body:
        'Continuous assessment scores are out. Check the department notice '
        'board for your marks and reach out if anything looks off.',
  ),
  Announcement(
    author: 'Exams Office',
    time: 'Yesterday',
    tag: 'General announcement',
    tagColor: SpotifyColors.tagInfo,
    body:
        'The end-of-semester examination timetable has been published. Verify '
        'your course codes and report any clash to the office.',
  ),
  Announcement(
    author: 'Library Admin',
    time: 'Mon',
    tag: 'General announcement',
    tagColor: SpotifyColors.tagInfo,
    body:
        'Library opening hours are extended to 10:00 PM through the exam '
        'period. Bring your student ID for after-hours access.',
  ),
  Announcement(
    author: 'Dr. Mensah',
    time: 'Mon',
    tag: 'Highly prior',
    tagColor: SpotifyColors.tagUrgent,
    body:
        'Reminder: the Csc 200 practical holds in Lab 3 this week. Come with '
        'your laptop and your completed pre-lab exercise.',
  ),
  Announcement(
    author: 'Housing Office',
    time: 'Sun',
    tag: 'Less prior',
    tagColor: SpotifyColors.tagMuted,
    body:
        'Hostel room ballot closes this Friday at 6:00 PM. Rank your preferred '
        'halls on the portal before the deadline.',
  ),
  Announcement(
    author: 'Career Services',
    time: 'Sun',
    tag: 'General announcement',
    tagColor: SpotifyColors.tagInfo,
    body:
        'The annual career fair holds next Wednesday. Bring copies of your CV '
        'and dress smart; doors open at 9:00 AM.',
  ),
  Announcement(
    author: 'Sports Council',
    time: 'Last week',
    tag: 'Less prior',
    tagColor: SpotifyColors.tagMuted,
    body:
        'Inter-faculty sports week kicks off on Monday. Registration for track '
        'events closes Friday at the sports office.',
  ),
  Announcement(
    author: 'Prof. Adeyemi',
    time: 'Last week',
    tag: 'General announcement',
    tagColor: SpotifyColors.tagInfo,
    body:
        'Extra tutorial for Csc 200 holds on Thursday at 4:00 PM in the main '
        'auditorium. Attendance is strongly encouraged.',
  ),
];
