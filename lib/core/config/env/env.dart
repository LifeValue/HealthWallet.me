import 'package:envied/envied.dart';

part 'env.g.dart';

@Envied(path: '.env')
abstract class Env {
  @EnviedField(varName: 'HUGGING_FACE_TOKEN', defaultValue: '', obfuscate: true)
  static String huggingFaceToken = _Env.huggingFaceToken;

  @EnviedField(varName: 'GOOGLE_WALLET_ISSUER_ID', defaultValue: '', obfuscate: true)
  static String googleWalletIssuerId = _Env.googleWalletIssuerId;

  @EnviedField(varName: 'APPLE_PASS_TYPE_ID', defaultValue: '', obfuscate: true)
  static String applePassTypeId = _Env.applePassTypeId;

  @EnviedField(varName: 'APPLE_TEAM_ID', defaultValue: '', obfuscate: true)
  static String appleTeamId = _Env.appleTeamId;
}
