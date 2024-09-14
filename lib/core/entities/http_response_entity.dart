class HttpResponseEntity<T> {
  final int statusCode;
  final T data;

  const HttpResponseEntity({
    required this.statusCode,
    required this.data,
  });
}
