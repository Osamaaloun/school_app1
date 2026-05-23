import 'grade_level.dart';

class StudentSearchResult {
  const StudentSearchResult({
    required this.id,
    required this.name,
    required this.grade,
  });

  final int id;
  final String name;
  final GradeLevel grade;
}
