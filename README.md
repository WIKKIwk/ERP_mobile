# Accord Mobile App

Accord Mobile App is the Flutter client for the Accord operational workflow on top of ERPNext. It is an Android-first application that connects four role-based experiences to the mobile backend and, through that backend, to ERPNext.

Main flow:

`mobile_app -> mobile_server -> ERPNext`

## Overview

The app supports these roles:

- `Supplier`
- `Werka`
- `Customer`
- `Admin`

The client is intentionally thin. It does not define business truth on its own. Its responsibility is to:

- authenticate users
- render role-specific flows
- call the mobile API
- manage session state, app lock, caches, notifications, and runtime resets
- keep role-local UI state consistent across screens

## Current Business Rules

These rules are important and reflect the current production-oriented architecture:

- `Delivery Note` is the source of truth for customer delivery state
- ERP custom fields, not comments, define business state
- comments are discussion and audit history only
- a role should read from one shared store instead of each screen owning its own copy of the same state
- logout must clear all session-scoped runtime state, not just the token
- release APKs must use the public domain backend, not `127.0.0.1` or `localhost`

Current `Delivery Note` state mapping:

- `accord_flow_state`
  - `0` = none
  - `1` = submitted
  - `2` = returned
- `accord_customer_state`
  - `0` = pending
  - `1` = confirmed
  - `2` = rejected
- `accord_customer_reason`
- `accord_delivery_actor`

Notes:

- `accord_delivery_actor` still exists as a `Data` field in the live ERP environment, even though it is used with integer semantics
- customer delivery comments can now be discussed through ERPNext `Delivery Note` comments while state truth remains in the ERP fields above

## Architecture

The app is organized into three main layers:

1. `Presentation`
   - screens
   - widgets
   - dock navigation
   - route-level UI interactions

2. `Core`
   - API client
   - session management
   - cache and persistence helpers
   - push and local notifications
   - security and app lock
   - localization
   - theme
   - network guard

3. `Shared models`
   - role types
   - dispatch and notification models
   - summaries and detail payloads
   - route arguments

Key entry files:

- `lib/main.dart`
- `lib/src/app/app.dart`
- `lib/src/app/app_router.dart`
- `lib/src/core/api/mobile_api.dart`
- `lib/src/features/shared/models/app_models.dart`

## App Startup

Startup flow:

1. `main.dart` loads:
   - local notifications
   - session
   - unread store
   - security controller
   - theme controller
   - locale controller
2. `ErpnextStockMobileApp` starts
3. `MaterialApp` is wrapped with:
   - `NetworkRequirementRuntime`
   - `NotificationRuntime`
   - `AppLockGate`
   - `DevicePreview` in supported non-release desktop/dev contexts
4. the initial route is always `/`
5. `AppEntryScreen` validates any saved local session before routing to a role home screen

## Session, Security, and Reset

`AppSession` stores the active token and `SessionProfile` in `SharedPreferences`.

When login succeeds:

- the session is stored
- the app resolves the destination route by role
- push token sync is triggered

When logout succeeds:

- the session is cleared
- role stores are reset
- unread and hidden notification state is cleared
- notification snapshots and caches are removed
- avatar cache is cleared
- last login credentials are removed

Relevant files:

- `lib/src/core/session/app_session.dart`
- `lib/src/core/session/app_runtime_reset.dart`
- `lib/src/features/auth/presentation/app_entry_screen.dart`
- `lib/src/core/api/mobile_api_auth_profile.dart`

## Role Flows

### Supplier

Supplier flow includes:

- home summary
- item selection and dispatch creation
- status breakdown and detail
- notifications and history
- detail views for receipt state and follow-up actions

Primary screens:

- `lib/src/features/supplier/presentation/supplier_home_screen.dart`
- `lib/src/features/supplier/presentation/supplier_notifications_screen.dart`
- `lib/src/features/supplier/presentation/supplier_recent_screen.dart`
- `lib/src/features/supplier/presentation/supplier_status_breakdown_screen.dart`
- `lib/src/features/supplier/presentation/supplier_status_detail_screen.dart`
- `lib/src/features/supplier/presentation/supplier_item_picker_screen.dart`
- `lib/src/features/supplier/presentation/supplier_qty_screen.dart`
- `lib/src/features/supplier/presentation/supplier_confirm_screen.dart`
- `lib/src/features/supplier/presentation/supplier_success_screen.dart`

### Werka

Werka flow includes:

- home summary
- pending receipts
- status breakdown and detail
- recent/history
- notifications
- supplier receipt confirmation and return flow
- unannounced supplier flow
- customer issue flow
- customer delivery discussion entry points

Primary screens:

- `lib/src/features/werka/presentation/werka_home_screen.dart`
- `lib/src/features/werka/presentation/werka_notifications_screen.dart`
- `lib/src/features/werka/presentation/werka_recent_screen.dart`
- `lib/src/features/werka/presentation/werka_status_breakdown_screen.dart`
- `lib/src/features/werka/presentation/werka_status_detail_screen.dart`
- `lib/src/features/werka/presentation/werka_detail_screen.dart`
- `lib/src/features/werka/presentation/werka_customer_delivery_detail_screen.dart`
- `lib/src/features/werka/presentation/werka_create_hub_screen.dart`
- `lib/src/features/werka/presentation/werka_unannounced_supplier_screen.dart`
- `lib/src/features/werka/presentation/werka_customer_issue_customer_screen.dart`
- `lib/src/features/werka/presentation/werka_success_screen.dart`

### Customer

Customer flow includes:

- home summary
- pending / confirmed / rejected states
- shipment detail
- approve / reject actions
- rejection with either a structured reason or a meaningful free-text reason
- discussion entry points for accepted and rejected delivery outcomes
- notifications

Primary screens:

- `lib/src/features/customer/presentation/customer_home_screen.dart`
- `lib/src/features/customer/presentation/customer_notifications_screen.dart`
- `lib/src/features/customer/presentation/customer_status_detail_screen.dart`
- `lib/src/features/customer/presentation/customer_delivery_detail_screen.dart`

### Admin

Admin flow includes:

- ERP settings
- supplier directory
- inactive / blocked supplier management
- supplier detail and item assignment
- customer detail
- item creation
- Werka info
- activity feed

Primary screens:

- `lib/src/features/admin/presentation/admin_home_screen.dart`
- `lib/src/features/admin/presentation/admin_activity_screen.dart`
- `lib/src/features/admin/presentation/admin_create_hub_screen.dart`
- `lib/src/features/admin/presentation/admin_settings_screen.dart`
- `lib/src/features/admin/presentation/admin_suppliers_screen.dart`
- `lib/src/features/admin/presentation/admin_inactive_suppliers_screen.dart`
- `lib/src/features/admin/presentation/admin_supplier_detail_screen.dart`
- `lib/src/features/admin/presentation/admin_customer_detail_screen.dart`
- `lib/src/features/admin/presentation/admin_item_create_screen.dart`
- `lib/src/features/admin/presentation/admin_supplier_create_screen.dart`
- `lib/src/features/admin/presentation/admin_customer_create_screen.dart`
- `lib/src/features/admin/presentation/admin_supplier_items_view_screen.dart`
- `lib/src/features/admin/presentation/admin_supplier_items_add_screen.dart`
- `lib/src/features/admin/presentation/admin_werka_screen.dart`

## Notifications and Discussion Threads

The app supports:

- unread and hidden notification state
- polling-based refresh
- FCM push token registration
- local notifications for surfaced dispatch changes
- ERP-visible discussion comments for delivery-note-backed customer response flows

Recent hardening work included:

- multi-device push token retention on the backend
- safer customer rejection validation
- delivery discussion entry points in Customer and Werka flows
- delivery-note-backed discussion comments routed to real ERPNext `Delivery Note` comments

Important principle:

- comments are audit and discussion history
- ERP custom fields remain the only business truth for state transitions

Relevant files:

- `lib/src/core/notifications/notification_runtime.dart`
- `lib/src/core/notifications/push_messaging_service.dart`
- `lib/src/core/notifications/local_notification_service.dart`
- `lib/src/features/shared/presentation/notification_detail_screen.dart`

## API Layer

`mobile_api.dart` groups role-based API calls into extension files.

Main API areas:

- auth and profile
- supplier summary/history/status/items/dispatch
- Werka summary/pending/history/status/confirm/create flows
- customer summary/history/status/detail/respond
- notification detail and comment APIs
- admin settings, directories, item creation, and activity

Primary files:

- `lib/src/core/api/mobile_api.dart`
- `lib/src/core/api/mobile_api_auth_profile.dart`
- `lib/src/core/api/mobile_api_supplier_notifications.dart`
- `lib/src/core/api/mobile_api_werka.dart`
- `lib/src/core/api/mobile_api_customer.dart`
- `lib/src/core/api/mobile_api_admin.dart`

## State Management

The app is moving toward a single-store-per-role model so that counts, previews, lists, and detail refreshes stay aligned.

Current role stores:

- `lib/src/features/supplier/state/supplier_store.dart`
- `lib/src/features/werka/state/werka_store.dart`
- `lib/src/features/customer/state/customer_store.dart`
- `lib/src/features/admin/state/admin_store.dart`

Runtime mutation helpers:

- `lib/src/core/notifications/customer_delivery_runtime_store.dart`
- `lib/src/core/notifications/supplier_runtime_store.dart`
- `lib/src/core/notifications/werka_runtime_store.dart`

## Development

Install dependencies:

```bash
flutter pub get
```

Run locally:

```bash
flutter run
```

Analyze:

```bash
flutter analyze
```

Test:

```bash
flutter test
```

## Release APK

Release APKs must target the public domain backend.

Build command:

```bash
make apk-domain APK_NAME=accord.apk
```

Output:

`build/app/outputs/flutter-apk/accord.apk`

Current release backend domain:

`https://core.wspace.sbs`

## Operational Notes

- Do not ship release APKs pointing to `127.0.0.1` or `localhost`
- Do not use comments as business truth
- Keep ERP-side state changes in the ERP custom fields and treat comments as discussion only
- Prefer extending behavior through API and custom apps rather than modifying ERPNext core

## Related Repositories

- mobile backend: `../mobile_server`
- ERP custom app: `/home/wikki/storage/local.git/erpnext_n1/erp/apps/accord_state_core`

## Status

The app currently includes:

- hardened session restore and logout reset
- multi-device push token support on the backend side
- structured customer rejection UX
- delivery discussion entry points for Customer and Werka

The main remaining product/architecture focus is continued cleanup of role-store consistency and history/source alignment.
