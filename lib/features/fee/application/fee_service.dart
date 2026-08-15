import 'package:flutter/foundation.dart';

import '../../auth/domain/services/auth_service.dart';
import '../domain/entities/fee_generation_result.dart';
import '../domain/entities/payment_record.dart';
import '../domain/entities/receipt_data.dart';
import '../domain/repositories/fee_repository.dart';

/// Drives the fee flows (generation, collection, reversal) and exposes
/// loading state + errors to the UI. The signed-in user is attached to every
/// payment and reversal for the audit trail.
class FeeService extends ChangeNotifier {
  FeeService({
    required FeeRepository repository,
    required AuthService authService,
  })  : _repository = repository,
        _authService = authService;

  final FeeRepository _repository;
  final AuthService _authService;

  /// Read operations (search, reports) go through the repository directly.
  FeeRepository get repository => _repository;

  bool busy = false;
  bool running = false;
  int processed = 0;
  int total = 0;
  String? errorMessage;
  FeeGenerationResult? lastGeneration;
  ReceiptData? lastReceipt;

  int? get _userId => _authService.currentUser?.id;
  String? get _userName => _authService.currentUser?.displayName;

  /// Generates monthly fee records for all active students. Progress is
  /// surfaced through [processed]/[total] and [running].
  Future<FeeGenerationResult> generate({
    required int year,
    required int month,
  }) async {
    running = true;
    busy = true;
    errorMessage = null;
    processed = 0;
    total = 0;
    lastGeneration = null;
    notifyListeners();
    try {
      final result = await _repository.generateMonthlyFees(
        year: year,
        month: month,
        onProgress: (p, t) {
          processed = p;
          total = t;
          notifyListeners();
        },
      );
      lastGeneration = result;
      return result;
    } catch (_) {
      errorMessage =
          'Fee generation failed. The database was left unchanged.';
      rethrow;
    } finally {
      running = false;
      busy = false;
      notifyListeners();
    }
  }

  Future<PaymentRecord> collectPayment({
    required int feeRecordId,
    required int studentId,
    required double amount,
    required DateTime paymentDate,
    String? receiptNumber,
    String? note,
  }) async {
    busy = true;
    errorMessage = null;
    notifyListeners();
    try {
      final payment = await _repository.recordPayment(
        feeRecordId: feeRecordId,
        studentId: studentId,
        amount: amount,
        paymentDate: paymentDate,
        receiptNumber: receiptNumber,
        note: note,
        createdByUserId: _userId,
        createdByName: _userName,
      );
      lastReceipt = await _repository.receiptData(payment.id);
      return payment;
    } catch (e) {
      errorMessage = _messageFor(e);
      rethrow;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<PaymentRecord> reversePayment({
    required int paymentId,
    String? reason,
  }) async {
    busy = true;
    errorMessage = null;
    notifyListeners();
    try {
      return await _repository.reversePayment(
        paymentId: paymentId,
        byUserId: _userId,
        byName: _userName,
        reason: reason,
      );
    } catch (e) {
      errorMessage = _messageFor(e);
      rethrow;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<dynamic> adjustFeeRecord({
    required int feeRecordId,
    double? discount,
    double? fine,
  }) async {
    busy = true;
    errorMessage = null;
    notifyListeners();
    try {
      return await _repository.adjustFeeRecord(
        feeRecordId: feeRecordId,
        discount: discount,
        fine: fine,
      );
    } catch (e) {
      errorMessage = _messageFor(e);
      rethrow;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  static String _messageFor(Object error) {
    if (error is OverpaymentException) {
      return 'That payment is more than the remaining balance.';
    }
    if (error is DuplicateReceiptException) {
      return 'That receipt number is already in use.';
    }
    if (error is ArgumentError) {
      return error.message?.toString() ?? 'Invalid value entered.';
    }
    return 'The operation could not be completed.';
  }
}
