import 'package:logger/logger.dart';

final logger = AppLogger();

class AppLogger {
  final logger = Logger(
    printer: PrefixPrinter(
      PrettyPrinter(
        methodCount: 0,
        errorMethodCount: 3,
        lineLength: 80,
        colors: false,
        printEmojis: false,
        dateTimeFormat: DateTimeFormat.none,
      ),
    ),
  );

  void v(dynamic message, [dynamic error, StackTrace? stackTrace]) =>
      logger.t(message, error: error, stackTrace: stackTrace);

  void d(dynamic message, [dynamic error, StackTrace? stackTrace]) =>
      logger.d(message, error: error, stackTrace: stackTrace);

  void i(dynamic message, [dynamic error, StackTrace? stackTrace]) =>
      logger.i(message, error: error, stackTrace: stackTrace);

  void fetchedRequestResponse(
    String objectName,
    int statusCode, [
    dynamic body,
  ]) =>
      logger.i(
        'Fetched $objectName with status code:'
        ' $statusCode and $objectName: ${body ?? 'no body'}',
      );

  void postRequestResponse(
    String objectName,
    int statusCode, [
    dynamic body,
  ]) =>
      logger.i(
        'Created $objectName with status code:'
        ' $statusCode and $objectName: ${body ?? 'no body'}',
      );

  void w(dynamic message, [dynamic error, StackTrace? stackTrace]) =>
      logger.w(message, error: error, stackTrace: stackTrace);

  void e(dynamic message, [dynamic error, StackTrace? stackTrace]) =>
      logger.e(message, error: error, stackTrace: stackTrace);

  void f(dynamic message, [dynamic error, StackTrace? stackTrace]) =>
      logger.t(message, error: error, stackTrace: stackTrace);
}
