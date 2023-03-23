import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:random_string/random_string.dart';
import 'package:universal_html/html.dart' as html;
import 'package:webview_flutter/webview_flutter.dart';

import 'model/config.dart';
import 'model/token.dart';
import 'request/authorization_request.dart';

class RequestTokenWeb {
  final StreamController<Map<String, String>> _onCodeListener = StreamController();
  final Config _config;
  late AuthorizationRequest _authorizationRequest;
  html.WindowBase? _popupWin;

  Stream<Map<String, String>>? _onCodeStream;

  RequestTokenWeb(Config config) : _config = config {
    _authorizationRequest = AuthorizationRequest(config);
  }

  Future<Token> requestToken() async {
    late Token token;
    String urlParams = _constructUrlParams();
    final state = randomAlpha(16);
    if (_config.context != null) {
      urlParams += '&state=$state' ;
      String initialURL = ('${_authorizationRequest.url}?$urlParams').replaceAll(' ', '%20');
      _webAuth(initialURL);
    } else {
      throw Exception('Context is null. Please call setContext(context).');
    }

    var jsonToken = await _onCode.first;
    if (jsonToken['state'] != state) {
      throw Exception('state field in response is not same in auth url param');
    }
    token = Token.fromJson(jsonToken);
    return token;
  }

  _webAuth(String initialURL) {
    html.window.onMessage.listen((event) {
      var tokenParam = 'access_token';
      var stateParam = 'state';
      final urlData = event.data.toString();
      if (urlData.contains(tokenParam) && urlData.contains(stateParam)) {
        _getUrlData(event.data.toString());
      }
      if (event.data.toString().contains('error')) {
        _closeWebWindow();
        throw Exception('Access denied or authentication canceled.');
      }
    });
    _popupWin = html.window.open(initialURL, 'Microsoft Auth', 'width=800, height=900, scrollbars=yes');
  }

  _getUrlData(String _url) {
    var url = _url.replaceFirst('#', '?');
    Uri uri = Uri.parse(url);

    if (uri.queryParameters['error'] != null) {
      _closeWebWindow();
      _onCodeListener.addError(Exception('Access denied or authentication canceled.'));
    }

    var token = uri.queryParameters;
    _onCodeListener.add(token);

    _closeWebWindow();
  }

  _closeWebWindow() {
    if (_popupWin != null) {
      _popupWin?.close();
      _popupWin = null;
    }
  }

  Future<void> clearCookies() async {
    await CookieManager().clearCookies();
  }

  Stream<Map<String, String>> get _onCode => _onCodeStream ??= _onCodeListener.stream.asBroadcastStream();

  String _constructUrlParams() => _mapToQueryParams(_authorizationRequest.parameters);

  String _mapToQueryParams(Map<String, String> params) {
    final queryParams = <String>[];
    params.forEach((String key, String value) => queryParams.add('$key=$value'));
    return queryParams.join('&');
  }

  void setContext(BuildContext context) {
    _config.context = context;
  }
}
