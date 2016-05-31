part of sqljocky_impl;

abstract class _ConnectionHelpers {
  _releaseReuseThrow(_Connection cnx, dynamic e) {
    if (!(e is MySqlException)) {
      _removeConnection(cnx);
    }
    throw e;
  }

  _removeConnection(cnx);
}
