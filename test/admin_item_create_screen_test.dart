import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:erpnext_stock_mobile/src/core/localization/app_localizations.dart';
import 'package:erpnext_stock_mobile/src/core/session/session.dart';
import 'package:erpnext_stock_mobile/src/features/admin/presentation/admin_item_create_screen.dart';
import 'package:erpnext_stock_mobile/src/features/shared/models/app_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    AppSession.instance.token = 'token';
    AppSession.instance.profile = const SessionProfile(
      role: UserRole.admin,
      displayName: 'Admin',
      legalName: 'Admin',
      ref: 'ADMIN-001',
      phone: '',
      avatarUrl: '',
    );
  });

  tearDown(() {
    AppSession.instance.token = null;
    AppSession.instance.profile = null;
  });

  testWidgets('duplicate item create shows temporary top notice',
      (tester) async {
    final seenRequests = <String>[];
    final client = _AdminItemCreateHttpClient(seenRequests);

    await HttpOverrides.runZoned(() async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true),
          locale: const Locale('uz'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: const AdminItemCreateScreen(),
        ),
      );

      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).at(0), 'test');
      await tester.enterText(find.byType(TextField).at(1), 'test');
      await tester.tap(find.text('Item yaratish'));
      await tester.pumpAndSettle();

      expect(
        seenRequests,
        contains('GET /v1/mobile/admin/items?q=test&limit=5'),
      );
      expect(
        seenRequests
            .where((request) => request == 'POST /v1/mobile/admin/items'),
        isEmpty,
      );
      expect(find.text('Item allaqachon yaratilgan'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 2200));
      await tester.pumpAndSettle();

      expect(find.text('Item allaqachon yaratilgan'), findsNothing);
      expect(tester.takeException(), isNull);
    }, createHttpClient: (_) => client);
  });
}

class _AdminItemCreateHttpClient implements HttpClient {
  _AdminItemCreateHttpClient(this.seenRequests);

  final List<String> seenRequests;

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async {
    final key =
        '$method ${url.path}${url.query.isEmpty ? '' : '?${url.query}'}';
    seenRequests.add(key);

    final Object body = switch (key) {
      'GET /v1/mobile/admin/settings' => {
          'default_uom': 'Kg',
        },
      'GET /v1/mobile/admin/item-groups' => const ['All Item Groups'],
      'GET /v1/mobile/admin/items?q=test&limit=5' => const [
          {
            'code': 'test',
            'name': 'test',
            'uom': 'Kg',
            'warehouse': 'Stores - A',
            'item_group': 'All Item Groups',
          },
        ],
      'POST /v1/mobile/admin/items' => {
          'error': 'admin item create failed',
        },
      _ => throw StateError('Unhandled request: $key'),
    };

    return _FakeHttpClientRequest(
      response: _FakeHttpClientResponse(
        body: jsonEncode(body),
        statusCode: key == 'POST /v1/mobile/admin/items'
            ? HttpStatus.internalServerError
            : HttpStatus.ok,
      ),
    );
  }

  @override
  Future<HttpClientRequest> getUrl(Uri url) => openUrl('GET', url);

  @override
  Future<HttpClientRequest> postUrl(Uri url) => openUrl('POST', url);

  @override
  void close({bool force = false}) {}

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeHttpClientRequest implements HttpClientRequest {
  _FakeHttpClientRequest({required this.response});

  final _FakeHttpClientResponse response;
  final _FakeHttpHeaders _headers = _FakeHttpHeaders();
  final Completer<HttpClientResponse> _done = Completer<HttpClientResponse>();

  @override
  HttpHeaders get headers => _headers;

  @override
  bool persistentConnection = true;

  @override
  bool followRedirects = true;

  @override
  int maxRedirects = 5;

  @override
  int contentLength = -1;

  @override
  bool bufferOutput = true;

  @override
  List<Cookie> get cookies => const <Cookie>[];

  @override
  Future<HttpClientResponse> get done => _done.future;

  @override
  void add(List<int> data) {}

  @override
  Future<void> addStream(Stream<List<int>> stream) async {}

  @override
  void write(Object? object) {}

  @override
  void writeAll(Iterable<Object?> objects, [String separator = '']) {}

  @override
  void writeCharCode(int charCode) {}

  @override
  void writeln([Object? object = '']) {}

  @override
  Future<void> flush() async {}

  @override
  Future<HttpClientResponse> close() {
    if (!_done.isCompleted) {
      _done.complete(response);
    }
    return _done.future;
  }

  @override
  void abort([Object? exception, StackTrace? stackTrace]) {
    if (!_done.isCompleted) {
      _done.completeError(
        exception ?? const HttpException('aborted'),
        stackTrace ?? StackTrace.empty,
      );
    }
  }

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeHttpClientResponse extends StreamView<List<int>>
    implements HttpClientResponse {
  _FakeHttpClientResponse({
    required String body,
    required this.statusCode,
  })  : _bytes = utf8.encode(body),
        _headers = _FakeHttpHeaders(),
        super(Stream<List<int>>.value(utf8.encode(body))) {
    _headers.set('content-type', 'application/json; charset=utf-8');
    _headers.contentLength = _bytes.length;
  }

  final List<int> _bytes;
  final _FakeHttpHeaders _headers;

  @override
  final int statusCode;

  @override
  String get reasonPhrase => statusCode == HttpStatus.ok ? 'OK' : 'ERROR';

  @override
  int get contentLength => _bytes.length;

  @override
  HttpHeaders get headers => _headers;

  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;

  @override
  bool get persistentConnection => false;

  @override
  bool get isRedirect => false;

  @override
  List<RedirectInfo> get redirects => const <RedirectInfo>[];

  @override
  Future<HttpClientResponse> redirect([
    String? method,
    Uri? url,
    bool? followLoops,
  ]) async {
    return this;
  }

  @override
  Future<Socket> detachSocket() {
    return Future<Socket>.error(
      UnsupportedError('detachSocket is not supported in tests'),
    );
  }

  @override
  List<Cookie> get cookies => const <Cookie>[];

  @override
  X509Certificate? get certificate => null;

  @override
  HttpConnectionInfo? get connectionInfo => null;

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeHttpHeaders implements HttpHeaders {
  final Map<String, List<String>> _values = <String, List<String>>{};
  int _contentLength = -1;
  ContentType? _contentType;

  String _normalize(String name) => name.toLowerCase();

  @override
  void add(String name, Object value, {bool preserveHeaderCase = false}) {
    _values
        .putIfAbsent(_normalize(name), () => <String>[])
        .add(value.toString());
  }

  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {
    _values[_normalize(name)] = <String>[value.toString()];
  }

  @override
  void removeAll(String name, {bool preserveHeaderCase = false}) {
    _values.remove(_normalize(name));
  }

  @override
  String? value(String name) {
    final values = _values[_normalize(name)];
    if (values == null || values.isEmpty) {
      return null;
    }
    return values.first;
  }

  @override
  List<String> operator [](String name) {
    return List<String>.unmodifiable(
      _values[_normalize(name)] ?? const <String>[],
    );
  }

  @override
  void forEach(void Function(String name, List<String> values) action) {
    _values.forEach(action);
  }

  @override
  int get contentLength => _contentLength;

  @override
  set contentLength(int value) {
    _contentLength = value;
  }

  @override
  ContentType? get contentType => _contentType;

  @override
  set contentType(ContentType? value) {
    _contentType = value;
  }

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
