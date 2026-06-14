import 'package:drift/drift.dart';

import 'package:ling/src/core/database/database_connection_io.dart'
    if (dart.library.js_interop) 'database_connection_web.dart';

QueryExecutor openDatabaseConnection() {
  return createDatabaseConnection();
}
