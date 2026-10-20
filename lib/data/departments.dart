/// Departments offered to students, stored as short codes in Firestore.
const List<String> kDepartments = ['CSC', 'SOE', 'CYB', 'IFT'];

/// Normalises a stored department to its short code.
///
/// Older accounts stored free-text department names, so both full names and
/// codes map to the same canonical value. Unknown values are kept (trimmed) so
/// the client and Firestore rules agree.
String normalizeDepartment(String value) {
  switch (value.trim().toLowerCase()) {
    case 'computer science':
    case 'csc':
      return 'CSC';
    case 'software engineering':
    case 'soe':
      return 'SOE';
    case 'cyber security':
    case 'cybersecurity':
    case 'cyb':
      return 'CYB';
    case 'information technology':
    case 'ift':
      return 'IFT';
    default:
      return value.trim();
  }
}
