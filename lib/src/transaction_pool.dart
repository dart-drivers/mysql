part of sqljocky_impl;

class _TransactionPool extends _ConnectionPoolImpl {
  final Connection cnx;

  _TransactionPool(this.cnx);

  Future<Connection> _getConnection() => new Future.value(cnx);

  _removeConnection(Connection cnx) {}
}
