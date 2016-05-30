part of sqljocky;

/// Use [ConnectionPool.getConnection] to get a connection to the database which
/// isn't released after each query. When you have finished with the connection
/// you must [release] it, otherwise it will never be available in the pool
/// again.
abstract class RetainedConnection extends QueriableConnection {
  /// Releases the connection back to the connection pool.
  Future release();

  bool get usingSSL;
}

class _RetainedConnectionImpl extends _RetainedConnectionBase
    implements RetainedConnection {
  _RetainedConnectionImpl._(cnx, pool) : super._(cnx, pool);

  Future release() {
    _checkReleased();
    _released = true;

    _cnx.inTransaction = false;
    _cnx.release();
    _pool._reuseConnectionForQueuedOperations(_cnx);
  }

  void _checkReleased() {
    if (_released) {
      throw new StateError("Connection has already been released");
    }
  }
}
