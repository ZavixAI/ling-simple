# Test layout rules

- Do not add new widget tests to `test/widget_test.dart`.
- Put new tests under the closest feature folder, for example:
  - `test/features/auth/presentation/`
  - `test/features/settings/presentation/`
  - `test/features/calendar/presentation/`
  - `test/features/chat/presentation/`
- If a test needs shared setup, extract a small helper under `test/support/` or a feature-local helper file instead of expanding `widget_test.dart`.
- Existing tests may be moved out of `widget_test.dart`; the file should shrink over time.
