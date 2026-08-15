import 'dart:convert' show utf8;
import 'dart:typed_data';

/// A tiny, dependency-free single-page PDF writer for plain-text documents
/// such as fee receipts.
///
/// It uses only the built-in Helvetica fonts, so it works fully offline on
/// Windows and web without any native plugin. Only Latin-1 text is
/// representable; characters outside the WinAnsi range are replaced with '?'.
class SimplePdfWriter {
  SimplePdfWriter({this.pageWidth = 595, this.pageHeight = 842});

  final double pageWidth;
  final double pageHeight;

  static const double _margin = 50;

  final List<_TextLine> _lines = [];
  final List<_HRule> _rules = [];
  double _y = 790;

  /// Adds a line of text at the current cursor, advancing the cursor.
  void text(
    String value, {
    double size = 11,
    bool bold = false,
    double indent = 0,
  }) {
    _lines.add(
      _TextLine(
        _winAnsi(value),
        size,
        bold ? 'F2' : 'F1',
        _margin + indent,
        _y,
      ),
    );
    _y -= size * 1.5;
  }

  /// Adds a horizontal rule and advances the cursor.
  void rule() {
    _rules.add(_HRule(_margin, _y - 6, pageWidth - _margin, _y - 6));
    _y -= 18;
  }

  /// Adds vertical space.
  void spacer(double points) => _y -= points;

  /// Renders the document and returns the raw PDF bytes.
  Uint8List build() {
    final content = StringBuffer()
      ..writeln('1 0 0 1 0 0 cm');
    for (final line in _lines) {
      content.writeln('BT /${line.font} ${_fmt(line.size)} Tf '
          '${_fmt(line.x)} ${_fmt(line.y)} Td '
          '(${_escape(line.value)}) Tj ET');
    }
    for (final rule in _rules) {
      content.writeln(
        '${_fmt(rule.x1)} ${_fmt(rule.y1)} m '
        '${_fmt(rule.x2)} ${_fmt(rule.y2)} l S',
      );
    }

    final stream = content.toString();
    final objects = <String>[
      '<< /Type /Catalog /Pages 2 0 R >>',
      '<< /Type /Pages /Kids [3 0 R] /Count 1 >>',
      '<< /Type /Page /Parent 2 0 R '
          '/MediaBox [0 0 ${_fmt(pageWidth)} ${_fmt(pageHeight)}] '
          '/Resources << /Font << /F1 4 0 R /F2 5 0 R >> >> '
          '/Contents 6 0 R >>',
      '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>',
      '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica-Bold >>',
      '<< /Length ${stream.length} >>\n'
          'stream\n$stream\nendstream',
    ];

    final buffer = BytesBuilder();
    buffer.add(utf8.encode('%PDF-1.4\n'));
    final offsets = <int>[];
    for (var i = 0; i < objects.length; i++) {
      offsets.add(buffer.length);
      buffer.add(utf8.encode('${i + 1} 0 obj\n${objects[i]}\nendobj\n'));
    }
    final xrefStart = buffer.length;
    buffer.add(utf8.encode('xref\n0 ${objects.length + 1}\n'));
    buffer.add(utf8.encode('0000000000 65535 f \n'));
    for (final offset in offsets) {
      buffer.add(utf8.encode('${offset.toString().padLeft(10, '0')} 00000 n \n'));
    }
    buffer.add(utf8.encode(
        'trailer\n<< /Size ${objects.length + 1} /Root 1 0 R >>\n'));
    buffer.add(utf8.encode('startxref\n$xrefStart\n%%EOF\n'));
    return buffer.toBytes();
  }

  /// Escapes PDF string special characters and maps to WinAnsi.
  static String _escape(String value) {
    return value
        .replaceAll('\\', r'\\')
        .replaceAll('(', r'\(')
        .replaceAll(')', r'\)');
  }

  static String _winAnsi(String value) {
    final codes = value.codeUnits.map((c) => c > 255 ? 0x3F : c);
    return String.fromCharCodes(codes);
  }

  static String _fmt(double value) => value.toStringAsFixed(2);
}

class _TextLine {
  const _TextLine(this.value, this.size, this.font, this.x, this.y);

  final String value;
  final double size;
  final String font;
  final double x;
  final double y;
}

class _HRule {
  const _HRule(this.x1, this.y1, this.x2, this.y2);

  final double x1;
  final double y1;
  final double x2;
  final double y2;
}
