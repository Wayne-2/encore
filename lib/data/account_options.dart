/// Roles offered during sign-up. The value is stored verbatim in Firestore.
const String kStudentRole = 'Student';
const String kAdminRole = 'Admin';

/// The faculty is fixed for now.
const String kFaculty = 'SICT';

/// Enrolled levels offered to students (also used to group feeds and chats).
const List<String> kLevels = [
  '100 Level',
  '200 Level',
  '300 Level',
  '400 Level',
  '500 Level',
  'Extras',
  'Alumni',
];
