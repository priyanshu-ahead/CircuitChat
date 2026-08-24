/// Content types matching SE's CONTENT_TYPE constants in the RN app.
enum ContentType {
  text,
  image,
  video,
  audio,
  file,
  location,
  call,
  notification,
  deleted,
  hidden,
  sticker,
  gif,
}

/// Message send/delivery status (mirrors SE's MESSAGE_STATUS constants).
enum MessageStatus {
  sending,   // local optimistic, not yet sent
  sent,      // received by server
  delivered, // received by recipient device
  seen,      // read by recipient
  seenOff,   // seen but read-receipts off
  failed,
  deletedEveryone,
}

/// A single emoji reaction on a message.
class MessageReaction {
  const MessageReaction({
    required this.id,
    required this.messageId,
    required this.userId,
    required this.reaction,
    this.createdAt,
  });

  final String id;
  final String messageId;
  final String userId;
  final String reaction; // emoji string
  final String? createdAt;

  factory MessageReaction.fromJson(Map<String, dynamic> json) =>
      MessageReaction(
        id: (json['_id'] ?? json['id'] ?? '').toString(),
        messageId: (json['message'] ?? '').toString(),
        userId: (json['user'] ?? '').toString(),
        reaction: (json['reaction'] ?? '').toString(),
        createdAt: json['createdAt']?.toString(),
      );

  Map<String, dynamic> toJson() => {
        '_id': id,
        'message': messageId,
        'user': userId,
        'reaction': reaction,
        if (createdAt != null) 'createdAt': createdAt,
      };
}

/// A mention entry inside a message.
class MessageMention {
  const MessageMention({required this.id, required this.name});
  final String id;
  final String name;

  factory MessageMention.fromJson(Map<String, dynamic> json) =>
      MessageMention(
        id: (json['_id'] ?? json['id'] ?? '').toString(),
        name: (json['name'] ?? '').toString(),
      );
}

/// Full message model matching the SE API and the RN Redux message slice.
class MessageModel {
  const MessageModel({
    required this.id,
    required this.chatId,
    required this.senderId,
    required this.contentType,
    this.text,
    this.mediaUrl,
    this.mediaSize,
    this.mediaDuration,
    this.latitude,
    this.longitude,
    this.status = MessageStatus.sent,
    this.isDeleted = false,
    this.isStarred = false,
    this.fromMe = false,
    this.isNew = false,
    this.replyToId,
    this.replyToMessage,
    this.forwardFrom,
    this.pinned,
    this.reactions = const [],
    this.mentions = const [],
    required this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String chatId;
  final String senderId;
  final ContentType contentType;
  final String? text;
  final String? mediaUrl;
  final int? mediaSize;
  final int? mediaDuration;
  final double? latitude;
  final double? longitude;
  final MessageStatus status;
  final bool isDeleted;
  final bool isStarred;

  /// `true` if this message was sent by the current logged-in user.
  final bool fromMe;

  /// `true` if this is a newly arrived unread message (used to auto-scroll).
  final bool isNew;

  final String? replyToId;

  /// Embedded preview of the replied-to message.
  final MessageModel? replyToMessage;

  /// Original sender info if this message was forwarded.
  final Map<String, dynamic>? forwardFrom;

  /// Pin info (if pinned).
  final Map<String, dynamic>? pinned;

  final List<MessageReaction> reactions;
  final List<MessageMention> mentions;
  final String createdAt;
  final String? updatedAt;

  // ── Convenience aliases ───────────────────────────────────────────────────
  /// `true` for types the UI renders as media bubbles.
  bool get isMedia =>
      contentType == ContentType.image ||
      contentType == ContentType.video ||
      contentType == ContentType.audio ||
      contentType == ContentType.file ||
      contentType == ContentType.gif ||
      contentType == ContentType.sticker;

  bool get isSystemMessage =>
      contentType == ContentType.notification ||
      contentType == ContentType.hidden ||
      contentType == ContentType.call;

  // ── Parsing helpers ───────────────────────────────────────────────────────
  static ContentType _contentTypeFromJson(dynamic v) {
    switch (v?.toString()) {
      case 'image':
        return ContentType.image;
      case 'video':
        return ContentType.video;
      case 'audio':
        return ContentType.audio;
      case 'file':
        return ContentType.file;
      case 'location':
        return ContentType.location;
      case 'call':
        return ContentType.call;
      case 'notification':
        return ContentType.notification;
      case 'deleted':
        return ContentType.deleted;
      case 'hidden':
        return ContentType.hidden;
      case 'sticker':
        return ContentType.sticker;
      case 'gif':
        return ContentType.gif;
      default:
        return ContentType.text;
    }
  }

  static MessageStatus _statusFromJson(dynamic v) {
    switch (v?.toString()) {
      case '0':
      case 'sending':
        return MessageStatus.sending;
      case '1':
      case 'sent':
        return MessageStatus.sent;
      case '2':
      case 'delivered':
        return MessageStatus.delivered;
      case '3':
      case 'seen':
        return MessageStatus.seen;
      case '4':
      case 'seenOff':
        return MessageStatus.seenOff;
      case 'failed':
        return MessageStatus.failed;
      case 'deletedEveryone':
        return MessageStatus.deletedEveryone;
      default:
        return MessageStatus.sent;
    }
  }

  static List<MessageReaction> _reactionsFromJson(dynamic v) {
    if (v is List) {
      return v
          .whereType<Map<String, dynamic>>()
          .map((e) => MessageReaction.fromJson(e))
          .toList();
    }
    return const [];
  }

  static List<MessageMention> _mentionsFromJson(dynamic v) {
    if (v is List) {
      return v
          .whereType<Map<String, dynamic>>()
          .map((e) => MessageMention.fromJson(e))
          .toList();
    }
    return const [];
  }

  static MessageModel? _replyFromJson(dynamic v) {
    if (v is Map<String, dynamic>) return MessageModel.fromJson(v);
    return null;
  }

  static int? _toInt(dynamic v) =>
      v == null ? null : (v is num ? v.toInt() : int.tryParse(v.toString()));

  static double? _toDouble(dynamic v) =>
      v == null ? null : (v is num ? v.toDouble() : double.tryParse(v.toString()));

  static bool _toBool(dynamic v, {bool fallback = false}) {
    if (v == null) return fallback;
    if (v is bool) return v;
    if (v is num) return v != 0;
    return fallback;
  }

  factory MessageModel.fromJson(Map<String, dynamic> json) => MessageModel(
        id: (json['_id'] ?? json['id'] ?? json['message_id'] ?? '').toString(),
        chatId: (json['chat'] ?? json['chat_id'] ?? json['chatId'] ?? '').toString(),
        senderId: (json['sender'] ?? json['sender_id'] ?? json['senderId'] ?? '').toString(),
        contentType: _contentTypeFromJson(json['contentType'] ?? json['type']),
        text: json['text']?.toString(),
        mediaUrl: (json['media_url'] ?? json['mediaUrl'] ?? json['url'])?.toString(),
        mediaSize: _toInt(json['media_size'] ?? json['mediaSize'] ?? json['size']),
        mediaDuration: _toInt(json['media_duration'] ?? json['mediaDuration'] ?? json['duration']),
        latitude: _toDouble(json['latitude']),
        longitude: _toDouble(json['longitude']),
        status: _statusFromJson(json['status'] ?? json['message_status']),
        isDeleted: _toBool(json['deleted'] ?? json['isDeleted'] ?? json['is_deleted']),
        isStarred: _toBool(json['starred'] ?? json['isStarred']),
        fromMe: _toBool(json['fromMe'] ?? json['from_me']),
        isNew: _toBool(json['new'] ?? json['isNew']),
        replyToId: (json['replyTo'] ?? json['reply_to_id'] ?? json['replyToId'])?.toString(),
        replyToMessage: _replyFromJson(json['replyMessage'] ?? json['reply_to_message']),
        forwardFrom: json['forwardFrom'] is Map<String, dynamic>
            ? json['forwardFrom'] as Map<String, dynamic>
            : null,
        pinned: json['pin'] is Map<String, dynamic>
            ? json['pin'] as Map<String, dynamic>
            : null,
        reactions: _reactionsFromJson(json['reactions']),
        mentions: _mentionsFromJson(json['mentions']),
        createdAt: (json['createdAt'] ?? json['created_at'] ?? '').toString(),
        updatedAt: (json['updatedAt'] ?? json['updated_at'])?.toString(),
      );

  Map<String, dynamic> toJson() => {
        '_id': id,
        'chat': chatId,
        'sender': senderId,
        'contentType': contentType.name,
        if (text != null) 'text': text,
        if (mediaUrl != null) 'mediaUrl': mediaUrl,
        if (mediaSize != null) 'mediaSize': mediaSize,
        if (mediaDuration != null) 'mediaDuration': mediaDuration,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
        'status': status.index,
        'deleted': isDeleted,
        'starred': isStarred,
        'fromMe': fromMe,
        if (replyToId != null) 'replyTo': replyToId,
        'reactions': reactions.map((e) => e.toJson()).toList(),
        'createdAt': createdAt,
        if (updatedAt != null) 'updatedAt': updatedAt,
      };

  MessageModel copyWith({
    String? text,
    MessageStatus? status,
    bool? isDeleted,
    bool? isStarred,
    bool? fromMe,
    bool? isNew,
    List<MessageReaction>? reactions,
    Map<String, dynamic>? pinned,
  }) =>
      MessageModel(
        id: id,
        chatId: chatId,
        senderId: senderId,
        contentType: contentType,
        text: text ?? this.text,
        mediaUrl: mediaUrl,
        mediaSize: mediaSize,
        mediaDuration: mediaDuration,
        latitude: latitude,
        longitude: longitude,
        status: status ?? this.status,
        isDeleted: isDeleted ?? this.isDeleted,
        isStarred: isStarred ?? this.isStarred,
        fromMe: fromMe ?? this.fromMe,
        isNew: isNew ?? this.isNew,
        replyToId: replyToId,
        replyToMessage: replyToMessage,
        forwardFrom: forwardFrom,
        pinned: pinned ?? this.pinned,
        reactions: reactions ?? this.reactions,
        mentions: mentions,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );
}

// Keep MessageType as a type alias for backward compatibility (media send).
enum MessageType { text, image, video, audio, file, location, call }
