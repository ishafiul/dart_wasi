import 'dart:io';

Uri guestFixtureUri(String name) {
  final current = Directory.current.uri;
  final packageRoot = current.path.endsWith('/packages/dart2wasi/')
      ? current
      : current.resolve('packages/dart2wasi/');
  return packageRoot.resolve('test/fixtures/$name.dart');
}
