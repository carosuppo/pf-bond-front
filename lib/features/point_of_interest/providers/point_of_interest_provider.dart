import 'package:flutter/foundation.dart';

import '../models/point_of_interest.dart';
import '../models/point_of_interest_request.dart';
import '../services/point_of_interest_service.dart';

class PointOfInterestProvider extends ChangeNotifier {
  final PointOfInterestService _service;

  PointOfInterestProvider(this._service);

  List<PointOfInterest> points = [];
  bool loading = false;
  bool saving = false;
  bool updating = false;
  bool deleting = false;
  String? errorMessage;
  int? _groupId;
  int _loadVersion = 0;
  int _sessionVersion = 0;

  Future<void> loadPoints(int groupId) async {
    final loadVersion = ++_loadVersion;
    _groupId = groupId;
    points = [];
    loading = true;
    errorMessage = null;
    notifyListeners();
    try {
      final loaded = await _service.getAll(groupId);
      if (_groupId == groupId && _loadVersion == loadVersion) points = loaded;
    } catch (error) {
      if (_groupId == groupId && _loadVersion == loadVersion) {
        errorMessage = _message(error);
      }
    } finally {
      if (_groupId == groupId && _loadVersion == loadVersion) {
        loading = false;
        notifyListeners();
      }
    }
  }

  void clear() {
    _sessionVersion++;
    _loadVersion++;
    _groupId = null;
    points = [];
    loading = false;
    saving = false;
    updating = false;
    deleting = false;
    errorMessage = null;
    notifyListeners();
  }

  void resetSessionState() => clear();

  Future<bool> create(int groupId, CreatePointOfInterestRequest request) async {
    final sessionVersion = _sessionVersion;
    saving = true;
    errorMessage = null;
    notifyListeners();
    try {
      final point = await _service.create(groupId, request);
      if (sessionVersion != _sessionVersion) return false;
      if (_groupId == groupId) points = [...points, point];
      return true;
    } catch (error) {
      if (sessionVersion != _sessionVersion) return false;
      errorMessage = _message(error);
      return false;
    } finally {
      if (sessionVersion == _sessionVersion) {
        saving = false;
        notifyListeners();
      }
    }
  }

  Future<bool> update(
    int groupId,
    int pointId,
    UpdatePointOfInterestRequest request,
  ) async {
    final sessionVersion = _sessionVersion;
    updating = true;
    errorMessage = null;
    notifyListeners();
    try {
      final updated = await _service.update(groupId, pointId, request);
      if (sessionVersion != _sessionVersion) return false;
      if (_groupId == groupId) {
        points = points
            .map((point) => point.id == pointId ? updated : point)
            .toList();
      }
      return true;
    } catch (error) {
      if (sessionVersion != _sessionVersion) return false;
      errorMessage = _message(error);
      return false;
    } finally {
      if (sessionVersion == _sessionVersion) {
        updating = false;
        notifyListeners();
      }
    }
  }

  Future<bool> delete(int groupId, int pointId) async {
    final sessionVersion = _sessionVersion;
    deleting = true;
    errorMessage = null;
    notifyListeners();
    try {
      await _service.delete(groupId, pointId);
      if (sessionVersion != _sessionVersion) return false;
      if (_groupId == groupId) {
        points = points.where((point) => point.id != pointId).toList();
      }
      return true;
    } catch (error) {
      if (sessionVersion != _sessionVersion) return false;
      errorMessage = _message(error);
      return false;
    } finally {
      if (sessionVersion == _sessionVersion) {
        deleting = false;
        notifyListeners();
      }
    }
  }

  String _message(Object error) =>
      error.toString().replaceFirst('Exception: ', '');
}
