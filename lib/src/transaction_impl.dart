part of sqljocky_impl;

class _TransactionImpl extends _RetainedConnectionBase implements Transaction {
  _TransactionImpl._(cnx, pool) : super._(cnx, pool);

  Future commit() async {
    _checkReleased();
    _released = true;

    var handler = new QueryStreamHandler("commit");
    var results = await _cnx.processHandler(handler);
    _cnx.inTransaction = false;
    _cnx.release();
    _pool._reuseConnectionForQueuedOperations(_cnx);
    return results;
  }

  Future rollback() async {
    _checkReleased();
    _released = true;

    var handler = new QueryStreamHandler("rollback");
    var results = await _cnx.processHandler(handler);
    _cnx.inTransaction = false;
    _cnx.release();
    _pool._reuseConnectionForQueuedOperations(_cnx);
    return results;
  }

  void _checkReleased() {
    if (_released) {
      throw new StateError("Transaction has already finished");
    }
  }
}
