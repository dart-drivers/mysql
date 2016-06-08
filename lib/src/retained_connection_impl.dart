part of sqljocky_impl;

class _RetainedConnectionImpl extends _RetainedConnectionBase
    implements RetainedConnection {
  _RetainedConnectionImpl._(cnx, pool) : super._(cnx, pool);

  void release() {
    _checkReleased();
    _released = true;

    _cnx.release();
    _pool._reuseConnectionForQueuedOperations(_cnx);
  }

  void _checkReleased() {
    if (_released) {
      throw new StateError("Connection has already been released");
    }
  }
}
