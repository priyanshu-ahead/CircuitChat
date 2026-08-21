enum MessageType { text, image, video, audio, file, location, call }

enum MessageStatus { sending, sent, delivered, seen, failed }

class MessageModel {
  const MessageModel({
    required this.id,
    required this.chatId,
    required this.senderId,
    required this.type,
    this.text,
    this.mediaUrl,
    this.mediaSize,
    this.mediaDuration,
    this.latitude,
    this.longitude,
    this.status = MessageStatus.sent,
    this.isDeleted = false,
    this.replyToId,
    required this.createdAt,
  });

  final String id;
  final String chatId;
  final String senderId;
  final MessageType type;
  final String? text;
  final String? mediaUrl;
  final int? mediaSize;
  final int? mediaDuration;
  final double? latitude;
  final double? longitude;
  final MessageStatus status;
  final bool isDeleted;
  final String? replyToId;
  final String createdAt;

  static MessageType _typeFromJson(dynamic v) {
    final s = v?.toString() ?? 'text';
    return MessageType.values.firstWhere(
      (e) => e.name == s,
      orElse: () => MessageType.text,
    );
  }

  static String _typeToJson(MessageType t) => t.name;

  static MessageStatus _statusFromJson(dynamic v) {
    final s = v?.toString() ?? 'sent';
    return MessageStatus.values.firstWhere(
      (e) => e.name == s,
      orElse: () => MessageStatus.sent,
    );
  }

  static String _statusToJson(MessageStatus s) => s.name;

  static int? _toInt(dynamic v) =>
      v == null ? null : (v is num ? v.toInt() : int.tryParse(v.toString()));

  static double? _toDouble(dynamic v) =>
      v == null ? null : (v is num ? v.toDouble() : double.tryParse(v.toString()));

  factory MessageModel.fromJson(Map<String, dynamic> json) => MessageModel(
        id: (json['id'] ?? json['_id'] ?? json['message_id'] ?? '').toString(),
        chatId: (json['chat_id'] ?? json['chatId'] ?? '').toString(),
        senderId: (json['sender_id'] ?? json['senderId'] ?? '').toString(),
        type: _typeFromJson(json['type']),
        text: json['text']?.toString(),
        mediaUrl: json['media_url']?.toString() ?? json['mediaUrl']?.toString(),
        mediaSize: _toInt(json['media_size'] ?? json['mediaSize']),
        mediaDuration: _toInt(json['media_duration'] ?? json['mediaDuration']),
        latitude: _toDouble(json['latitude']),
        longitude: _toDouble(json['longitude']),
        status: _statusFromJson(json['status']),
        isDeleted: json['is_deleted'] == true || json['isDeleted'] == true,
        replyToId: (json['reply_to_id'] ?? json['replyToId'])?.toString(),
        createdAt: (json['created_at'] ?? json['createdAt'] ?? '').toString(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'chat_id': chatId,
        'sender_id': senderId,
        'type': _typeToJson(type),
        if (text != null) 'text': text,
        if (mediaUrl != null) 'media_url': mediaUrl,
        if (mediaSize != null) 'media_size': mediaSize,
        if (mediaDuration != null) 'media_duration': mediaDuration,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
        'status': _statusToJson(status),
        'is_deleted': isDeleted,
        if (replyToId != null) 'reply_to_id': replyToId,
        'created_at': createdAt,
      };
}
