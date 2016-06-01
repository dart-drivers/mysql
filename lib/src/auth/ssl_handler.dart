part of sqljocky_impl;

class _SSLHandler extends _Handler {
  final int clientFlags;
  final int maxPacketSize;
  final int characterSet;
  final _Handler _handler;

  _Handler get nextHandler => _handler;

  _SSLHandler(this.clientFlags, this.maxPacketSize, this.characterSet,
      this._handler) {
    log = new Logger("SSLHandler");
  }

  Buffer createRequest() {
    var buffer = new Buffer(32);
    buffer.seekWrite(0);
    buffer.writeUint32(clientFlags);
    buffer.writeUint32(maxPacketSize);
    buffer.writeByte(characterSet);
    buffer.fill(23, 0);

    return buffer;
  }
}
