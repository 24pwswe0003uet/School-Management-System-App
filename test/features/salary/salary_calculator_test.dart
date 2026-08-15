import 'package:flutter_test/flutter_test.dart';
import 'package:school_office_management/features/salary/application/salary_calculator.dart';

void main() {
  group('SalaryCalculator.netPayable', () {
    test('base minus advance minus deduction plus adjustment', () {
      final net = SalaryCalculator.netPayable(
        base: 30000,
        advance: 2000,
        deduction: 1500,
        otherAdjustment: 500,
      );
      expect(net, 27000);
    });

    test('plain base salary with no adjustments', () {
      final net = SalaryCalculator.netPayable(
        base: 25000,
        advance: 0,
        deduction: 0,
        otherAdjustment: 0,
      );
      expect(net, 25000);
    });

    test('advance alone reduces the net', () {
      final net = SalaryCalculator.netPayable(
        base: 30000,
        advance: 30000,
        deduction: 0,
        otherAdjustment: 0,
      );
      expect(net, 0);
    });

    test('a negative result is clamped to zero', () {
      final net = SalaryCalculator.netPayable(
        base: 10000,
        advance: 8000,
        deduction: 4000,
        otherAdjustment: 0,
      );
      expect(net, 0);
    });

    test('negative adjustment lowers the net, positive raises it', () {
      final lower = SalaryCalculator.netPayable(
        base: 30000,
        advance: 0,
        deduction: 0,
        otherAdjustment: -1000,
      );
      final higher = SalaryCalculator.netPayable(
        base: 30000,
        advance: 0,
        deduction: 0,
        otherAdjustment: 1000,
      );
      expect(lower, 29000);
      expect(higher, 31000);
    });

    test('fractional components are rounded to two decimals', () {
      final net = SalaryCalculator.netPayable(
        base: 30000.001,
        advance: 0.005,
        deduction: 0,
        otherAdjustment: 0,
      );
      expect(net, 30000.0);
    });
  });

  group('SalaryCalculator.raw and isClamped', () {
    test('raw is unclamped', () {
      final raw = SalaryCalculator.raw(
        base: 10000,
        advance: 8000,
        deduction: 4000,
        otherAdjustment: 0,
      );
      expect(raw, -2000);
    });

    test('isClamped is true only when the raw result is negative', () {
      expect(
        SalaryCalculator.isClamped(
          base: 10000,
          advance: 8000,
          deduction: 4000,
          otherAdjustment: 0,
        ),
        isTrue,
      );
      expect(
        SalaryCalculator.isClamped(
          base: 10000,
          advance: 0,
          deduction: 0,
          otherAdjustment: 0,
        ),
        isFalse,
      );
      expect(
        SalaryCalculator.isClamped(
          base: 10000,
          advance: 10000,
          deduction: 0,
          otherAdjustment: 0,
        ),
        isFalse,
      );
    });
  });

  group('SalaryCalculator.round', () {
    test('rounds to two decimals', () {
      expect(SalaryCalculator.round(1234.567), 1234.57);
      expect(SalaryCalculator.round(12.5), 12.5);
      expect(SalaryCalculator.round(0.004), 0.0);
    });
  });
}
