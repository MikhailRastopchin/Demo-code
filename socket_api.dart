// ignore_for_file: avoid_types_on_closure_parameters, prefer_mixin, avoid_catches_without_on_clauses, avoid_print, unused_element

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:data/api/endpoints.dart';
import 'package:data/api/models/chats/chat.dart';
import 'package:data/api/models/chats/message.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/status.dart' as status;

class SocketApi with ChangeNotifier {
  SocketApi();

  IOWebSocketChannel? _socket;
  Completer<bool> _connecting = Completer<bool>();
  final StreamController<Chat> _chatsController = StreamController.broadcast();
  final StreamController<Message> _messagesController =
      StreamController.broadcast();
  final StreamController<int> _readEventsController =
      StreamController.broadcast();

  StreamSubscription? _socketSubscription;

  Stream<Chat> get chats => _chatsController.stream;
  Stream<Message> get messages => _messagesController.stream;
  Stream<int> get readEvents => _readEventsController.stream;

  int? _profileId;

  Future<void> setProfile({required final int profileId}) async {
    _profileId = profileId;
    await _connect();
  }

  void removeProfile() {
    _profileId = null;
    _close();
  }

  Future<void> _connect() async {
    await _close();
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('TOKEN');
    assert(_profileId != null);
    final wsUrl = Uri.parse('${Endpoints.baseWsUrl}/$_profileId/?token=$token');
    if (token == null || _profileId == null) {
      await _chatsController.close();
      await _messagesController.close();
      await _readEventsController.close();
      _connecting.complete(false);
    } else if (_socket == null && _socketSubscription == null) {
      try {
        _socket = IOWebSocketChannel.connect(
          wsUrl,
          pingInterval: const Duration(seconds: 5),
        );
        _socketSubscription = _socket!.stream.listen(
          _onMessage,
          onDone: _onDone,
          onError: (Object err, StackTrace stackTrace) {
            print('Listen err $err, $stackTrace');
          },
        );
        _connecting.complete(true);
        debugPrint('connected');
      } catch (_) {
        debugPrint('cant connected');
      }
    }
  }

  Future<void> _onDone() async {
    await _close();
    await Future<void>.delayed(const Duration(seconds: 1), () async {
      await _connect();
    });
  }

  Future<void> _close() async {
    _connecting = Completer<bool>();
    await _socketSubscription?.cancel();
    _socketSubscription = null;
    try {
      await _socket?.sink.close(status.normalClosure);
    } catch (_) {
      debugPrint('Socket already closed.');
    }

    if (_socket != null) {
      print(['disconnected', _socket?.closeCode, _socket?.closeReason]);
    }
    _socket = null;
  }

  void _onMessage(dynamic message) {
    debugPrint('✅ RECEIVED: $message');
    final msg = jsonDecode(message.toString()) as Map<String, dynamic>;
    final chatJson = msg['chat'] as Map<String, dynamic>;
    final event = msg['type'] as String;
    if (event == 'write_message') {
      final chatModel = Chat.fromJson(chatJson);
      _chatsController.sink.add(chatModel);
      if (chatModel.lastMessage != null) {
        _messagesController.sink.add(chatModel.lastMessage!);
      }
    } else if (event == 'read_messages') {
      final chatId = chatJson['id'] as int;
      _readEventsController.sink.add(chatId);
    }
  }

  Future<void> _send(
    String cmd,
    int chatId,
    String? message, {
    Map<String, dynamic>? data,
  }) async {
    if (_socket == null) {
      await _connect();
    }
    final connectionResult = await _connecting.future;
    if (connectionResult != true) {
      return;
    }
    final d = <String, dynamic>{
      'type': cmd,
      'chat_id': chatId,
      'message': message,
    };
    d.removeWhere((key, value) => value == null);
    final json = jsonEncode(d);
    _socket!.sink.add(json);
    debugPrint('💬 SEND: $d');
  }

  Future<void> sendTextMessage({
    required final String text,
    required final int chatId,
  }) async {
    await _send('write_message', chatId, text);
  }

  Future<void> setMessagesRead({required final int chatId}) async {
    await _send('read_message', chatId, null);
  }

  @override
  Future<void> dispose() async {
    await _socketSubscription?.cancel();
    await _chatsController.close();
    await _messagesController.close();
    await _readEventsController.close();
    super.dispose();
  }
}
