part of leancloud_storage;

class _LCHttpClient {
  String appId;

  String appKey;

  String server;

  String sdkVersion;

  String apiVersion;

  _LCAppRouter _appRouter;

  Dio _dio;

  LogInterceptor _logInterceptor;

  DioCacheManager _cacheManager;

  _LCHttpClient(this.appId, this.appKey, this.server, this.sdkVersion,
      this.apiVersion, LCQueryCache queryCache) {
    _appRouter = new _LCAppRouter(appId, server);
    BaseOptions options = new BaseOptions(headers: {
      'X-LC-Id': appId,
      'User-Agent': 'LeanCloud-Flutter-SDK/$sdkVersion'
    }, contentType: 'application/json');
    _dio = new Dio(options);
    if (queryCache != null) {
      _cacheManager = new DioCacheManager(CacheConfig());
      _dio.interceptors.add(_cacheManager.interceptor);
    }
  }

  void enableLog() {
    if (_logInterceptor == null) {
      _logInterceptor =
          new LogInterceptor(requestBody: true, responseBody: true);
    }
    _dio.interceptors.add(_logInterceptor);
  }

  Future get(String path,
      {Map<String, dynamic> headers,
      Map<String, dynamic> queryParams,
      CachePolicy cachePolicy}) async {
    await _refreshServer();
    Options options = buildCacheOptions(Duration(days: 7));
    if (cachePolicy == CachePolicy.onlyNetwork) {
      options.extra[DIO_CACHE_KEY_TRY_CACHE] = false;
      options.extra[DIO_CACHE_KEY_FORCE_REFRESH] = true;
    }
    options.headers = _generateHeaders(headers);
    try {
      Response response =
          await _dio.get(path, options: options, queryParameters: queryParams);
      return response.data;
    } on DioError catch (e) {
      _handleError(e);
    }
  }

  Future post(String path,
      {Map<String, dynamic> headers,
      dynamic data,
      Map<String, dynamic> queryParams}) async {
    await _refreshServer();
    Options options = _toOptions(headers);
    try {
      Response response = await _dio.post(path,
          options: options, data: data, queryParameters: queryParams);
      return response.data;
    } on DioError catch (e) {
      _handleError(e);
    }
  }

  Future put(String path,
      {Map<String, dynamic> headers,
      dynamic data,
      Map<String, dynamic> queryParams}) async {
    await _refreshServer();
    Options options = _toOptions(headers);
    try {
      Response response = await _dio.put(path,
          options: options, data: data, queryParameters: queryParams);
      return response.data;
    } on DioError catch (e) {
      _handleError(e);
    }
  }

  Future delete(String path,
      {Map<String, dynamic> headers,
      dynamic data,
      Map<String, dynamic> queryParams}) async {
    await _refreshServer();
    Options options = _toOptions(headers);
    try {
      Response response = await _dio.delete(path,
          options: options, data: data, queryParameters: queryParams);
      return response.data;
    } on DioError catch (e) {
      _handleError(e);
    }
  }

  Future<bool> clearAllCache() {
    if (_cacheManager != null) {
      return _cacheManager.clearAll();
    }
    return Future.value(true);
  }

  Future _refreshServer() async {
    // 以防 server 过期
    String apiServer = await _appRouter.getApiServer();
    _dio.options.baseUrl = '$apiServer/$apiVersion/';
  }

  Options _toOptions(Map<String, dynamic> additionalHeaders) {
    Map<String, dynamic> headers = _generateHeaders(additionalHeaders);
    return new Options(headers: headers);
  }

  Map<String, dynamic> _generateHeaders(
      Map<String, dynamic> additionalHeaders) {
    Map<String, dynamic> headers = new Map<String, dynamic>();
    int timestamp = DateTime.now().millisecondsSinceEpoch;
    Uint8List data = Utf8Encoder().convert('$timestamp$appKey');
    Digest digest = md5.convert(data);
    String sign = hex.encode(digest.bytes);
    headers['X-LC-Sign'] = '$sign,$timestamp';
    LCUser currentUser = LCUser._currentUser;
    if (currentUser != null) {
      headers['X-LC-Session'] = currentUser.sessionToken;
    }
    if (additionalHeaders != null) {
      additionalHeaders.forEach((key, value) {
        headers[key] = value;
      });
    }
    return headers;
  }

  void _handleError(DioError e) {
    if (e.type != DioErrorType.RESPONSE) {
      throw e;
    }
    Response response = e.response;
    int code = response.statusCode ~/ 100;
    if (code == 4) {
      int code = response.data['code'];
      String message = response.data['error'];
      throw new LCException(code, message);
    }
    throw new LCException(response.statusCode, response.statusMessage);
  }
}
