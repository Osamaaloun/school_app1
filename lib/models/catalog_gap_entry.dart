class CatalogGapEntry {
  const CatalogGapEntry({
    required this.studentId,
    required this.studentName,
    required this.nationalId,
    required this.missingCatalogTitles,
  });

  final int studentId;
  final String studentName;
  final String nationalId;
  final List<String> missingCatalogTitles;

  bool get hasGap => missingCatalogTitles.isNotEmpty;
}
