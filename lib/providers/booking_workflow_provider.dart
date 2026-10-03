import 'package:flutter/foundation.dart';

import '../core/constants/booking_status.dart';
import '../repositories/booking_request_repository.dart';

class BookingWorkflowProvider extends ChangeNotifier {
  BookingWorkflowProvider({BookingRequestRepository? repository})
    : _repository = repository ?? BookingRequestRepository();

  final BookingRequestRepository _repository;
  bool _isBusy = false;
  String? _errorMessage;

  bool get isBusy => _isBusy;
  String? get errorMessage => _errorMessage;

  Future<bool> transition({
    required String requestId,
    required BookingRequestStatus nextStatus,
    String? rejectionReason,
    String? ownerId,
    String? customerId,
    String? busId,
  }) async {
    if (_isBusy) return false;
    _isBusy = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await _repository.transitionStatus(
        requestId: requestId,
        nextStatus: nextStatus,
        rejectionReason: rejectionReason,
        ownerId: ownerId,
        customerId: customerId,
        busId: busId,
      );
      return true;
    } catch (error) {
      _errorMessage = error.toString().replaceFirst('Exception: ', '');
      return false;
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }
}
