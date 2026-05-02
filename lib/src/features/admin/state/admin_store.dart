import '../../../core/api/mobile_api.dart';
import '../../shared/models/app_models.dart';
import 'package:flutter/foundation.dart';

class AdminStore extends ChangeNotifier {
  AdminStore._();

  static final AdminStore instance = AdminStore._();

  bool _loadingSummary = false;
  bool _loadingActivity = false;
  bool _loadingHomeActions = false;
  bool _loadedSummary = false;
  bool _loadedActivity = false;
  bool _loadedHomeActions = false;
  Object? _summaryError;
  Object? _activityError;
  Object? _homeActionsError;

  AdminSupplierSummary _summary = const AdminSupplierSummary(
    totalSuppliers: 0,
    activeSuppliers: 0,
    blockedSuppliers: 0,
  );
  List<AdminHomeAction> _homeActions = _defaultHomeActions;
  List<DispatchRecord> _activityItems = const <DispatchRecord>[];

  bool get loadingSummary => _loadingSummary;
  bool get loadingActivity => _loadingActivity;
  bool get loadingHomeActions => _loadingHomeActions;
  bool get loadedSummary => _loadedSummary;
  bool get loadedActivity => _loadedActivity;
  bool get loadedHomeActions => _loadedHomeActions;
  Object? get summaryError => _summaryError;
  Object? get activityError => _activityError;
  Object? get homeActionsError => _homeActionsError;
  AdminSupplierSummary get summary => _summary;
  List<AdminHomeAction> get homeActions => _homeActions;
  List<DispatchRecord> get activityItems => _activityItems;

  Future<void> bootstrapSummary({bool force = false}) async {
    if (_loadingSummary) return;
    if (_loadedSummary && !force) return;
    await refreshSummary();
  }

  Future<void> bootstrapActivity({bool force = false}) async {
    if (_loadingActivity) return;
    if (_loadedActivity && !force) return;
    await refreshActivity();
  }

  Future<void> bootstrapHomeActions({bool force = false}) async {
    if (_loadingHomeActions) return;
    if (_loadedHomeActions && !force) return;
    await refreshHomeActions();
  }

  Future<void> refreshSummary() async {
    if (_loadingSummary) return;
    _loadingSummary = true;
    _summaryError = null;
    notifyListeners();
    try {
      _summary = await MobileApi.instance.adminSupplierSummary();
      _loadedSummary = true;
    } catch (error) {
      _summaryError = error;
    } finally {
      _loadingSummary = false;
      notifyListeners();
    }
  }

  Future<void> refreshHomeActions() async {
    if (_loadingHomeActions) return;
    _loadingHomeActions = true;
    _homeActionsError = null;
    notifyListeners();
    try {
      final actions = await MobileApi.instance.adminHomeActions();
      if (actions.isNotEmpty) {
        _homeActions = actions;
      }
      _loadedHomeActions = true;
    } catch (error) {
      _homeActionsError = error;
    } finally {
      _loadingHomeActions = false;
      notifyListeners();
    }
  }

  Future<void> refreshActivity() async {
    if (_loadingActivity) return;
    _loadingActivity = true;
    _activityError = null;
    notifyListeners();
    try {
      _activityItems = await MobileApi.instance.adminActivity();
      _loadedActivity = true;
    } catch (error) {
      _activityError = error;
    } finally {
      _loadingActivity = false;
      notifyListeners();
    }
  }

  Future<void> refreshAll() async {
    await Future.wait([
      refreshSummary(),
      refreshActivity(),
    ]);
  }

  void clear() {
    _loadingSummary = false;
    _loadingActivity = false;
    _loadingHomeActions = false;
    _loadedSummary = false;
    _loadedActivity = false;
    _loadedHomeActions = false;
    _summaryError = null;
    _activityError = null;
    _homeActionsError = null;
    _summary = const AdminSupplierSummary(
      totalSuppliers: 0,
      activeSuppliers: 0,
      blockedSuppliers: 0,
    );
    _homeActions = _defaultHomeActions;
    _activityItems = const <DispatchRecord>[];
    notifyListeners();
  }

  static const List<AdminHomeAction> _defaultHomeActions = [
    AdminHomeAction(
      id: 'erp_settings',
      title: 'ERP settings',
      subtitle: 'Core integration and stock defaults',
      routeName: '/admin-settings',
      highlighted: true,
    ),
    AdminHomeAction(
      id: 'suppliers',
      title: 'Suppliers',
      subtitle: 'List, mahsulot biriktirish va block nazorati',
      routeName: '/admin-suppliers',
      highlighted: false,
    ),
    AdminHomeAction(
      id: 'werka',
      title: 'Add Werka',
      subtitle: 'Configure warehouse worker phone and name',
      routeName: '/admin-werka',
      highlighted: false,
    ),
  ];
}
