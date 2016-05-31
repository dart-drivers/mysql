part of sqljocky;

class _TransactionPool extends _ConnectionPoolImpl {
  final _Connection cnx;

  _TransactionPool(this.cnx);

  Future<_Connection> _getConnection() => new Future.value(cnx);

  _removeConnection(_Connection cnx) {}
}
