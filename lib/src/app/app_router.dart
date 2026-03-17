import '../features/auth/presentation/login_screen.dart';
import '../features/auth/presentation/app_entry_screen.dart';
import '../features/customer/presentation/customer_delivery_detail_screen.dart';
import '../features/customer/presentation/customer_home_screen.dart';
import '../features/customer/presentation/customer_notifications_screen.dart';
import '../features/customer/presentation/customer_status_detail_screen.dart';
import '../features/admin/presentation/admin_activity_screen.dart';
import '../features/admin/presentation/admin_create_hub_screen.dart';
import '../features/admin/presentation/admin_home_screen.dart';
import '../features/admin/presentation/admin_inactive_suppliers_screen.dart';
import '../features/admin/presentation/admin_item_create_screen.dart';
import '../features/admin/presentation/admin_settings_screen.dart';
import '../features/admin/presentation/admin_supplier_create_screen.dart';
import '../features/admin/presentation/admin_customer_create_screen.dart';
import '../features/admin/presentation/admin_customer_detail_screen.dart';
import '../features/admin/presentation/admin_supplier_detail_screen.dart';
import '../features/admin/presentation/admin_supplier_items_add_screen.dart';
import '../features/admin/presentation/admin_supplier_items_view_screen.dart';
import '../features/admin/presentation/admin_suppliers_screen.dart';
import '../features/admin/presentation/admin_werka_screen.dart';
import '../features/shared/models/app_models.dart';
import '../features/shared/presentation/pin_setup_confirm_screen.dart';
import '../features/shared/presentation/pin_setup_entry_screen.dart';
import '../features/shared/presentation/notification_detail_screen.dart';
import '../features/shared/presentation/profile_screen.dart';
import '../features/supplier/presentation/supplier_confirm_screen.dart';
import '../features/supplier/presentation/supplier_home_screen.dart';
import '../features/supplier/presentation/supplier_item_picker_screen.dart';
import '../features/supplier/presentation/supplier_notifications_screen.dart';
import '../features/supplier/presentation/supplier_status_breakdown_screen.dart';
import '../features/supplier/presentation/supplier_status_detail_screen.dart';
import '../features/supplier/presentation/supplier_qty_screen.dart';
import '../features/supplier/presentation/supplier_recent_screen.dart';
import '../features/supplier/presentation/supplier_success_screen.dart';
import '../features/werka/presentation/werka_detail_screen.dart';
import '../features/werka/presentation/werka_home_screen.dart';
import '../features/werka/presentation/werka_create_hub_screen.dart';
import '../features/werka/presentation/werka_customer_issue_customer_screen.dart';
import '../features/werka/presentation/werka_customer_delivery_detail_screen.dart';
import '../features/werka/presentation/werka_notifications_screen.dart';
import '../features/werka/presentation/werka_recent_screen.dart';
import '../features/werka/presentation/werka_unannounced_supplier_screen.dart';
import '../features/werka/presentation/werka_status_detail_screen.dart';
import '../features/werka/presentation/werka_status_breakdown_screen.dart';
import '../features/werka/presentation/werka_success_screen.dart';
import 'package:flutter/material.dart';

class AppRoutes {
  static const String login = '/';
  static const String supplierHome = '/supplier-home';
  static const String supplierStatusBreakdown = '/supplier-status-breakdown';
  static const String supplierStatusDetail = '/supplier-status-detail';
  static const String supplierItemPicker = '/supplier-item-picker';
  static const String supplierQty = '/supplier-qty';
  static const String supplierConfirm = '/supplier-confirm';
  static const String supplierSuccess = '/supplier-success';
  static const String supplierNotifications = '/supplier-notifications';
  static const String supplierRecent = '/supplier-recent';
  static const String notificationDetail = '/notification-detail';
  static const String werkaHome = '/werka-home';
  static const String werkaCreateHub = '/werka-create-hub';
  static const String werkaCustomerIssueCustomer =
      '/werka-customer-issue-customer';
  static const String werkaUnannouncedSupplier = '/werka-unannounced-supplier';
  static const String werkaNotifications = '/werka-notifications';
  static const String werkaRecent = '/werka-recent';
  static const String werkaStatusBreakdown = '/werka-status-breakdown';
  static const String werkaStatusDetail = '/werka-status-detail';
  static const String werkaDetail = '/werka-detail';
  static const String werkaCustomerDeliveryDetail =
      '/werka-customer-delivery-detail';
  static const String werkaSuccess = '/werka-success';
  static const String profile = '/profile';
  static const String customerHome = '/customer-home';
  static const String customerNotifications = '/customer-notifications';
  static const String customerStatusDetail = '/customer-status-detail';
  static const String customerDetail = '/customer-detail';
  static const String pinSetupEntry = '/pin-setup-entry';
  static const String pinSetupConfirm = '/pin-setup-confirm';
  static const String adminHome = '/admin-home';
  static const String adminActivity = '/admin-activity';
  static const String adminCreateHub = '/admin-create-hub';
  static const String adminSettings = '/admin-settings';
  static const String adminSuppliers = '/admin-suppliers';
  static const String adminSupplierCreate = '/admin-supplier-create';
  static const String adminCustomerCreate = '/admin-customer-create';
  static const String adminCustomerDetail = '/admin-customer-detail';
  static const String adminInactiveSuppliers = '/admin-inactive-suppliers';
  static const String adminItemCreate = '/admin-item-create';
  static const String adminSupplierDetail = '/admin-supplier-detail';
  static const String adminSupplierItemsView = '/admin-supplier-items-view';
  static const String adminSupplierItemsAdd = '/admin-supplier-items-add';
  static const String adminWerka = '/admin-werka';
}

class AppRouter {
  static const Set<String> staticDockRoutes = {
    AppRoutes.supplierHome,
    AppRoutes.supplierNotifications,
    AppRoutes.supplierRecent,
    AppRoutes.werkaHome,
    AppRoutes.werkaNotifications,
    AppRoutes.werkaRecent,
    AppRoutes.adminHome,
    AppRoutes.adminActivity,
    AppRoutes.adminCreateHub,
    AppRoutes.adminSettings,
    AppRoutes.adminSuppliers,
    AppRoutes.adminWerka,
    AppRoutes.profile,
    AppRoutes.customerHome,
    AppRoutes.customerNotifications,
  };

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case AppRoutes.login:
        return _buildRoute(settings, const AppEntryScreen());
      case AppRoutes.supplierHome:
        return _buildRoute(settings, const SupplierHomeScreen());
      case AppRoutes.supplierStatusBreakdown:
        final SupplierStatusKind kind =
            settings.arguments as SupplierStatusKind;
        return _buildRoute(
          settings,
          SupplierStatusBreakdownScreen(kind: kind),
        );
      case AppRoutes.supplierStatusDetail:
        final SupplierStatusDetailArgs args =
            settings.arguments as SupplierStatusDetailArgs;
        return _buildRoute(
          settings,
          SupplierStatusDetailScreen(args: args),
        );
      case AppRoutes.supplierItemPicker:
        return _buildRoute(settings, const SupplierItemPickerScreen());
      case AppRoutes.supplierQty:
        if (settings.arguments is SupplierQtyArgs) {
          final SupplierQtyArgs args = settings.arguments as SupplierQtyArgs;
          return _buildRoute(
            settings,
            SupplierQtyScreen(
              item: args.item,
              initialQty: args.initialQty,
            ),
          );
        }
        final SupplierItem item = settings.arguments as SupplierItem;
        return _buildRoute(settings, SupplierQtyScreen(item: item));
      case AppRoutes.supplierConfirm:
        final SupplierConfirmArgs args =
            settings.arguments as SupplierConfirmArgs;
        return _buildRoute(settings, SupplierConfirmScreen(args: args));
      case AppRoutes.supplierSuccess:
        final DispatchRecord record = settings.arguments as DispatchRecord;
        return _buildRoute(settings, SupplierSuccessScreen(record: record));
      case AppRoutes.supplierNotifications:
        return _buildRoute(settings, const SupplierNotificationsScreen());
      case AppRoutes.supplierRecent:
        return _buildRoute(settings, const SupplierRecentScreen());
      case AppRoutes.notificationDetail:
        final String receiptID = settings.arguments as String;
        return _buildRoute(
          settings,
          NotificationDetailScreen(receiptID: receiptID),
        );
      case AppRoutes.werkaHome:
        return _buildRoute(settings, const WerkaHomeScreen());
      case AppRoutes.werkaCreateHub:
        return _buildRoute(settings, const WerkaCreateHubScreen());
      case AppRoutes.werkaCustomerIssueCustomer:
        final WerkaCustomerIssuePrefillArgs? args =
            settings.arguments is WerkaCustomerIssuePrefillArgs
                ? settings.arguments as WerkaCustomerIssuePrefillArgs
                : null;
        return _buildRoute(
          settings,
          WerkaCustomerIssueCustomerScreen(prefill: args),
        );
      case AppRoutes.werkaUnannouncedSupplier:
        final WerkaUnannouncedPrefillArgs? args =
            settings.arguments is WerkaUnannouncedPrefillArgs
                ? settings.arguments as WerkaUnannouncedPrefillArgs
                : null;
        return _buildRoute(
          settings,
          WerkaUnannouncedSupplierScreen(prefill: args),
        );
      case AppRoutes.werkaNotifications:
        return _buildRoute(settings, const WerkaNotificationsScreen());
      case AppRoutes.werkaRecent:
        return _buildRoute(settings, const WerkaRecentScreen());
      case AppRoutes.werkaStatusBreakdown:
        final WerkaStatusKind kind = settings.arguments as WerkaStatusKind;
        return _buildRoute(
          settings,
          WerkaStatusBreakdownScreen(kind: kind),
        );
      case AppRoutes.werkaStatusDetail:
        final WerkaStatusDetailArgs args =
            settings.arguments as WerkaStatusDetailArgs;
        return _buildRoute(
          settings,
          WerkaStatusDetailScreen(args: args),
        );
      case AppRoutes.werkaDetail:
        final DispatchRecord record = settings.arguments as DispatchRecord;
        return _buildRoute(settings, WerkaDetailScreen(record: record));
      case AppRoutes.werkaCustomerDeliveryDetail:
        final DispatchRecord record = settings.arguments as DispatchRecord;
        return _buildRoute(
          settings,
          WerkaCustomerDeliveryDetailScreen(record: record),
        );
      case AppRoutes.werkaSuccess:
        final DispatchRecord record = settings.arguments as DispatchRecord;
        return _buildRoute(settings, WerkaSuccessScreen(record: record));
      case AppRoutes.profile:
        return _buildRoute(settings, const ProfileScreen());
      case AppRoutes.customerHome:
        return _buildRoute(settings, const CustomerHomeScreen());
      case AppRoutes.customerNotifications:
        return _buildRoute(settings, const CustomerNotificationsScreen());
      case AppRoutes.customerStatusDetail:
        final CustomerStatusKind kind =
            settings.arguments as CustomerStatusKind;
        return _buildRoute(
          settings,
          CustomerStatusDetailScreen(kind: kind),
        );
      case AppRoutes.customerDetail:
        final String deliveryNoteID = settings.arguments as String;
        return _buildRoute(
          settings,
          CustomerDeliveryDetailScreen(deliveryNoteID: deliveryNoteID),
        );
      case AppRoutes.pinSetupEntry:
        return _buildRoute(settings, const PinSetupEntryScreen());
      case AppRoutes.pinSetupConfirm:
        final PinSetupConfirmArgs args =
            settings.arguments as PinSetupConfirmArgs;
        return _buildRoute(settings, PinSetupConfirmScreen(args: args));
      case AppRoutes.adminHome:
        return _buildRoute(settings, const AdminHomeScreen());
      case AppRoutes.adminActivity:
        return _buildRoute(settings, const AdminActivityScreen());
      case AppRoutes.adminCreateHub:
        return _buildRoute(settings, const AdminCreateHubScreen());
      case AppRoutes.adminSettings:
        return _buildAdminSettingsRoute(settings, const AdminSettingsScreen());
      case AppRoutes.adminSuppliers:
        return _buildRoute(settings, const AdminSuppliersScreen());
      case AppRoutes.adminSupplierCreate:
        return _buildRoute(settings, const AdminSupplierCreateScreen());
      case AppRoutes.adminCustomerCreate:
        return _buildRoute(settings, const AdminCustomerCreateScreen());
      case AppRoutes.adminCustomerDetail:
        final String customerRef = settings.arguments as String;
        return _buildRoute(
          settings,
          AdminCustomerDetailScreen(customerRef: customerRef),
        );
      case AppRoutes.adminInactiveSuppliers:
        return _buildRoute(settings, const AdminInactiveSuppliersScreen());
      case AppRoutes.adminItemCreate:
        return _buildRoute(settings, const AdminItemCreateScreen());
      case AppRoutes.adminSupplierDetail:
        final String supplierRef = settings.arguments as String;
        return _buildRoute(
          settings,
          AdminSupplierDetailScreen(supplierRef: supplierRef),
        );
      case AppRoutes.adminSupplierItemsView:
        final String supplierRef = settings.arguments as String;
        return _buildRoute(
          settings,
          AdminSupplierItemsViewScreen(supplierRef: supplierRef),
        );
      case AppRoutes.adminSupplierItemsAdd:
        final String supplierRef = settings.arguments as String;
        return _buildRoute(
          settings,
          AdminSupplierItemsAddScreen(supplierRef: supplierRef),
        );
      case AppRoutes.adminWerka:
        return _buildRoute(settings, const AdminWerkaScreen());
      default:
        return _buildRoute(settings, const LoginScreen());
    }
  }

  static PageRoute<dynamic> _buildRoute(RouteSettings settings, Widget child) {
    return MaterialPageRoute<dynamic>(
      settings: settings,
      builder: (context) {
        return child;
      },
    );
  }

  static PageRoute<dynamic> _buildAdminSettingsRoute(
    RouteSettings settings,
    Widget child,
  ) {
    return MaterialPageRoute<dynamic>(
      settings: settings,
      builder: (context) {
        return child;
      },
    );
  }
}
