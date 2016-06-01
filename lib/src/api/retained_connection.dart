part of sqljocky_impl;

/// Use [ConnectionPool.getConnection] to get a connection to the database which
/// isn't released after each query. When you have finished with the connection
/// you must [release] it, otherwise it will never be available in the pool
/// again.
abstract class RetainedConnection extends QueriableConnection {
  /// Releases the connection back to the connection pool.
  void release();

  bool get usingSSL;
}
