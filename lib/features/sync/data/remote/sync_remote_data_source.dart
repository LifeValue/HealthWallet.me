import 'package:dio/dio.dart';
import 'package:health_wallet/features/sync/data/dto/fhir_resource_dto.dart';
import 'package:injectable/injectable.dart';

@injectable
class SyncRemoteDataSource {
  final Dio _dio;

  SyncRemoteDataSource(this._dio);

  void updateBaseUrl(String baseUrl) {
    _dio.options.baseUrl = baseUrl;
  }

  void updateAuthorizationToken(String token) {
    _dio.options.headers['Authorization'] = 'Bearer $token';
  }

  Future<List<FhirResourceDto>> getResources({required String endpoint}) async {
    final response = await _dio.get(endpoint);

    final responseData = response.data;

    return (responseData['data'] as List)
        .whereType<Map<String, dynamic>>()
        .map(FhirResourceDto.fromJson)
        .toList();
  }
}
