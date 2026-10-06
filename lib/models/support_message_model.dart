import 'package:cloud_firestore/cloud_firestore.dart';

class SupportConversationModel {
  const SupportConversationModel({
    required this.id,
    required this.participantId,
    required this.participantRole,
    required this.participantName,
    required this.createdAt,
  });

  final String id;
  final String participantId;
  final String participantRole;
  final String participantName;
  final DateTime createdAt;

  factory SupportConversationModel.fromFirestore(
    QueryDocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data();
    return SupportConversationModel(
      id: snapshot.id,
      participantId: data['participantId'] as String? ?? '',
      participantRole: data['participantRole'] as String? ?? '',
      participantName: data['participantName'] as String? ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

class SupportMessageModel {
  const SupportMessageModel({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.senderRole,
    required this.senderName,
    required this.receiverId,
    required this.receiverRole,
    required this.message,
    required this.isRead,
    required this.createdAt,
  });

  final String id;
  final String conversationId;
  final String senderId;
  final String senderRole;
  final String senderName;
  final String receiverId;
  final String receiverRole;
  final String message;
  final bool isRead;
  final DateTime createdAt;

  factory SupportMessageModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data() ?? const <String, dynamic>{};
    return SupportMessageModel(
      id: snapshot.id,
      conversationId: data['conversationId'] as String? ?? '',
      senderId: data['senderId'] as String? ?? '',
      senderRole: data['senderRole'] as String? ?? '',
      senderName: data['senderName'] as String? ?? '',
      receiverId: data['receiverId'] as String? ?? '',
      receiverRole: data['receiverRole'] as String? ?? '',
      message: data['message'] as String? ?? '',
      isRead: data['isRead'] as bool? ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
