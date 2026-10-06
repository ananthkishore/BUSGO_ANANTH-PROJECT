import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_12/models/notification_model.dart';

void main() {
  test('owner message notifications retain sender details for admins', () {
    final notification = NotificationModel(
      id: 'owner-message-1',
      recipientId: 'admin-1',
      type: 'owner_message',
      title: 'Message from bus owner',
      message: 'Please help with my bus listing.',
      relatedOwnerId: 'owner-1',
      relatedOwnerName: 'Kishore',
      isRead: false,
      createdAt: DateTime(2026, 9, 30),
    );

    final data = notification.toFirestore();

    expect(data['recipientId'], 'admin-1');
    expect(data['type'], 'owner_message');
    expect(data['message'], 'Please help with my bus listing.');
    expect(data['ownerId'], 'owner-1');
    expect(data['ownerName'], 'Kishore');
  });

  test('customer message notifications retain customer details for admins', () {
    final notification = NotificationModel(
      id: 'customer-message-1',
      recipientId: 'admin-1',
      type: 'customer_message',
      title: 'Message from customer',
      message: 'Hi, I need help with my booking.',
      relatedCustomerId: 'customer-9',
      relatedCustomerName: 'Priya',
      isRead: false,
      createdAt: DateTime(2026, 9, 30),
    );

    final data = notification.toFirestore();

    expect(data['recipientId'], 'admin-1');
    expect(data['type'], 'customer_message');
    expect(data['message'], 'Hi, I need help with my booking.');
    expect(data['customerId'], 'customer-9');
    expect(data['customerName'], 'Priya');
  });

  test('support notifications retain their conversation reference', () {
    final notification = NotificationModel(
      id: 'support-reply-1',
      recipientId: 'customer-9',
      type: 'support_reply',
      title: 'BUSGO Admin replied to your message',
      message: 'How can I help?',
      conversationId: 'customer-9',
      senderId: 'admin-1',
      isRead: false,
      createdAt: DateTime(2026, 10, 5),
    );

    expect(notification.toFirestore()['conversationId'], 'customer-9');
  });

  test(
    'owner support notifications keep the authenticated sender identity in every supported field',
    () {
      final notification = NotificationModel(
        id: 'owner-message-2',
        recipientId: 'admin-1',
        type: 'owner_message',
        title: 'Message from bus owner',
        message: 'Hi good',
        senderId: 'owner-42',
        relatedOwnerId: 'owner-42',
        relatedOwnerName: 'Owner Test',
        isRead: false,
        createdAt: DateTime(2026, 9, 30),
      );

      final data = notification.toFirestore();

      expect(data['senderId'], 'owner-42');
      expect(data['ownerId'], 'owner-42');
      expect(data['relatedOwnerId'], 'owner-42');
    },
  );

  test('bus deletion notification keeps structured historical identifiers', () {
    final deletedAt = DateTime(2026, 9, 29, 14, 30);
    final notification = NotificationModel(
      id: 'bus-1_deleted_admin-1',
      recipientId: 'admin-1',
      type: 'bus_deleted_by_owner',
      title: 'Bus deleted by owner',
      message: 'City Express was deleted by Kishore.',
      relatedBusId: 'bus-1',
      relatedOwnerId: 'owner-1',
      relatedBusName: 'City Express',
      relatedRegistrationNumber: 'TN-39',
      relatedOwnerName: 'Kishore',
      deletedAt: deletedAt,
      isRead: false,
      createdAt: deletedAt,
    );

    final data = notification.toFirestore();

    expect(data['type'], 'bus_deleted_by_owner');
    expect(data['relatedBusId'], 'bus-1');
    expect(data['ownerId'], 'owner-1');
    expect(data['busName'], 'City Express');
    expect(data['registrationNumber'], 'TN-39');
    expect(data['ownerName'], 'Kishore');
    expect((data['deletedAt'] as Timestamp).toDate(), deletedAt);
  });

  test(
    'legacy bus status notification IDs recover the exact bus document ID',
    () {
      final approved = NotificationModel(
        id: 'bus_doc_1_status_approved_owner-1',
        recipientId: 'owner-1',
        type: 'bus_approved',
        title: 'Bus approved',
        message: 'Bus approved',
        isRead: false,
        createdAt: DateTime(2026, 9, 29),
      );
      final rejected = NotificationModel(
        id: 'bus_doc_2_status_rejected_owner-1',
        recipientId: 'owner-1',
        type: 'bus_rejected',
        title: 'Bus submission rejected',
        message: 'Bus submission rejected',
        isRead: false,
        createdAt: DateTime(2026, 9, 29),
      );

      expect(approved.busIdForNavigation, 'bus_doc_1');
      expect(rejected.busIdForNavigation, 'bus_doc_2');
    },
  );

  test(
    'legacy bus ID recovery rejects unrelated or mismatched notification IDs',
    () {
      final notification = NotificationModel(
        id: 'bus_doc_1_status_approved_other-owner',
        recipientId: 'owner-1',
        type: 'bus_update_approved',
        title: 'Bus update approved',
        message: 'Bus update approved',
        isRead: false,
        createdAt: DateTime(2026, 9, 29),
      );

      expect(notification.busIdForNavigation, isNull);
    },
  );

  test('legacy bus update submission ID recovers its bus document ID', () {
    final notification = NotificationModel(
      id: 'bus_doc_3_update_admin-1',
      recipientId: 'admin-1',
      type: 'bus_update_submitted',
      title: 'Bus update requires review',
      message: 'Bus update requires review',
      isRead: false,
      createdAt: DateTime(2026, 9, 29),
    );

    expect(notification.busIdForNavigation, 'bus_doc_3');

    final approvedUpdate = NotificationModel(
      id: 'bus_doc_4_bus_update_approved_owner-1',
      recipientId: 'owner-1',
      type: 'bus_update_approved',
      title: 'Bus update approved',
      message: 'Bus update approved',
      isRead: false,
      createdAt: DateTime(2026, 9, 29),
    );
    final rejectedUpdate = NotificationModel(
      id: 'bus_doc_5_bus_update_rejected_owner-1',
      recipientId: 'owner-1',
      type: 'bus_update_rejected',
      title: 'Bus update rejected',
      message: 'Bus update rejected',
      isRead: false,
      createdAt: DateTime(2026, 9, 29),
    );

    expect(approvedUpdate.busIdForNavigation, 'bus_doc_4');
    expect(rejectedUpdate.busIdForNavigation, 'bus_doc_5');
  });
}
