import 'migration_lifecycle.dart';

class DomainFailureCategory {
  final String failureCode;
  final String categoryName;
  final String userMessage;
  final FailureSeverity severity;
  final bool rollbackTrigger;

  const DomainFailureCategory({
    required this.failureCode,
    required this.categoryName,
    required this.userMessage,
    required this.severity,
    required this.rollbackTrigger,
  });

  Map<String, dynamic> toMap() {
    return {
      'failureCode': failureCode,
      'categoryName': categoryName,
      'userMessage': userMessage,
      'severity': severity.wireValue,
      'rollbackTrigger': rollbackTrigger,
    };
  }

  factory DomainFailureCategory.fromMap(Map<String, dynamic> map) {
    return DomainFailureCategory(
      failureCode: map['failureCode'] as String,
      categoryName: map['categoryName'] as String,
      userMessage: map['userMessage'] as String,
      severity: FailureSeverityX.fromWireValue(map['severity'] as String),
      rollbackTrigger: map['rollbackTrigger'] as bool? ?? false,
    );
  }
}
