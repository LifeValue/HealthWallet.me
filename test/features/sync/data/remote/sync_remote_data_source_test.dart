import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/features/sync/data/dto/fhir_resource_dto.dart';
import 'package:health_wallet/features/sync/data/remote/sync_remote_data_source.dart';

/// Answers every request with [body] as JSON and records what was sent.
class FakeHttpAdapter implements HttpClientAdapter {
  FakeHttpAdapter(this.body);

  Object? body;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return ResponseBody.fromString(
      jsonEncode(body),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late Dio dio;
  late FakeHttpAdapter adapter;
  late SyncRemoteDataSource dataSource;

  setUp(() {
    adapter = FakeHttpAdapter({'data': <Object>[]});
    dio = Dio()..httpClientAdapter = adapter;
    dataSource = SyncRemoteDataSource(dio);
  });

  group('SyncRemoteDataSource', () {
    test('updateBaseUrl and updateAuthorizationToken configure Dio', () {
      dataSource
        ..updateBaseUrl('https://fasten.local/')
        ..updateAuthorizationToken('tok');
      expect(dio.options.baseUrl, 'https://fasten.local/');
      expect(dio.options.headers['Authorization'], 'Bearer tok');
    });

    test('getResources requests the endpoint with the bearer token', () async {
      dataSource
        ..updateBaseUrl('https://fasten.local/')
        ..updateAuthorizationToken('tok');
      await dataSource.getResources(endpoint: 'api/secure/resource/fhir');
      final request = adapter.requests.single;
      expect(request.method, 'GET');
      expect(
        request.uri.toString(),
        'https://fasten.local/api/secure/resource/fhir',
      );
      expect(request.headers['Authorization'], 'Bearer tok');
    });

    test('getResources parses each entry of "data"', () async {
      adapter.body = {
        'success': true,
        'data': [
          {
            'source_id': 's1',
            'source_resource_type': 'Patient',
            'source_resource_id': 'p1',
            'sort_date': '2024-01-01',
            'resource_raw': {'resourceType': 'Patient'},
          },
          'not an object',
          42,
          {'source_resource_id': 'p2'},
        ],
      };
      final resources = await dataSource.getResources(
        endpoint: 'https://x/fhir',
      );
      expect(resources, [
        FhirResourceDto(
          sourceId: 's1',
          resourceType: 'Patient',
          resourceId: 'p1',
          date: DateTime(2024),
          resourceRaw: const {'resourceType': 'Patient'},
        ),
        const FhirResourceDto(resourceId: 'p2'),
      ]);
    });

    test('getResources returns an empty list for empty data', () async {
      expect(await dataSource.getResources(endpoint: 'https://x/'), isEmpty);
    });

    test('getResources throws when "data" is missing', () async {
      adapter.body = {'success': false};
      await expectLater(
        dataSource.getResources(endpoint: 'https://x/'),
        throwsA(isA<TypeError>()),
      );
    });
  });
}
