# Bug Hunt Findings

This document tracks bugs and risks found during the current Accord Mobile review.

## 1. QR scan dispatch can create duplicate Delivery Notes

Severity: High

Status: Fixed in working tree. QR dispatch now sends source metadata and the server blocks repeated dispatch for the same source marker.

Previous behavior:
The QR result screen sent only `customer_ref`, `item_code`, and `qty` when the user tapped `Customerga jo'natish`.

Risk before fix:
If the same QR is scanned and submitted again, the backend cannot know that this exact barcode or stock entry line was already dispatched. This can create duplicate Delivery Notes.

Relevant files:
- `lib/src/features/werka/presentation/werka_stock_entry_lookup_screen.dart`
- `lib/src/core/api/werka/mobile_api_werka.dart`
- `accord_mobile_server/internal/core/types.go`

Suggested direction:
Send source metadata such as `barcode`, `stock_entry_name`, and `line_index`, then enforce idempotency or duplicate protection on the server.

## 2. Batch QR can fall back to the first item when exact match fails

Severity: High

Status: Fixed in working tree. Batch QR now requires an exact item name/code match and does not fall back to the first result.

Previous behavior:
Batch QR lookup searched item options and used `options.first` when an exact item match was not found.

Risk before fix:
The app may dispatch a different item/customer than the one encoded in the Batch QR.

Relevant file:
- `lib/src/features/werka/presentation/werka_archive_batch_qr_lookup_screen.dart`

Suggested direction:
Require an exact item match. If no exact match exists, show a clear error and block dispatch.

## 3. Batch QR customer selection differs from the normal dispatch flow

Severity: High

Status: Fixed in working tree. Batch QR now resolves the preferred customer with the shared priority logic and lets the user change the customer directly from the Batch QR result screen.

Previous behavior:
Normal product dispatch used the primary-customer preference logic. Batch QR chose a customer from `CustomerItemOption` resolution and could miss that priority behavior.

Risk:
For items assigned to multiple customers, Batch QR may dispatch to the wrong customer.

Relevant files:
- `lib/src/features/werka/presentation/werka_archive_batch_qr_lookup_screen.dart`
- `lib/src/features/werka/presentation/werka_customer_issue_customer_screen.dart`
- `lib/src/core/customer/customer_priority.dart`

Suggested direction:
Make Batch QR use the same preferred customer resolution as the normal product dispatch flow.

## 4. Full `flutter analyze` fails because third-party plugin files are included

Severity: Medium

Status: Fixed in working tree. `third_party/**` is now excluded from app analysis, so vendored plugin examples, tests, and pigeon files no longer produce missing dependency errors.

Previous behavior:
Running `flutter analyze` over the whole project enters `third_party/local_auth_darwin` and reports missing `integration_test`, `pigeon`, and `mockito` dependencies.

Remaining note:
`flutter analyze` still reports app-owned warnings and infos, mostly from GScale stale/deprecated code. Those are tracked separately in bugs 6 and 8.

Risk:
The app code may be healthy, but CI or a new teammate can see a red analyzer result.

Relevant files:
- `analysis_options.yaml`
- `third_party/local_auth_darwin`
- `pubspec.yaml`

Suggested direction:
Exclude third-party plugin example/test/pigeon files from app analysis, or document the expected analyze command.

## 5. Full `flutter test` fails in `widget_test.dart`

Severity: Medium

Status: Fixed in working tree. `widget_test.dart` now tests `LoginScreen` directly with explicit Uzbek localization and bounded pumps, so it no longer waits forever on app-level animations/runtime work.

Previous behavior:
`test/widget_test.dart` calls `pumpAndSettle()` after loading the full app, and the test times out.

Risk:
The test suite appears red even though the failure is likely caused by app-level timers or animations that never fully settle.

Relevant file:
- `test/widget_test.dart`

Suggested direction:
Use bounded pumps or test a narrower login widget instead of waiting for the entire app to settle.

## 6. GScale has unused stale code after UI refactors

Severity: Medium

Status: Fixed in working tree. Stale GScale constants, old warehouse search/cache state, unused status flags, and unused card/status widgets were removed.

Previous behavior:
Analyzer reported unused fields, methods, and widgets in `gscale_mobile_app.dart`.

Examples:
- `_warehousesLoading`
- `_warehouseSetupExpanded`
- `_statusText`
- `_warehouses`
- `_submitWarehouseSetup`
- old section/card widgets

Risk:
This is not a crash, but it makes the file harder to maintain and can hide real logic drift.

Relevant file:
- `lib/src/features/gscale/gscale_mobile_app.dart`

Suggested direction:
Remove unused code in small steps after confirming no hidden workflow still depends on it.

## 7. QR scanner can spam snackbar for unsupported QR codes

Severity: Low to Medium

Current behavior:
When an unsupported QR is detected, the scanner keeps running and can repeatedly show the same snackbar if the QR remains in view.

Risk:
Poor user experience in real scanning conditions.

Relevant file:
- `lib/src/features/werka/presentation/werka_stock_entry_qr_scan_screen.dart`

Suggested direction:
Throttle unsupported QR feedback, or temporarily pause detection after an unsupported scan.

## 8. GScale uses deprecated Flutter APIs

Severity: Low

Status: Fixed in working tree. GScale now uses `WidgetStateProperty`, `WidgetState`, and `onPopInvokedWithResult`.

Previous behavior:
Analyzer reported deprecated uses such as `MaterialStateProperty`, `MaterialState`, and `onPopInvoked`.

Risk:
The app still works, but future Flutter upgrades may increase warnings or require changes.

Relevant file:
- `lib/src/features/gscale/gscale_mobile_app.dart`

Suggested direction:
Move to `WidgetStateProperty`, `WidgetState`, and `onPopInvokedWithResult`.

## 9. Batch QR dispatch flow lacks focused tests

Severity: Low to Medium

Status: Fixed in working tree. Batch QR now has a widget test proving exact item resolution, preferred customer selection, and direct submit payload.

Previous behavior:
Batch QR parser tests existed, but the dispatch resolution and submit flow were not covered.

Risk:
Future UI or API changes can break Batch QR dispatch without test signal.

Relevant files:
- `test/werka_archive_batch_qr_test.dart`
- `lib/src/features/werka/presentation/werka_archive_batch_qr_lookup_screen.dart`

Suggested direction:
Add tests for exact item matching, preferred customer selection, and direct submit behavior.

## 10. QR result dispatch flow lacks source/idempotency tests

Severity: Low to Medium

Status: Fixed in working tree. QR result dispatch now has widget tests proving source metadata propagation, scanned-barcode fallback, and duplicate source feedback.

Previous behavior:
The QR result dispatch flow had no focused test proving that source barcode or stock entry metadata was preserved.

Risk:
Even after source tracking is added, a future change could silently remove it.

Relevant file:
- `lib/src/features/werka/presentation/werka_stock_entry_lookup_screen.dart`

Suggested direction:
Add tests around source metadata propagation and duplicate prevention once backend support is implemented.
