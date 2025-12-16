import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:health_wallet/core/data/local/app_database.dart';
import 'package:health_wallet/core/services/biometric_auth_service.dart';

// import 'package:health_wallet/features/user/data/data_source/local/user_local_data_source.dart';
import 'package:health_wallet/features/user/data/data_source/remote/user_remote_data_source.dart';
import 'package:injectable/injectable.dart';
import 'package:shared_preferences/shared_preferences.dart';

@module
abstract class RegisterModule {
  @preResolve
  Future<SharedPreferences> get prefs => SharedPreferences.getInstance();

  @lazySingleton
  Dio get dio => Dio();

  @lazySingleton
  AppDatabase get appDatabase => AppDatabase();

  @lazySingleton
  UserRemoteDataSource get userRemoteDataSource => MockUserRemoteDataSource();

  // UserLocalDataSource is automatically registered via @Injectable annotation

  @lazySingleton
  BiometricAuthService get biometricAuthService => BiometricAuthService();

  @lazySingleton
  FlutterSecureStorage get flutterSecureStorage => const FlutterSecureStorage();
}
