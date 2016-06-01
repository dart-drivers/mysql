part of sqljocky_impl;

abstract class _RetainedConnectionBase extends Object
    with _ConnectionHelpers
    implements QueriableConnection {
  _Connection _cnx;
  _ConnectionPoolImpl _pool;
  bool _released;

  _RetainedConnectionBase._(this._cnx, this._pool) : _released = false;

  Future<Results> query(String sql) {
    _checkReleased();
    var handler = new QueryStreamHandler(sql);
    return _cnx.processHandler(handler);
  }

  Future<Query> prepare(String sql) async {
    _checkReleased();
    var query =
        new _QueryImpl._forTransaction(new _TransactionPool(_cnx), _cnx, sql);
    await query._prepare(true);
    return new Future.value(query);
  }

  Future<Results> prepareExecute(String sql, List parameters) async {
    _checkReleased();
    var query = await prepare(sql);
    var results = await query.execute(parameters);
    //TODO is it right to close here? Query might still be running
    query.close();
    return new Future.value(results);
  }

  void _checkReleased();

  _removeConnection(_Connection cnx) {
    _pool._removeConnection(cnx);
  }

  bool get usingSSL => _cnx.usingSSL;
}
