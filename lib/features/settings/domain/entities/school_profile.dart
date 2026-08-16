/// How the school logo is stored. IO platforms keep it as a file in the
/// application-support directory; web (no filesystem) falls back to a BLOB
/// row in SQLite.
enum LogoKind {
  none('none'),
  file('file'),
  blob('blob');

  const LogoKind(this.value);

  final String value;

  static LogoKind fromValue(String? value) => switch (value) {
        'file' => LogoKind.file,
        'blob' => LogoKind.blob,
        _ => LogoKind.none,
      };
}

/// The school identity used across the app: receipts, report exports and the
/// dashboard title. Defaults are safe placeholders so the app never shows a
/// blank header before the profile is configured.
class SchoolProfile {
  const SchoolProfile({
    this.schoolName = '',
    this.address = '',
    this.phone = '',
    this.email = '',
    this.academicYear = '',
    this.receiptFooter = '',
    this.logoKind = LogoKind.none,
    this.logoFileName,
    this.logoMimeType,
  });

  final String schoolName;
  final String address;
  final String phone;
  final String email;
  final String academicYear;
  final String receiptFooter;
  final LogoKind logoKind;
  final String? logoFileName;
  final String? logoMimeType;

  bool get hasLogo => logoKind != LogoKind.none;

  SchoolProfile copyWith({
    String? schoolName,
    String? address,
    String? phone,
    String? email,
    String? academicYear,
    String? receiptFooter,
    LogoKind? logoKind,
    String? logoFileName,
    String? logoMimeType,
  }) {
    return SchoolProfile(
      schoolName: schoolName ?? this.schoolName,
      address: address ?? this.address,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      academicYear: academicYear ?? this.academicYear,
      receiptFooter: receiptFooter ?? this.receiptFooter,
      logoKind: logoKind ?? this.logoKind,
      logoFileName: logoFileName ?? this.logoFileName,
      logoMimeType: logoMimeType ?? this.logoMimeType,
    );
  }
}
