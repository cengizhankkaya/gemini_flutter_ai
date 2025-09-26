import 'dart:math';

typedef AsyncAction<T> = Future<T> Function();

class RetryPolicy {
  const RetryPolicy();

  Future<T> executeWithBackoff<T>(
    AsyncAction<T> action, {
    int maxAttempts = 5,
    Duration baseDelay = const Duration(milliseconds: 400),
  }) async {
    final Random random = Random.secure();
    int attempt = 0;

    while (true) {
      try {
        return await action();
      } catch (error) {
        attempt++;
        final String err = error.toString().toLowerCase();
        final bool isTransient = err.contains('503') ||
            err.contains('unavailable') ||
            err.contains('overloaded') ||
            err.contains('rate limit') ||
            err.contains('timeout') ||
            err.contains('service temporarily unavailable');

        if (!isTransient || attempt >= maxAttempts) {
          rethrow;
        }

        final int jitterMs = random.nextInt(250);
        final Duration delay = baseDelay * pow(2, attempt) + Duration(milliseconds: jitterMs);
        await Future.delayed(delay);
      }
    }
  }
}


