import '../entities/family_outstanding_row.dart';
import '../entities/fee_generation_result.dart';
import '../entities/fee_period.dart';
import '../entities/fee_record.dart';
import '../entities/fee_record_details.dart';
import '../entities/fee_record_list_item.dart';
import '../entities/fee_status.dart';
import '../entities/fee_structure.dart';
import '../entities/fee_student_pick.dart';
import '../entities/monthly_collection_report.dart';
import '../entities/payment_record.dart';
import '../entities/receipt_data.dart';
import '../entities/unpaid_student_row.dart';

/// Thrown when a payment would exceed the fee record's remaining amount.
/// Overpayment is deliberately not supported by the business rules.
class OverpaymentException implements Exception {
  const OverpaymentException(this.remaining);

  final double remaining;

  @override
  String toString() =>
      'OverpaymentException: only ${remaining.toStringAsFixed(2)} remains.';
}

/// Thrown when a receipt number is already in use.
class DuplicateReceiptException implements Exception {
  const DuplicateReceiptException(this.receiptNumber);

  final String receiptNumber;

  @override
  String toString() => 'DuplicateReceiptException: $receiptNumber';
}

/// Data operations for the Fee Management module.
///
/// Implementations guarantee: balances and statuses are only ever changed
/// inside the same transaction as the payment/reversal/adjustment that caused
/// them; payments are never deleted (only reversed); overpayment is rejected;
/// receipt numbers are unique; a student has at most one charge per month.
abstract interface class FeeRepository {
  // Fee structures/rules ------------------------------------------------

  Future<List<FeeStructure>> listFeeStructures();

  Future<FeeStructure> createFeeStructure({
    required String name,
    String? className,
    required double monthlyAmount,
    double discountAmount,
    String? description,
    required FeeType feeType,
  });

  Future<FeeStructure> updateFeeStructure({
    required int id,
    required String name,
    String? className,
    required double monthlyAmount,
    double discountAmount,
    String? description,
    required FeeType feeType,
  });

  Future<void> setFeeStructureActive(int id, bool isActive);

  // Generation -----------------------------------------------------------

  /// Creates monthly fee records for every active student, resolving the
  /// amount from the student's class rule (else the global default rule).
  /// Students without a rule, or who already have a record for the period,
  /// are reported and skipped. Runs in a single transaction.
  Future<FeeGenerationResult> generateMonthlyFees({
    required int year,
    required int month,
    void Function(int processed, int total)? onProgress,
  });

  // Records + search ------------------------------------------------------

  Future<List<FeeRecordListItem>> searchFeeRecords({
    String query,
    FeePeriod? period,
    FeeStatus? status,
    String? className,
    int? studentId,
  });

  Future<FeeRecord?> getFeeRecord(int id);

  Future<FeeRecordDetails> getFeeRecordDetails(int id);

  Future<List<FeeRecord>> listOpenFeeRecords(int studentId);

  Future<FeeRecord?> getFeeRecordForPeriod(int studentId, FeePeriod period);

  Future<List<FeeRecord>> studentFeeHistory(int studentId);

  Future<List<FeeStudentPick>> searchStudents(String query, {int limit = 20});

  /// Distinct student classes, for the record-search class filter.
  Future<List<String>> distinctClasses();

  // Payments ---------------------------------------------------------------

  /// Records a payment and updates the fee record's balance/status in the same
  /// transaction. Throws [OverpaymentException] when `amount` exceeds the
  /// remaining balance and [DuplicateReceiptException] for a used receipt.
  Future<PaymentRecord> recordPayment({
    required int feeRecordId,
    required int studentId,
    required double amount,
    required DateTime paymentDate,
    String? receiptNumber,
    String? note,
    int? createdByUserId,
    String? createdByName,
  });

  /// Controlled reversal: flags the payment as reversed (never deletes it) and
  /// restores the fee record's balance/status in the same transaction.
  Future<PaymentRecord> reversePayment({
    required int paymentId,
    int? byUserId,
    String? byName,
    String? reason,
  });

  /// Adjusts a record's discount/fine, recomputing net payable and remaining
  /// in a transaction.
  Future<FeeRecord> adjustFeeRecord({
    required int feeRecordId,
    double? discount,
    double? fine,
  });

  Future<String> nextReceiptNumber();

  Future<ReceiptData?> receiptData(int paymentId);

  // Reports ----------------------------------------------------------------

  Future<MonthlyCollectionReport> monthlyCollection({
    required int year,
    required int month,
  });

  Future<double> totalOutstanding();

  Future<List<UnpaidStudentRow>> unpaidStudents(FeePeriod period);

  Future<List<FamilyOutstandingRow>> familyOutstanding();
}
