class Failure {
  final String message;
  final FailureType type;

  const Failure({required this.message, this.type = FailureType.unknown});
}

enum FailureType {
  authentication,
  rateLimited,
  unavailable,
  network,
  timeout,
  invalidRequest,
  unknown,
}


