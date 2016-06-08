part of sqljocky_impl;

class _ConnectionPoolImpl extends Object
    with _ConnectionHelpers
    implements ConnectionPool {
  final Logger _log;

  final String _host;
  final int _port;
  final String _user;
  final String _password;
  final String _db;
  final bool _useCompression = false;
  final bool _useSSL;
  final int _maxPacketSize;
  int _max;

  /// The pool maintains a queue of connection requests. When a connection completes, if there
  /// is a connection in the queue then it is 'activated' - that is, the future returned
  /// by _getConnection() completes.
  final Queue<Completer<Connection>> _pendingConnections;
  /*
   * If you need a particular connection, put an entry in _requestedConnections. As soon as
   * that connection is free then the completer completes. _requestedConnections is
   * checked before _pendingConnections.
   */
  final Map<Connection, Queue<Completer>> _requestedConnections;
  final List<Connection> _pool;

  _ConnectionPoolImpl(
      {String host: 'localhost',
      int port: 3306,
      String user,
      String password,
      String db,
      int max: 5,
      int maxPacketSize: 16 * 1024 * 1024,
//      bool useCompression: false,
      bool useSSL: false})
      : _pendingConnections = new Queue<Completer<Connection>>(),
        _requestedConnections = new Map<Connection, Queue<Completer>>(),
        _pool = new List<Connection>(),
        _host = host,
        _port = port,
        _user = user,
        _password = password,
        _db = db,
        _maxPacketSize = maxPacketSize,
        _max = max,
//  _useCompression = useCompression,
        _useSSL = useSSL,
        _log = new Logger("ConnectionPool");

  Future<Connection> getConnectionInternal() {
    _log.finest("Getting a connection");
    var c = new Completer<Connection>();

    if (_log.isLoggable(Level.FINEST)) {
      var inUseCount =
          _pool.fold(0, (value, cnx) => cnx.inUse ? value + 1 : value);
      _log.finest("Number of in-use connections: $inUseCount");
    }

    var cnx = _pool.firstWhere((aConnection) => !aConnection.inUse,
        orElse: () => null);
    if (cnx != null) {
      _log.finest("Using open pooled cnx#${cnx.number}");
      cnx.use();
      c.complete(cnx);
    } else if (_pool.length < _max) {
      _log.finest("Creating new pooled cnx#${_pool.length}");
      _createConnection(c);
    } else {
      _log.finest("Waiting for an available connection");
      _pendingConnections.add(c);
    }
    return c.future;
  }

  _createConnection(Completer c) async {
    var cnx = new Connection((cnx) {
      _removeConnection(cnx);
    }, (cnx) {
      _reuseConnectionForQueuedOperations(cnx);
    }, _pool.length, _maxPacketSize);
    cnx.use();
    cnx.autoRelease = false;
    _pool.add(cnx);
    try {
      await cnx.connect(
          host: _host,
          port: _port,
          user: _user,
          password: _password,
          db: _db,
          useCompression: _useCompression,
          useSSL: _useSSL);
      cnx.autoRelease = true;
      _log.finest("Logged in on cnx#${cnx.number}");
      c.complete(cnx);
    } catch (e, st) {
      if (!(e is MySqlException)) {
        _removeConnection(cnx);
      }
      c.completeError(e, st);
    }
  }

  _removeConnection(Connection cnx) {
    _pool.remove(cnx);
  }

  /// Attempts to continue using a connection. If the connection isn't managed
  /// by this pool, or if the connection is already in use, nothing happens.
  ///
  /// If there are operations which have been queued in this pool, starts
  /// to execute that operation.
  ///
  /// Otherwise, nothing happens.
  _reuseConnectionForQueuedOperations(Connection cnx) {
    cnx.release();
    if (!_pool.contains(cnx)) {
      _log.warning("reuseConnection called for unmanaged connection");
      return;
    }

    if (cnx.inUse) {
      _log.finest("cnx#${cnx.number} already reused");
      return;
    }

    if (_requestedConnections.containsKey(cnx) &&
        _requestedConnections[cnx].length > 0) {
      _log.finest("Reusing cnx#${cnx.number} for a requested operation");
      var c = _requestedConnections[cnx].removeFirst();
      cnx.use();
      c.complete(cnx);
      return;
    }

    if (_pendingConnections.length > 0) {
      _log.finest("Reusing cnx#${cnx.number} for a queued operation");
      var c = _pendingConnections.removeFirst();
      cnx.use();
      c.complete(cnx);
    }
  }

// dangerous - would need to switch all connections
//  Future useDatabase(String dbName) {
//    return _getConnection()
//    .then((cnx) {
//      var handler = new _UseDbHandler(dbName);
//      return cnx.processHandler(handler);
//    });
//  }

  void closeConnectionsNow() {
    for (Connection cnx in _pool.toList()) {
      if (cnx != null) {
        cnx.close();
      }
    }
  }

  void closeConnectionsWhenNotInUse() {
    for (Connection cnx in _pool.toList()) {
      if (cnx != null) {
        cnx.closeWhenFinished();
      }
    }
  }

  Future<Results> query(String sql) async {
    _log.info("Running query: $sql");

    var cnx = await getConnectionInternal();
    _log.fine("Got cnx#${cnx.number} for query");
    try {
      var results = await cnx.processHandler(new QueryStreamHandler(sql));
      _log.fine("Got query results on #${cnx.number} for: $sql");
      return results;
    } catch (e) {
      _releaseReuseThrow(cnx, e);
    }
  }

  Future ping() async {
    _log.info("Pinging server");

    var cnx = await getConnectionInternal();
    var x = await cnx.processHandler(new _PingHandler());
    _log.fine("Pinged");
    return x;
  }

  Future debug() async {
    _log.info("Sending debug message");

    var cnx = await getConnectionInternal();
    try {
      var x = await cnx.processHandler(new _DebugHandler());
      _log.fine("Message sent");
      return x;
    } catch (e) {
      _releaseReuseThrow(cnx, e);
    }
  }

  // Close a prepared query on all connections which have this query.
  // This may take some time if it has to wait a long time for a
  // connection to become free.
  _closeQuery(_QueryImpl q, bool retain) async {
    _log.finest("Closing query: ${q.sql}");
    var thePool = new List<Connection>();
    thePool.addAll(_pool); // prevent concurrent modification
    for (var cnx in thePool) {
      var preparedQuery = cnx.removePreparedQueryFromCache(q.sql);
      if (preparedQuery != null) {
        _log.finest("Connection not ready");
        await _waitUntilReady(cnx);
        _log.finest("Connection ready - closing query: ${q.sql}");
        var handler =
            new _CloseStatementHandler(preparedQuery.statementHandlerId);
        cnx.autoRelease = !retain;
        cnx.processHandler(handler, noResponse: true);
      }
    }
  }

  /// The future returned by [_waitUntilReady] fires when the connection is next available
  /// to be used.
  Future<Connection> _waitUntilReady(Connection cnx) {
    var c = new Completer<Connection>();
    if (!cnx.inUse) {
      // connection isn't in use, so use it straight away
      cnx.use();
      c.complete(cnx);
    } else {
      // Connection is in use, so request we get it the next time it's available.
      if (!_requestedConnections.containsKey(cnx)) {
        _requestedConnections[cnx] = new Queue<Completer>();
      }
      _requestedConnections[cnx].add(c);
    }
    return c.future;
  }

  Future<Query> prepare(String sql) async {
    var query = new _QueryImpl._internal(this, sql);
    await query._prepare(false);
    _log.info("Got prepared query");
    return query;
  }

  Future<Transaction> startTransaction({bool consistent: false}) async {
    _log.info("Starting transaction");

    var cnx = await getConnectionInternal();
    cnx.inTransaction = true;
    var sql;
    if (consistent) {
      sql = "start transaction with consistent snapshot";
    } else {
      sql = "start transaction";
    }
    try {
      await cnx.processHandler(new QueryStreamHandler(sql));
      _log.fine("Transaction started on cnx#${cnx.number}");
      return new _TransactionImpl._(cnx, this);
    } catch (e) {
      _releaseReuseThrow(cnx, e);
    }
  }

  Future<RetainedConnection> getConnection() async {
    _log.info("Retaining connection");

    var cnx = await getConnectionInternal();
    cnx.inTransaction = true;
    return new _RetainedConnectionImpl._(cnx, this);
  }

  Future<Results> prepareExecute(String sql, List parameters) async {
    var query = await prepare(sql);
    return query.execute(parameters);
  }

//  dynamic fieldList(String table, [String column]);
//  dynamic refresh(bool grant, bool log, bool tables, bool hosts,
//                  bool status, bool threads, bool slave, bool master);
//  dynamic shutdown(bool def, bool waitConnections, bool waitTransactions,
//                   bool waitUpdates, bool waitAllBuffers,
//                   bool waitCriticalBuffers, bool killQuery, bool killConnection);
//  dynamic statistics();
//  dynamic processInfo();
//  dynamic processKill(int id);
//  dynamic changeUser(String user, String password, [String db]);
//  dynamic binlogDump(options);
//  dynamic registerSlave(options);
//  dynamic setOptions(int option);
}
