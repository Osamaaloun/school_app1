/// الصفوف من السابع حتى الثاني ثانوي — مسارات تكنولوجيا وإدارة وأكاديمي.
enum GradeLevel {
  grade7(0, 'السابع'),
  grade8(1, 'الثامن'),
  grade9(2, 'التاسع'),
  grade10Technology(3, 'العاشر تكنولوجيا'),
  grade10Administration(4, 'العاشر إدارة'),
  grade10Academic(9, 'العاشر الأكاديمي'),
  firstSecondaryTechnology(5, 'الأول ثانوي تكنولوجيا'),
  firstSecondaryAdministration(6, 'الأول ثانوي إدارة'),
  firstSecondaryAcademic(10, 'الأول ثانوي الأكاديمي'),
  secondSecondaryTechnology(7, 'الثاني ثانوي تكنولوجيا'),
  secondSecondaryAdministration(8, 'الثاني ثانوي إدارة'),
  secondSecondaryAcademic(11, 'الثاني ثانوي الأكاديمي');

  const GradeLevel(this.dbValue, this.arabicLabel);

  final int dbValue;
  final String arabicLabel;

  static GradeLevel? fromDbValue(int? v) {
    if (v == null) return null;
    for (final g in GradeLevel.values) {
      if (g.dbValue == v) return g;
    }
    return null;
  }

  /// وفق التوزيع المدرسي الشائع في الأردن: السابع حتى العاشر (كل المسارات) مجاني؛ الثانوي يُشترى.
  bool get booksDistributedFree {
    switch (this) {
      case GradeLevel.grade7:
      case GradeLevel.grade8:
      case GradeLevel.grade9:
      case GradeLevel.grade10Technology:
      case GradeLevel.grade10Administration:
      case GradeLevel.grade10Academic:
        return true;
      case GradeLevel.firstSecondaryTechnology:
      case GradeLevel.firstSecondaryAdministration:
      case GradeLevel.firstSecondaryAcademic:
      case GradeLevel.secondSecondaryTechnology:
      case GradeLevel.secondSecondaryAdministration:
      case GradeLevel.secondSecondaryAcademic:
        return false;
    }
  }
}
