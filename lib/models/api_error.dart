/// Rescue Platform API hibamodell és kivételek a rescue-platform-openapi-v02 specifikáció alapján.
class ApiException implements Exception {
  final int statusCode;
  final String code;
  final String message;
  final String? requestId;

  const ApiException({
    required this.statusCode,
    required this.code,
    required this.message,
    this.requestId,
  });

  factory ApiException.fromJson(int statusCode, Map<String, dynamic> json) {
    return ApiException(
      statusCode: statusCode,
      code: json['code']?.toString() ?? 'UNKNOWN_ERROR',
      message: json['message']?.toString() ?? 'Ismeretlen hiba történt.',
      requestId: json['request_id']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'code': code,
    'message': message,
    if (requestId != null) 'request_id': requestId,
  };

  @override
  String toString() => 'ApiException($statusCode, code: $code, message: $message, requestId: $requestId)';
}

class UnauthorizedException extends ApiException {
  const UnauthorizedException({
    String code = 'UNAUTHENTICATED',
    String message = 'Jelentkezz be újra.',
    String? requestId,
  }) : super(statusCode: 401, code: code, message: message, requestId: requestId);
}

class ForbiddenException extends ApiException {
  const ForbiddenException({
    String code = 'MEMBERSHIP_NOT_APPROVED',
    String message = 'Jóváhagyott tagság szükséges.',
    String? requestId,
  }) : super(statusCode: 403, code: code, message: message, requestId: requestId);
}

class NotFoundException extends ApiException {
  const NotFoundException({
    String code = 'NOT_FOUND',
    String message = 'Az erőforrás nem található.',
    String? requestId,
  }) : super(statusCode: 404, code: code, message: message, requestId: requestId);
}

class ConflictException extends ApiException {
  const ConflictException({
    required String code,
    required String message,
    String? requestId,
  }) : super(statusCode: 409, code: code, message: message, requestId: requestId);
}

class PreconditionFailedException extends ApiException {
  const PreconditionFailedException({
    String code = 'VERSION_CONFLICT',
    String message = 'Az adat megváltozott.',
    String? requestId,
  }) : super(statusCode: 412, code: code, message: message, requestId: requestId);
}

class UnprocessableEntityException extends ApiException {
  const UnprocessableEntityException({
    String code = 'INVALID_DEVICE_PROVIDER',
    String message = 'A platform és a provider nem kompatibilis.',
    String? requestId,
  }) : super(statusCode: 422, code: code, message: message, requestId: requestId);
}
