import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_static/shelf_static.dart';

void main() async {
  final handler = const Pipeline().addMiddleware(logRequests()).addHandler(
        createStaticHandler('example/web', defaultDocument: 'index.html'),
      );

  final server = await io.serve(handler, InternetAddress.loopbackIPv4, 8080);
  print('Serving at http://${server.address.host}:${server.port}');
}
