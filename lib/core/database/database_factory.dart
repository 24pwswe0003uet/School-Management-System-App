// Selects the platform-appropriate SQLite database factory at compile time.
export 'database_factory_stub.dart'
    if (dart.library.io) 'database_factory_io.dart'
    if (dart.library.js_interop) 'database_factory_web.dart';
