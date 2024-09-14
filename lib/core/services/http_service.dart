import 'dart:convert';

import '../entities/http_response_entity.dart';
import 'package:http/http.dart' as http;

abstract class IHttpService {
  Future<HttpResponseEntity> get<T>(String url);
}

final class HttpService implements IHttpService {
  final http.Client client;

  const HttpService(this.client);

  @override
  Future<HttpResponseEntity> get<T>(String url) async {
    final http.Response data = await client.get(Uri.parse(url));
    return HttpResponseEntity<T>(
      statusCode: data.statusCode,
      data: jsonDecode(data.body),
    );
  }
}
