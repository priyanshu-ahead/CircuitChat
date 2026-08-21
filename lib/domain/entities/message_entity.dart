/// Message type enum — mirrors data layer but lives in domain.
enum MessageKind { text, image, video, audio, file, location, call }

/// Message delivery status.
enum DeliveryStatus { sending, sent, delivered, seen, failed }

/// Pure domain entity for a chat message.
class MessageEntity {
  const MessageEntity({
    required this.id,
    required this.chatId,
    required this.senderId,
    required this.kind,
    this.text,
    this.mediaUrl,
    this.mediaDuration,
    this.latitude,
    this.longitude,
    this.status = DeliveryStatus.sent,
    this.isDeleted = false,
    this.replyToId,
    required this.createdAt,
  });

  final String id;
  final String chatId;
  final String senderId;
  final MessageKind kind;
  final String? text;
  final String? mediaUrl;
  final int? mediaDuration; // seconds
  final double? latitude;
  final double? longitude;
  final DeliveryStatus status;
  final bool isDeleted;
  final String? replyToId;
  final DateTime createdAt;

  bool get isMedia =>
      kind == MessageKind.image ||
      kind == MessageKind.video ||
      kind == MessageKind.audio ||
      kind == MessageKind.file;

  MessageEntity copyWith({DeliveryStatus? status, bool? isDeleted}) =>
      MessageEntity(
        id: id,
        chatId: chatId,
        senderId: senderId,
        kind: kind,
        text: text,
        mediaUrl: mediaUrl,
        mediaDuration: mediaDuration,
        latitude: latitude,
        longitude: longitude,
        status: status ?? this.status,
        isDeleted: isDeleted ?? this.isDeleted,
        replyToId: replyToId,
        createdAt: createdAt,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MessageEntity && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
