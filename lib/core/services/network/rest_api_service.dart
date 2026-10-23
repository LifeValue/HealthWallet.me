import 'package:dio/dio.dart';
import 'package:health_wallet/core/config/constants/app_constants.dart';
import 'package:health_wallet/core/config/exceptions/remote_exception.dart';
import 'package:health_wallet/core/services/network/interceptors/access_token_interceptor.dart';
import 'package:injectable/injectable.dart';
import 'package:health_wallet/core/l10n/arb/app_localizations.dart';

enum RestMethod { get, post, put, patch, delete }

abstract class RestApiService {
  Future<T> request<T>({
    required RestMethod method,
    required String path,
    Map<String, dynamic>? queryParameters,
    dynamic body,
    Map<String, dynamic>? headers,
    String? contentType,
    ResponseType? responseType,
    T Function(Map<String, dynamic>)? decoder,
    dynamic Function(dynamic rawResponse)? onExtract,
    String? baseUrlOverride,
    Duration? sendTimeout,
    Duration? receiveTimeout,
  });
}

@LazySingleton(as: RestApiService)
class RestApiServiceImpl implements RestApiService {
  final _dio = Dio(BaseOptions(
    baseUrl: AppConstants.baseUrl,
    connectTimeout: AppConstants.connectTimeout,
    sendTimeout: AppConstants.sendTimeout,
    receiveTimeout: AppConstants.receiveTimeout,
  ))
    ..interceptors.addAll([
      LogInterceptor(
        request: true,
        responseBody: true,
        requestBody: true,
        requestHeader: true,
      ),
      AccessTokenInterceptor(),
    ]);

  @override
  Future<T> request<T>({
    required RestMethod method,
    required String path,
    Map<String, dynamic>? queryParameters,
    // ignore: avoid-dynamic
    dynamic body,
    Map<String, dynamic>? headers,
    String? contentType,
    ResponseType? responseType,
    T Function(Map<String, dynamic>)? decoder,
    dynamic Function(dynamic rawResponse)? onExtract,
    String? baseUrlOverride,
    Duration? sendTimeout,
    Duration? receiveTimeout,
  }) async {
    try {
      final response = await _requestByMethod(
        method: method,
        path: path,
        queryParameters: queryParameters,
        body: body,
        options: Options(
          headers: headers,
          contentType: contentType,
          responseType: responseType,
          sendTimeout: sendTimeout ?? AppConstants.sendTimeout,
          receiveTimeout: receiveTimeout ?? AppConstants.receiveTimeout,
        ),
      );

      dynamic data =
          (onExtract != null) ? onExtract(response.data) : response.data;
      return (decoder != null) ? decoder(data) : data;
    } catch (exception) {
      throw mapDioException(exception);
    }
  }

  Future<Response> _requestByMethod({
    required RestMethod method,
    required String path,
    Map<String, dynamic>? queryParameters,
    // ignore: avoid-dynamic
    dynamic body,
    Options? options,
  }) {
    switch (method) {
      case RestMethod.get:
        return _dio.get(
          path,
          data: body,
          queryParameters: queryParameters,
          options: options,
        );
      case RestMethod.post:
        return _dio.post(
          path,
          data: body,
          queryParameters: queryParameters,
          options: options,
        );
      case RestMethod.patch:
        return _dio.patch(
          path,
          data: body,
          queryParameters: queryParameters,
          options: options,
        );
      case RestMethod.put:
        return _dio.put(
          path,
          data: body,
          queryParameters: queryParameters,
          options: options,
        );
      case RestMethod.delete:
        return _dio.delete(
          path,
          data: body,
          queryParameters: queryParameters,
          options: options,
        );
    }
  }

  RemoteException mapDioException(Object? exception, [AppLocalizations? l10n]) {
    final String remoteGenericMessage =
        l10n?.serverError ?? 'Something went wrong on the server';
    final String remoteTimeoutMessage = l10n?.serverTimeout ?? 'Server timeout';
    final String remoteConnectionMessage =
        l10n?.connectionError ?? 'Connection error';

    if (exception is DioException) {
      switch (exception.type) {
        case DioExceptionType.cancel:
          return const RemoteException(kind: RemoteExceptionKind.cancel);
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.receiveTimeout:
        case DioExceptionType.sendTimeout:
          return RemoteException(
              kind: RemoteExceptionKind.timeout,
              rootException: exception,
              message: remoteTimeoutMessage);
        case DioExceptionType.badResponse:
          final httpErrorCode = exception.response?.statusCode ?? -1;

          String message = remoteGenericMessage;

          /// server-defined error
          if (exception.response?.data != null) {
            message = exception.response!.data['message'] ??
                exception.response!.data['error'] ??
                remoteGenericMessage;
          }

          return RemoteException(
            kind: RemoteExceptionKind.server,
            httpErrorCode: httpErrorCode,
            rootException: exception,
            message: message,
          );
        case DioExceptionType.connectionError:
        case DioExceptionType.badCertificate:
          return RemoteException(
              kind: RemoteExceptionKind.network,
              rootException: exception,
              message: remoteConnectionMessage);
        case DioExceptionType.unknown:
          return RemoteException(
              kind: RemoteExceptionKind.unknown, rootException: exception);
      }
    }

    return RemoteException(
        kind: RemoteExceptionKind.unknown,
        rootException: exception,
        message: remoteGenericMessage);
  }
}
