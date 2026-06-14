class DebugExecutionLog {
  const DebugExecutionLog({
    required this.action,
    required this.status,
    required this.summary,
    required this.updatedAt,
    this.executionPath,
    this.reason,
    this.shouldNotify,
    this.checkpointId,
    this.details = const <String, Object?>{},
  });

  final String action;
  final String status;
  final String summary;
  final String updatedAt;
  final String? executionPath;
  final String? reason;
  final bool? shouldNotify;
  final String? checkpointId;
  final Map<String, Object?> details;
}
