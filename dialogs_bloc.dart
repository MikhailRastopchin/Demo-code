// ignore_for_file: cascade_invocations

import 'dart:async';

import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'dialogs_bloc.freezed.dart';

@freezed
class DialogsState with _$DialogsState {
  const DialogsState._();

  const factory DialogsState.initial() = _InitialState;

  const factory DialogsState.fetching({
    required final int page,
    required final int ownProfileId,
    required final bool hasBadge,
    final String? search,
  }) = _FetchingState;

  const factory DialogsState.error({
    required final int ownProfileId,
    @Default(false) final bool hasBadge,
    final int? page,
    final String? search,
  }) = _ErrorState;

  const factory DialogsState.networkError({
    required final int ownProfileId,
    @Default(false) final bool hasBadge,
    final int? page,
    final String? search,
  }) = _NetworkErrorState;

  const factory DialogsState.fetched({
    required final int page,
    required final int ownProfileId,
    required final bool hasBadge,
    required final List<Chat> chats,
    final String? search,
  }) = _FetchedState;

  List<Chat>? get chats =>
      maybeMap<List<Chat>?>(orElse: () => null, fetched: (s) => s.chats);

  bool get hasBadge => map<bool>(
    initial: (s) => false,
    fetching: (s) => s.hasBadge,
    error: (s) => s.hasBadge,
    networkError: (s) => s.hasBadge,
    fetched: (s) => s.hasBadge,
  );

  String? get search => map<String?>(
    initial: (s) => null,
    fetching: (s) => s.search,
    error: (s) => s.search,
    networkError: (s) => s.search,
    fetched: (s) => s.search,
  );

  bool get isLoading =>
      maybeMap<bool>(orElse: () => false, fetching: (s) => true);

  bool get isError => maybeMap<bool>(orElse: () => false, error: (s) => true);

  bool get isNetworkError =>
      maybeMap<bool>(orElse: () => false, networkError: (s) => true);

  bool get isFetched =>
      maybeMap<bool>(orElse: () => false, fetched: (s) => true);

  int? get ownProfileId => map<int?>(
    initial: (s) => null,
    fetching: (s) => s.ownProfileId,
    error: (s) => s.ownProfileId,
    networkError: (s) => s.ownProfileId,
    fetched: (s) => s.ownProfileId,
  );

  int? get page => map<int?>(
    initial: (s) => null,
    fetching: (s) => s.page,
    error: (s) => s.page,
    networkError: (s) => s.page,
    fetched: (s) => s.page,
  );
}

@freezed
class DialogsEvent with _$DialogsEvent {
  const factory DialogsEvent.connectToSocket({
    required final int ownProfileId,
    final String? search,
  }) = _ConnectToSocketEvent;

  const factory DialogsEvent.fetch({
    required final int ownProfileId,
    final String? search,
  }) = _FetchEvent;

  const factory DialogsEvent.receiveMessage({required final Chat model}) =
      _ReceiveMessageEvent;

  const factory DialogsEvent.setMessagesIsRead({required final int chatId}) =
      _SetMessagesIsReadEvent;

  const factory DialogsEvent.logout() = _LogoutEvent;
}

class DialogsBloc extends Bloc<DialogsEvent, DialogsState> {
  DialogsBloc() : super(const DialogsState.initial()) {
    on<DialogsEvent>(
      (event, emitter) => event.map(
        fetch: (e) => _fetchChats(e, emitter),
        receiveMessage: (e) => _insertReceivedMessage(e, emitter),
        setMessagesIsRead: (e) => _setMessagesIsRead(e, emitter),
        logout: (e) => _clear(e, emitter),
        connectToSocket: (e) => _connectSocket(e, emitter),
      ),
      transformer: sequential(),
    );
  }

  final ChatRepository _chatRepository = serviceDiChat<ChatRepository>();
  final SocketApi socketApi = serviceDiChat<SocketApi>();
  StreamSubscription? _inboundMessageHandler;
  StreamSubscription? _readMessageHandler;

  Future<void> _connectSocket(
    _ConnectToSocketEvent event,
    Emitter<DialogsState> emit,
  ) async {
    await socketApi.setProfile(profileId: event.ownProfileId);
    add(DialogsEvent.fetch(ownProfileId: event.ownProfileId));
  }

  Future<void> _fetchChats(
    _FetchEvent event,
    Emitter<DialogsState> emit,
  ) async {
    _inboundMessageHandler ??= socketApi.chats.listen(_handleInboundMessage);
    _readMessageHandler ??= socketApi.readEvents.listen(_handleReadMessages);
    emit.call(
      DialogsState.fetching(
        ownProfileId: event.ownProfileId,
        hasBadge: state.hasBadge,
        page: 0,
      ),
    );
    try {
      final chats = await _chatRepository.getDialogs(
        search: event.search != null && event.search!.trim().isNotEmpty
            ? event.search!.trim()
            : null,
      );
      final chatsWithMessages = chats
          .where((c) => c.lastMessage != null)
          .toList();
      final chatsWithoutMessages = chats
          .where((c) => c.lastMessage == null)
          .toList();
      chatsWithMessages.sort((one, other) {
        return one.lastMessage!.createdAt.isBefore(other.lastMessage!.createdAt)
            ? 1
            : 0;
      });
      final hasBadge = chats.any((chat) => chat.countUnreadMessages > 0);
      emit.call(
        DialogsState.fetched(
          ownProfileId: event.ownProfileId,
          chats: chatsWithMessages.followedBy(chatsWithoutMessages).toList(),
          hasBadge: hasBadge,
          page: 0,
        ),
      );
    } catch (e) {
      emit.call(DialogsState.error(ownProfileId: event.ownProfileId));
    }
  }

  Future<void> _insertReceivedMessage(
    _ReceiveMessageEvent event,
    Emitter<DialogsState> emit,
  ) async {
    final chats = state.chats?.toList() ?? [];
    final isChatExists = chats.any((chat) => chat.id == event.model.id);
    if (isChatExists) {
      final currentChatIndex = chats.indexWhere(
        (chat) => chat.id == event.model.id,
      );
      chats[currentChatIndex] = event.model;
      chats.sort((one, other) {
        if (one.lastMessage != null && other.lastMessage != null) {
          return one.lastMessage!.createdAt.isBefore(
                other.lastMessage!.createdAt,
              )
              ? 1
              : 0;
        } else if (one.lastMessage == null && other.lastMessage != null) {
          return one.createdAt.isBefore(other.lastMessage!.createdAt) ? 1 : 0;
        } else if (one.lastMessage != null && other.lastMessage == null) {
          return one.lastMessage!.createdAt.isBefore(other.createdAt) ? 1 : 0;
        } else {
          return one.createdAt.isBefore(other.createdAt) ? 1 : 0;
        }
      });
      emit.call(
        DialogsState.fetched(
          hasBadge: event.model.countUnreadMessages > 0 || state.hasBadge,
          chats: chats,
          ownProfileId: state.ownProfileId!,
          page: state.page ?? 0,
        ),
      );
    } else {
      chats.insert(0, event.model);
      emit.call(
        DialogsState.fetched(
          hasBadge: event.model.countUnreadMessages > 0 || state.hasBadge,
          chats: chats,
          ownProfileId: state.ownProfileId!,
          page: state.page ?? 0,
        ),
      );
    }
  }

  Future<void> _setMessagesIsRead(
    _SetMessagesIsReadEvent event,
    Emitter<DialogsState> emit,
  ) async {
    if (state.chats == null) {
      return;
    }
    final chats = List.of(state.chats!);
    final chatIndex = chats.indexWhere((chat) => chat.id == event.chatId);
    if (chatIndex == -1) {
      return;
    }
    final chat = chats[chatIndex];
    chats[chatIndex] = chat.copyWith(countUnreadMessages: 0);
    final hasBadge = chats.any((chat) => chat.countUnreadMessages > 0);
    emit.call(
      DialogsState.fetched(
        chats: chats,
        hasBadge: hasBadge,
        ownProfileId: state.ownProfileId!,
        page: state.page!,
      ),
    );
  }

  void _handleInboundMessage(final Chat model) {
    add(DialogsEvent.receiveMessage(model: model));
  }

  void _handleReadMessages(final int chatId) {
    add(DialogsEvent.setMessagesIsRead(chatId: chatId));
  }

  @override
  Future<void> close() async {
    await _inboundMessageHandler?.cancel();
    await _readMessageHandler?.cancel();
    _inboundMessageHandler = null;
    _readMessageHandler = null;
    await super.close();
  }

  Future<void> _clear(_LogoutEvent event, Emitter<DialogsState> emit) async {
    await _inboundMessageHandler?.cancel();
    await _readMessageHandler?.cancel();
    _inboundMessageHandler = null;
    _readMessageHandler = null;
    emit.call(const DialogsState.initial());
  }
}
