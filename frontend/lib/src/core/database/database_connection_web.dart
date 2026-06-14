import 'package:drift/drift.dart';
// ignore: deprecated_member_use
import 'package:drift/web.dart';

QueryExecutor createDatabaseConnection() {
  return WebDatabase('ling_app_db');
}
