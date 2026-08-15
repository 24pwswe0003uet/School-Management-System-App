import 'package:school_office_management/features/fee/domain/entities/family_outstanding_row.dart';
import 'package:school_office_management/features/fee/domain/entities/fee_generation_result.dart';
import 'package:school_office_management/features/fee/domain/entities/fee_period.dart';
import 'package:school_office_management/features/fee/domain/entities/fee_record.dart';
import 'package:school_office_management/features/fee/domain/entities/fee_record_details.dart';
import 'package:school_office_management/features/fee/domain/entities/fee_record_list_item.dart';
import 'package:school_office_management/features/fee/domain/entities/fee_status.dart';
import 'package:school_office_management/features/fee/domain/entities/fee_structure.dart';
import 'package:school_office_management/features/fee/domain/entities/fee_student_pick.dart';
import 'package:school_office_management/features/fee/domain/entities/monthly_collection_report.dart';
import 'package:school_office_management/features/fee/domain/entities/payment_record.dart';
import 'package:school_office_management/features/fee/domain/entities/receipt_data.dart';
import 'package:school_office_management/features/fee/domain/entities/unpaid_student_row.dart';
import 'package:school_office_management/features/fee/domain/repositories/fee_repository.dart';

/// In-memory [FeeRepository] for widget tests. Mirrors the repository's
/// business rules (overpayment rejection, unique receipts, auto IDs, status
/// updates on payment) without a database.
class FakeFeeRepository implements FeeRepository {
  FakeFeeRepository({
    List<FeeStudentPick>? students,
    List<FeeRecord>? records,
    List<PaymentRecord>? payments,
    List<FeeStructure>? structures,
    List<FamilyOutstandingRow>? familyOutstandingRows,
    this.generationAmount = 5000,
  })  : students = [...?students],
        records = [...?records],
        payments = [...?payments],
        structures = [...?structures],
        familyOutstandingRows = [...?familyOutstandingRows];

  final List<FeeStudentPick> students;
  final List<FeeRecord> records;
  final List<PaymentRecord> payments;
  final List<FeeStructure> structures;
  final List<FamilyOutstandingRow> familyOutstandingRows;
  double generationAmount;

  bool failSearchStudents = false;
  bool failRecordsSearch = false;
  bool failStructures = false;

  int _nextRecordId = 1000;
  int _nextPaymentId = 1000;

  FeeStudentPick? _studentFor(int studentId) {
    for (final student in students) {
      if (student.id == studentId) return student;
    }
    return null;
  }

  FeeRecord _copyRecord(
    FeeRecord record, {
    double? discount,
    double? fine,
    double? paid,
  }) {
    final nextDiscount = discount ?? record.discount;
    final nextFine = fine ?? record.fine;
    final net = record.expectedAmount - nextDiscount + nextFine;
    final nextPaid = paid ?? record.paidAmount;
    final remaining = (net - nextPaid).clamp(0, net).toDouble();
    final status = remaining <= 0.0001
        ? (nextPaid <= 0.0001 ? FeeStatus.unpaid : FeeStatus.paid)
        : (nextPaid <= 0.0001 ? FeeStatus.unpaid : FeeStatus.partial);
    return FeeRecord(
      id: record.id,
      feeRecordId: record.feeRecordId,
      studentId: record.studentId,
      period: record.period,
      expectedAmount: record.expectedAmount,
      discount: nextDiscount,
      fine: nextFine,
      netPayable: net < 0 ? 0 : net,
      paidAmount: nextPaid,
      remainingAmount: remaining,
      status: status,
    );
  }

  @override
  Future<List<FeeStructure>> listFeeStructures() async {
    if (failStructures) throw Exception('simulated database failure');
    return List.of(structures);
  }

  @override
  Future<FeeStructure> createFeeStructure({
    required String name,
    String? className,
    required double monthlyAmount,
    double discountAmount = 0,
    String? description,
  }) async {
    final id = structures.length + 1;
    final structure = FeeStructure(
      id: id,
      structureId: 'FS-${id.toString().padLeft(6, '0')}',
      name: name,
      className: className,
      monthlyAmount: monthlyAmount,
      discountAmount: discountAmount,
      description: description,
      isActive: true,
    );
    structures.add(structure);
    return structure;
  }

  @override
  Future<FeeStructure> updateFeeStructure({
    required int id,
    required String name,
    String? className,
    required double monthlyAmount,
    double discountAmount = 0,
    String? description,
  }) async {
    final index = structures.indexWhere((s) => s.id == id);
    final existing = structures[index];
    structures[index] = FeeStructure(
      id: existing.id,
      structureId: existing.structureId,
      name: name,
      className: className,
      monthlyAmount: monthlyAmount,
      discountAmount: discountAmount,
      description: description,
      isActive: existing.isActive,
    );
    return structures[index];
  }

  @override
  Future<void> setFeeStructureActive(int id, bool isActive) async {
    final index = structures.indexWhere((s) => s.id == id);
    final existing = structures[index];
    structures[index] = FeeStructure(
      id: existing.id,
      structureId: existing.structureId,
      name: existing.name,
      className: existing.className,
      monthlyAmount: existing.monthlyAmount,
      discountAmount: existing.discountAmount,
      description: existing.description,
      isActive: isActive,
    );
  }

  @override
  Future<FeeGenerationResult> generateMonthlyFees({
    required int year,
    required int month,
    void Function(int processed, int total)? onProgress,
  }) async {
    final period = FeePeriod(year: year, month: month);
    var created = 0;
    var alreadyExists = 0;
    var noRule = 0;
    for (var i = 0; i < students.length; i++) {
      final student = students[i];
      final hasRecord = records.any(
        (r) => r.studentId == student.id && r.period == period,
      );
      if (hasRecord) {
        alreadyExists++;
      } else if (structures.isEmpty && noRuleCase) {
        noRule++;
      } else {
        final id = _nextRecordId++;
        records.add(
          FeeRecord(
            id: id,
            feeRecordId: 'FEE-${id.toString().padLeft(6, '0')}',
            studentId: student.id,
            period: period,
            expectedAmount: generationAmount,
            discount: 0,
            fine: 0,
            netPayable: generationAmount,
            paidAmount: 0,
            remainingAmount: generationAmount,
            status: FeeStatus.unpaid,
          ),
        );
        created++;
      }
      onProgress?.call(i + 1, students.length);
    }
    return FeeGenerationResult(
      created: created,
      alreadyExists: alreadyExists,
      noRule: noRule,
    );
  }

  /// When true and no structures exist, students are reported as "no rule".
  bool noRuleCase = false;

  @override
  Future<List<FeeRecordListItem>> searchFeeRecords({
    String query = '',
    FeePeriod? period,
    FeeStatus? status,
    String? className,
    int? studentId,
  }) async {
    if (failRecordsSearch) throw Exception('simulated database failure');
    final term = query.trim().toLowerCase();
    final rows = records.where((r) {
      if (studentId != null && r.studentId != studentId) return false;
      if (period != null && r.period != period) return false;
      if (status != null && r.status != status) return false;
      final student = _studentFor(r.studentId);
      if (className != null &&
          className.isNotEmpty &&
          student?.className != className) {
        return false;
      }
      if (term.isNotEmpty) {
        final matchesStudent =
            (student?.name.toLowerCase().contains(term) ?? false) ||
            (student?.studentId.toLowerCase().contains(term) ?? false);
        final matchesGuardian =
            (student?.guardianName ?? '').toLowerCase().contains(term);
        if (!matchesStudent && !matchesGuardian) return false;
      }
      return true;
    }).toList();
    rows.sort((a, b) => b.period.year != a.period.year
        ? b.period.year.compareTo(a.period.year)
        : b.period.month.compareTo(a.period.month));
    return rows.map((r) {
      final student = _studentFor(r.studentId);
      return FeeRecordListItem(
        record: r,
        studentId: student?.studentId ?? 'STU-?',
        studentName: student?.name ?? 'Student',
        guardianName: student?.guardianName,
        className: student?.className,
        section: student?.section,
      );
    }).toList();
  }

  @override
  Future<FeeRecord?> getFeeRecord(int id) async {
    for (final record in records) {
      if (record.id == id) return record;
    }
    return null;
  }

  @override
  Future<FeeRecordDetails> getFeeRecordDetails(int id) async {
    final record = await getFeeRecord(id);
    if (record == null) throw ArgumentError('Fee record $id does not exist.');
    final student = _studentFor(record.studentId);
    final recordPayments = payments
        .where((p) => p.feeRecordId == id)
        .toList()
      ..sort((a, b) => b.paymentDate.compareTo(a.paymentDate));
    return FeeRecordDetails(
      record: record,
      studentId: student?.studentId ?? 'STU-?',
      studentName: student?.name ?? 'Student',
      guardianName: student?.guardianName,
      className: student?.className,
      section: student?.section,
      payments: recordPayments,
    );
  }

  @override
  Future<List<FeeRecord>> listOpenFeeRecords(int studentId) async {
    final open = records
        .where(
          (r) =>
              r.studentId == studentId &&
              r.status != FeeStatus.paid,
        )
        .toList()
      ..sort((a, b) => a.period.startIso.compareTo(b.period.startIso));
    return open;
  }

  @override
  Future<FeeRecord?> getFeeRecordForPeriod(
    int studentId,
    FeePeriod period,
  ) async {
    for (final record in records) {
      if (record.studentId == studentId && record.period == period) {
        return record;
      }
    }
    return null;
  }

  @override
  Future<List<FeeRecord>> studentFeeHistory(int studentId) async {
    final history = records
        .where((r) => r.studentId == studentId)
        .toList()
      ..sort((a, b) => b.period.startIso.compareTo(a.period.startIso));
    return history;
  }

  @override
  Future<List<FeeStudentPick>> searchStudents(
    String query, {
    int limit = 20,
  }) async {
    if (failSearchStudents) throw Exception('simulated database failure');
    final term = query.trim().toLowerCase();
    if (term.isEmpty) return const [];
    return students
        .where(
          (s) =>
              s.name.toLowerCase().contains(term) ||
              s.studentId.toLowerCase().contains(term) ||
              (s.guardianName ?? '').toLowerCase().contains(term),
        )
        .take(limit)
        .toList();
  }

  @override
  Future<List<String>> distinctClasses() async {
    final classes = <String>{};
    for (final student in students) {
      if (student.className != null) {
        classes.add(student.className!);
      }
    }
    return classes.toList()..sort();
  }

  @override
  Future<PaymentRecord> recordPayment({
    required int feeRecordId,
    required int studentId,
    required double amount,
    required DateTime paymentDate,
    String? receiptNumber,
    String? note,
    int? createdByUserId,
    String? createdByName,
  }) async {
    if (amount <= 0) {
      throw ArgumentError('Payment amount must be greater than zero.');
    }
    final index = records.indexWhere((r) => r.id == feeRecordId);
    if (index < 0) throw ArgumentError('Fee record $feeRecordId does not exist.');
    final record = records[index];
    if (record.studentId != studentId) {
      throw ArgumentError('Payment student does not match the fee record.');
    }
    if (amount > record.remainingAmount + 0.0001) {
      throw OverpaymentException(record.remainingAmount);
    }
    final receipt = (receiptNumber == null || receiptNumber.trim().isEmpty)
        ? _nextReceipt()
        : receiptNumber.trim();
    final duplicate = payments.any(
      (p) => (p.receiptNumber ?? '').toLowerCase() == receipt.toLowerCase(),
    );
    if (duplicate) throw DuplicateReceiptException(receipt);

    final id = _nextPaymentId++;
    final payment = PaymentRecord(
      id: id,
      paymentId: 'PAY-${id.toString().padLeft(6, '0')}',
      studentId: studentId,
      feeRecordId: feeRecordId,
      amount: amount,
      paymentDate: paymentDate,
      receiptNumber: receipt,
      note: note,
      createdByUserId: createdByUserId,
      createdByName: createdByName,
      status: PaymentStatus.active,
    );
    payments.add(payment);
    records[index] = _copyRecord(record, paid: record.paidAmount + amount);
    return payment;
  }

  String _nextReceipt() {
    final maxNumber = payments.fold(0, (max, p) {
      final value = int.tryParse(
            (p.receiptNumber ?? '').replaceAll(RegExp(r'[^0-9]'), ''),
          ) ??
          0;
      return value > max ? value : max;
    });
    return 'RCP-${(maxNumber + 1).toString().padLeft(6, '0')}';
  }

  @override
  Future<PaymentRecord> reversePayment({
    required int paymentId,
    int? byUserId,
    String? byName,
    String? reason,
  }) async {
    final index = payments.indexWhere((p) => p.id == paymentId);
    if (index < 0) throw ArgumentError('Payment $paymentId does not exist.');
    final payment = payments[index];
    if (payment.status == PaymentStatus.reversed) {
      throw ArgumentError('Payment $paymentId is already reversed.');
    }
    final reversed = PaymentRecord(
      id: payment.id,
      paymentId: payment.paymentId,
      studentId: payment.studentId,
      feeRecordId: payment.feeRecordId,
      amount: payment.amount,
      paymentDate: payment.paymentDate,
      receiptNumber: payment.receiptNumber,
      note: payment.note,
      createdByUserId: payment.createdByUserId,
      createdByName: payment.createdByName,
      status: PaymentStatus.reversed,
      reversedAt: DateTime.now(),
      reversedByName: byName,
      reverseReason: reason,
    );
    payments[index] = reversed;
    final recordIndex = records.indexWhere((r) => r.id == payment.feeRecordId);
    final record = records[recordIndex];
    records[recordIndex] = _copyRecord(
      record,
      paid: (record.paidAmount - payment.amount).clamp(0, record.netPayable),
    );
    return reversed;
  }

  @override
  Future<FeeRecord> adjustFeeRecord({
    required int feeRecordId,
    double? discount,
    double? fine,
  }) async {
    final index = records.indexWhere((r) => r.id == feeRecordId);
    if (index < 0) throw ArgumentError('Fee record $feeRecordId does not exist.');
    final updated = _copyRecord(records[index], discount: discount, fine: fine);
    records[index] = updated;
    return updated;
  }

  @override
  Future<String> nextReceiptNumber() async => _nextReceipt();

  @override
  Future<ReceiptData?> receiptData(int paymentId) async {
    final payment = payments.where((p) => p.id == paymentId).firstOrNull;
    if (payment == null) return null;
    final student = _studentFor(payment.studentId);
    final record = records.where((r) => r.id == payment.feeRecordId).first;
    return ReceiptData(
      paymentId: payment.paymentId,
      receiptNumber: payment.receiptNumber ?? '',
      studentId: student?.studentId ?? 'STU-?',
      studentName: student?.name ?? 'Student',
      guardianName: student?.guardianName,
      periodLabel: record.period.label,
      expectedAmount: record.expectedAmount,
      discount: record.discount,
      fine: record.fine,
      netPayable: record.netPayable,
      paidAmount: record.paidAmount,
      remainingAmount: record.remainingAmount,
      paymentDate: payment.paymentDate,
      paymentNote: payment.note,
      createdByName: payment.createdByName,
      isReversed: payment.status == PaymentStatus.reversed,
    );
  }

  @override
  Future<MonthlyCollectionReport> monthlyCollection({
    required int year,
    required int month,
  }) async {
    final period = FeePeriod(year: year, month: month);
    final inMonth = payments.where((p) {
      if (p.status != PaymentStatus.active) return false;
      return p.paymentDate.year == year && p.paymentDate.month == month;
    }).toList();
    return MonthlyCollectionReport(
      period: period,
      collected: inMonth.fold(0, (sum, p) => sum + p.amount),
      paymentCount: inMonth.length,
    );
  }

  @override
  Future<double> totalOutstanding() async {
    return records
        .where((r) => r.status != FeeStatus.paid)
        .fold<double>(0.0, (sum, r) => sum + r.remainingAmount);
  }

  @override
  Future<List<UnpaidStudentRow>> unpaidStudents(FeePeriod period) async {
    final rows = records.where((r) {
      if (r.period != period) return false;
      if (r.status == FeeStatus.paid) return false;
      return true;
    }).map((r) {
      final student = _studentFor(r.studentId);
      return UnpaidStudentRow(
        record: r,
        studentId: student?.studentId ?? 'STU-?',
        studentName: student?.name ?? 'Student',
        className: student?.className,
        section: student?.section,
        guardianName: student?.guardianName,
      );
    }).toList();
    rows.sort((a, b) => a.studentName.compareTo(b.studentName));
    return rows;
  }

  @override
  Future<List<FamilyOutstandingRow>> familyOutstanding() async {
    return List.of(familyOutstandingRows);
  }
}
