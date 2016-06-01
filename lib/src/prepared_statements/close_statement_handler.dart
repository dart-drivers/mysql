part of sqljocky_impl;

class _CloseStatementHandler extends _Handler {
  final int _handle;

  _CloseStatementHandler(this._handle) {
    log = new Logger("CloseStatementHandler");
  }

  Buffer createRequest() {
    var buffer = new Buffer(5);
    buffer.writeByte(COM_STMT_CLOSE);
    buffer.writeUint32(_handle);
    return buffer;
  }
}
