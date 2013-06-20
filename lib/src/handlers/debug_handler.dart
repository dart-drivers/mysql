part of sqljocky;

class _DebugHandler extends _Handler {
  _DebugHandler() {
    log = new Logger("DebugHandler");
  }
  
  Buffer createRequest() {
    var buffer = new Buffer(1);
    buffer.writeByte(COM_DEBUG);
    return buffer;
  }

  _HandlerResponse processResponse(Buffer response) => 
      new _HandlerResponse(finished: true, result: checkResponse(response));
}
