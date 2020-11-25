import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:firebase_core/firebase_core.dart';

bool initialized = false;

final defaults = <String, dynamic>{'welcome': 'default welcome'};

Future<RemoteConfig> initRemoteConfig() async {
  await Firebase.initializeApp();
  final RemoteConfig remoteConfig = await RemoteConfig.instance;
  // Enable developer mode to relax fetch throttling
  remoteConfig.setConfigSettings(RemoteConfigSettings(debugMode: true));
  remoteConfig.setDefaults(<String, dynamic>{
    'welcome': 'default welcome',
    'hello': 'default hello',
  });
  initialized = true;
  return remoteConfig;
}

Future<void> testRemoteConfig() async {
  print('testing rem conf..');
  print('getting rem conf..');
  RemoteConfig remoteConfig = await initRemoteConfig();
  print('rem conf init succ');
  await remoteConfig.fetch(expiration: const Duration(hours: 5));
  print('rem conf fetch succ');
  await remoteConfig.activateFetched();
  print('rem conf activate succ');
  print('welcome message: ' + remoteConfig.getString('welcome'));
}
