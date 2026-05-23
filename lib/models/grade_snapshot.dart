import 'grade_level.dart';

class GradeSnapshot {
  const GradeSnapshot({
    required this.grade,
    required this.studentCount,
    required this.catalogTitleCount,
    required this.studentsWithShortageCount,
  });

  final GradeLevel grade;
  final int studentCount;
  final int catalogTitleCount;
  final int studentsWithShortageCount;

  bool get hasCatalog => catalogTitleCount > 0;
}
