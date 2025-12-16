/// Result of receiving/importing a SMART Health Card
class SHCReceiveResult {
  final bool success;
  final String? errorMessage;
  final int? importedResourceCount;
  final String? issuerId;

  SHCReceiveResult({
    required this.success,
    this.errorMessage,
    this.importedResourceCount,
    this.issuerId,
  });

  factory SHCReceiveResult.success({
    required int importedResourceCount,
    String? issuerId,
  }) {
    return SHCReceiveResult(
      success: true,
      importedResourceCount: importedResourceCount,
      issuerId: issuerId,
    );
  }

  factory SHCReceiveResult.failure(String errorMessage) {
    return SHCReceiveResult(
      success: false,
      errorMessage: errorMessage,
    );
  }
}


