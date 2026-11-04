# Campus Supply Desk (In-Class 12, Intro to Firebase, Variant B)

Undergraduate submission. A Flutter product manager backed by the Cloud Firestore collection `campus_products`.

## Features
* Create, live read (`StreamBuilder` on `snapshots()`), edit, and delete products
* Delete targets the selected **document ID**, with a confirmation dialog and a visible error on `FirebaseException`
* Case insensitive **substring** search as you type (`book` matches *Maple Notebook* and *maple Bookmark*)
* Optional min/max price filter, inclusive, combined with search; **Reset** clears everything
* Validation: trimmed nonempty name; price must be a plain, finite, nonnegative number (0 is valid; negative, NaN, Infinity, `$`, commas rejected); min > max rejected
* Status line shows how many products match and whether the snapshot came from cache or server (`isFromCache`, `hasPendingWrites`)

Filtering and validation live in `lib/product_logic.dart` (no Flutter/Firebase imports) and are unit tested in `test/product_logic_test.dart` against the five Variant B fixtures (tests T4, T5, T6).

## Schema (`campus_products`)
| Field | Type | Example |
|---|---|---|
| name | string | Maple Notebook |
| price | number | 9.75 |

Fixtures: Maple Notebook 9.75, Campus Pen Set 16.50, Study Lamp 29.00, maple Bookmark 4.25, Welcome Sample 0.00.

## Run
```bash
# 1. regenerate platform folders (android/ etc.)
flutter create --project-name my_product_app --platforms=android .
flutter pub get

# 2. connect your own Firebase project (overwrites lib/firebase_options.dart)
dart pub global activate flutterfire_cli
firebase login
flutterfire configure --platforms=android     # Windows: flutterfire.bat configure --platforms=android

# 3. check and run
flutter analyze
flutter test
flutter run
```
In Firebase Console create a Firestore database (Standard edition, `(default)`, test mode for this class only), then add the five fixtures to `campus_products` with **numeric** prices.

## Verified results (Android emulator, Pixel 5 AVD)
* `flutter test`: 29 tests passed. `flutter analyze`: no issues.
* T1 to T8 were run on the emulator against Firestore project `campus-supply-desk-pine`; screenshots and the full table are in the Word report.

## Firebase configuration
`lib/firebase_options.dart` in this repo is a placeholder on purpose. The project's Firestore is in test mode for the lab, so its client config is kept out of the public repo; regenerate yours with `flutterfire configure --platforms=android`. No credentials, tokens, or service account keys are committed.
