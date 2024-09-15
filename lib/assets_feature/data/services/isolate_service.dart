import 'dart:isolate';

Future<T> runIsolate<T>(Future<T> Function() callback) async {
  return await Isolate.run<T>(() async {
    return await callback();
  });
}
