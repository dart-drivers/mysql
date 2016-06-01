part of sqljocky_impl;

class AuthHandler extends _Handler {
  final String username;
  final String password;
  final String db;
  final List<int> scrambleBuffer;
  final int clientFlags;
  final int maxPacketSize;
  final int characterSet;
  final bool _ssl;

  AuthHandler(this.username, this.password, this.db, this.scrambleBuffer,
      this.clientFlags, this.maxPacketSize, this.characterSet,
      {bool ssl: false})
      : this._ssl = false {
    log = new Logger("AuthHandler");
  }

  List<int> getHash() {
    List<int> hash;
    if (password == null) {
      hash = <int>[];
    } else {
      var hashedPassword = sha1.convert(UTF8.encode(password)).bytes;
      var doubleHashedPassword = sha1.convert(hashedPassword).bytes;
      var hashedSaltedPassword = sha1
          .convert([]..addAll(scrambleBuffer)..addAll(doubleHashedPassword))
          .bytes;

      hash = new List<int>(hashedSaltedPassword.length);
      for (var i = 0; i < hash.length; i++) {
        hash[i] = hashedSaltedPassword[i] ^ hashedPassword[i];
      }
    }
    return hash;
  }

  Buffer createRequest() {
    // calculate the mysql password hash
    var hash = getHash();

    var encodedUsername = username == null ? [] : UTF8.encode(username);
    var encodedDb;

    var size = hash.length + encodedUsername.length + 2 + 32;
    var newClientFlags = clientFlags;
    if (db != null) {
      encodedDb = UTF8.encode(db);
      size += encodedDb.length + 1;
      newClientFlags |= CLIENT_CONNECT_WITH_DB;
    }

    var buffer = new Buffer(size);
    buffer.seekWrite(0);
    buffer.writeUint32(newClientFlags);
    buffer.writeUint32(maxPacketSize);
    buffer.writeByte(characterSet);
    buffer.fill(23, 0);
    buffer.writeNullTerminatedList(encodedUsername);
    buffer.writeByte(hash.length);
    buffer.writeList(hash);

    if (db != null) {
      buffer.writeNullTerminatedList(encodedDb);
    }

    return buffer;
  }
}
