library sqljocky.handshake_handler_test;

import 'package:sqljocky2/constants.dart';
import 'package:sqljocky2/src/auth/auth_handler.dart';
import 'package:sqljocky2/src/auth/character_set.dart';
import 'package:sqljocky2/src/auth/handshake_handler.dart';
import 'package:sqljocky2/src/auth/ssl_handler.dart';
import 'package:sqljocky2/src/buffer.dart';
import 'package:sqljocky2/src/handlers/handler.dart';
import 'package:sqljocky2/src/mysql_client_error.dart';

import 'package:test/test.dart';

const int MAX_PACKET_SIZE = 16 * 1024 * 1024;

Buffer _createHandshake(protocolVersion, serverVersion, threadId,
    scrambleBuffer, serverCapabilities,
    [serverLanguage,
    serverStatus,
    serverCapabilities2,
    scrambleLength,
    scrambleBuffer2,
    pluginName,
    pluginNameNull]) {
  var length = 1 + serverVersion.length + 1 + 4 + 8 + 1 + 2;
  if (serverLanguage != null) {
    length += 1 + 2 + 2 + 1 + 10;
    if (scrambleBuffer2 != null) {
      length += scrambleBuffer2.length + 1;
    }
    if (pluginName != null) {
      length += pluginName.length;
      if (pluginNameNull) {
        length++;
      }
    }
  }

  var response = new Buffer(length);
  response.writeByte(protocolVersion);
  response.writeNullTerminatedList(serverVersion.codeUnits);
  response.writeInt32(threadId);
  response.writeList(scrambleBuffer.codeUnits);
  response.writeByte(0);
  response.writeInt16(serverCapabilities);
  if (serverLanguage != null) {
    response.writeByte(serverLanguage);
    response.writeInt16(serverStatus);
    response.writeInt16(serverCapabilities2);
    response.writeByte(scrambleLength);
    response.fill(10, 0);
    if (scrambleBuffer2 != null) {
      response.writeNullTerminatedList(scrambleBuffer2.codeUnits);
    }
    if (pluginName != null) {
      response.writeList(pluginName.codeUnits);
      if (pluginNameNull) {
        response.writeByte(0);
      }
    }
  }
  return response;
}

void main() {
  group('HandshakeHandler._readResponseBuffer', () {
    test('throws if handshake protocol is not 10', () {
      var handler = new HandshakeHandler("", "", MAX_PACKET_SIZE);
      var response = new Buffer.fromList([9]);
      expect(() {
        handler.readResponseBuffer(response);
      }, throwsA(new isInstanceOf<MySqlClientError>()));
    });

    test('set values and does not throw if handshake protocol is 10', () {
      var user = "bob";
      var password = "password";
      var db = "db";
      var handler =
          new HandshakeHandler(user, password, MAX_PACKET_SIZE, db, true, true);
      var serverVersion = "version 1";
      var threadId = 123882394;
      var serverLanguage = 9;
      var serverStatus = 999;
      var serverCapabilities1 = CLIENT_PROTOCOL_41 | CLIENT_SECURE_CONNECTION;
      var serverCapabilities2 = 0;
      var scrambleBuffer1 = "abcdefgh";
      var scrambleBuffer2 = "ijklmnopqrstuvwxyz";
      var scrambleLength = scrambleBuffer1.length + scrambleBuffer2.length + 1;
      var responseBuffer = _createHandshake(
          10,
          serverVersion,
          threadId,
          scrambleBuffer1,
          serverCapabilities1,
          serverLanguage,
          serverStatus,
          serverCapabilities2,
          scrambleLength,
          scrambleBuffer2);
      handler.readResponseBuffer(responseBuffer);

      expect(handler.serverVersion, equals(serverVersion));
      expect(handler.threadId, equals(threadId));
      expect(handler.serverLanguage, equals(serverLanguage));
      expect(handler.serverStatus, equals(serverStatus));
      expect(handler.serverCapabilities, equals(serverCapabilities1));
      expect(handler.scrambleLength, equals(scrambleLength));
      expect(handler.scrambleBuffer,
          equals((scrambleBuffer1 + scrambleBuffer2).codeUnits));
    });

    test('should cope with no data past first capability flags', () {
      var serverVersion = "version 1";
      var scrambleBuffer1 = "abcdefgh";
      var threadId = 123882394;
      var serverCapabilities = CLIENT_PROTOCOL_41 | CLIENT_SECURE_CONNECTION;

      var responseBuffer = _createHandshake(
          10, serverVersion, threadId, scrambleBuffer1, serverCapabilities);

      var handler = new HandshakeHandler("", "", MAX_PACKET_SIZE);
      handler.readResponseBuffer(responseBuffer);

      expect(handler.serverVersion, equals(serverVersion));
      expect(handler.threadId, equals(threadId));
      expect(handler.serverCapabilities, equals(serverCapabilities));
      expect(handler.serverLanguage, equals(null));
      expect(handler.serverStatus, equals(null));
    });

    test('should read plugin name', () {
      var user = "bob";
      var password = "password";
      var db = "db";
      var handler =
          new HandshakeHandler(user, password, MAX_PACKET_SIZE, db, true, true);
      var serverVersion = "version 1";
      var threadId = 123882394;
      var serverLanguage = 9;
      var serverStatus = 999;
      var serverCapabilities1 = CLIENT_PROTOCOL_41 | CLIENT_SECURE_CONNECTION;
      var serverCapabilities2 = CLIENT_PLUGIN_AUTH >> 0x10;
      var scrambleBuffer1 = "abcdefgh";
      var scrambleBuffer2 = "ijklmnopqrstuvwxyz";
      var scrambleLength = scrambleBuffer1.length + scrambleBuffer2.length + 1;
      var pluginName = "plugin name";
      var responseBuffer = _createHandshake(
          10,
          serverVersion,
          threadId,
          scrambleBuffer1,
          serverCapabilities1,
          serverLanguage,
          serverStatus,
          serverCapabilities2,
          scrambleLength,
          scrambleBuffer2,
          pluginName,
          false);
      handler.readResponseBuffer(responseBuffer);

      expect(handler.pluginName, equals(pluginName));
    });

    test('should read plugin name with null', () {
      var user = "bob";
      var password = "password";
      var db = "db";
      var handler =
          new HandshakeHandler(user, password, MAX_PACKET_SIZE, db, true, true);
      var serverVersion = "version 1";
      var threadId = 123882394;
      var serverLanguage = 9;
      var serverStatus = 999;
      var serverCapabilities1 = CLIENT_PROTOCOL_41 | CLIENT_SECURE_CONNECTION;
      var serverCapabilities2 = CLIENT_PLUGIN_AUTH >> 0x10;
      var scrambleBuffer1 = "abcdefgh";
      var scrambleBuffer2 = "ijklmnopqrstuvwxyz";
      var scrambleLength = scrambleBuffer1.length + scrambleBuffer2.length + 1;
      var pluginName = "plugin name";
      var responseBuffer = _createHandshake(
          10,
          serverVersion,
          threadId,
          scrambleBuffer1,
          serverCapabilities1,
          serverLanguage,
          serverStatus,
          serverCapabilities2,
          scrambleLength,
          scrambleBuffer2,
          pluginName,
          true);
      handler.readResponseBuffer(responseBuffer);

      expect(handler.pluginName, equals(pluginName));
    });

    test('should read buffer without scramble data', () {
      var user = "bob";
      var password = "password";
      var db = "db";
      var handler =
          new HandshakeHandler(user, password, MAX_PACKET_SIZE, db, true, true);
      var serverVersion = "version 1";
      var threadId = 123882394;
      var serverLanguage = 9;
      var serverStatus = 999;
      var serverCapabilities1 = CLIENT_PROTOCOL_41;
      var serverCapabilities2 = CLIENT_PLUGIN_AUTH >> 0x10;
      var scrambleBuffer1 = "abcdefgh";
      var scrambleBuffer2 = null;
      var scrambleLength = scrambleBuffer1.length;
      var pluginName = "plugin name";
      var responseBuffer = _createHandshake(
          10,
          serverVersion,
          threadId,
          scrambleBuffer1,
          serverCapabilities1,
          serverLanguage,
          serverStatus,
          serverCapabilities2,
          scrambleLength,
          scrambleBuffer2,
          pluginName,
          true);
      handler.readResponseBuffer(responseBuffer);

      expect(handler.pluginName, equals(pluginName));
    });

    test('should read buffer with short scramble data length', () {
      var user = "bob";
      var password = "password";
      var db = "db";
      var handler =
          new HandshakeHandler(user, password, MAX_PACKET_SIZE, db, true, true);
      var serverVersion = "version 1";
      var threadId = 123882394;
      var serverLanguage = 9;
      var serverStatus = 999;
      var serverCapabilities1 = CLIENT_PROTOCOL_41 | CLIENT_SECURE_CONNECTION;
      var serverCapabilities2 = CLIENT_PLUGIN_AUTH >> 0x10;
      var scrambleBuffer1 = "abcdefgh";
      var scrambleBuffer2 = "ijklmnopqrst";
      var scrambleLength = 5;
      var pluginName = "plugin name";
      var responseBuffer = _createHandshake(
          10,
          serverVersion,
          threadId,
          scrambleBuffer1,
          serverCapabilities1,
          serverLanguage,
          serverStatus,
          serverCapabilities2,
          scrambleLength,
          scrambleBuffer2,
          pluginName,
          true);
      handler.readResponseBuffer(responseBuffer);

      expect(handler.pluginName, equals(pluginName));
    });
  });

  group('HandshakeHandler.processResponse', () {
    test('throws if server protocol is not 4.1', () {
      var handler = new HandshakeHandler("", "", MAX_PACKET_SIZE);
      var response = _createHandshake(
          10, "version 1", 123, "abcdefgh", 0, 0, 0, 0, 0, "buffer");
      expect(() {
        handler.processResponse(response);
      }, throwsA(new isInstanceOf<MySqlClientError>()));
    });

    test('works when plugin name is not set', () {
      var user = "bob";
      var password = "password";
      var db = "db";
      var handler =
          new HandshakeHandler(user, password, MAX_PACKET_SIZE, db, true, true);
      var serverVersion = "version 1";
      var threadId = 123882394;
      var serverLanguage = 9;
      var serverStatus = 999;
      var serverCapabilities1 = CLIENT_PROTOCOL_41 | CLIENT_SECURE_CONNECTION;
      var serverCapabilities2 = 0;
      var scrambleBuffer1 = "abcdefgh";
      var scrambleBuffer2 = "ijklmnopqrstuvwxyz";
      var scrambleLength = scrambleBuffer1.length + scrambleBuffer2.length + 1;
      var responseBuffer = _createHandshake(
          10,
          serverVersion,
          threadId,
          scrambleBuffer1,
          serverCapabilities1,
          serverLanguage,
          serverStatus,
          serverCapabilities2,
          scrambleLength,
          scrambleBuffer2);
      var response = handler.processResponse(responseBuffer);

      expect(handler.useCompression, isFalse);
      expect(handler.useSSL, isFalse);

      expect(response, new isInstanceOf<HandlerResponse>());
      expect(response.nextHandler, new isInstanceOf<AuthHandler>());

      int clientFlags = CLIENT_PROTOCOL_41 |
          CLIENT_LONG_PASSWORD |
          CLIENT_LONG_FLAG |
          CLIENT_TRANSACTIONS |
          CLIENT_SECURE_CONNECTION;

      AuthHandler authHandler = response.nextHandler;
      expect(authHandler.characterSet, equals(CharacterSet.UTF8));
      expect(authHandler.username, equals(user));
      expect(authHandler.password, equals(password));
      expect(authHandler.scrambleBuffer,
          equals((scrambleBuffer1 + scrambleBuffer2).codeUnits));
      expect(authHandler.db, equals(db));
      expect(authHandler.clientFlags, equals(clientFlags));
      expect(authHandler.maxPacketSize, equals(MAX_PACKET_SIZE));
    });

    test('works when plugin name is set', () {
      var user = "bob";
      var password = "password";
      var db = "db";
      var handler =
          new HandshakeHandler(user, password, MAX_PACKET_SIZE, db, true, true);
      var serverVersion = "version 1";
      var threadId = 123882394;
      var serverLanguage = 9;
      var serverStatus = 999;
      var serverCapabilities1 = CLIENT_PROTOCOL_41 | CLIENT_SECURE_CONNECTION;
      var serverCapabilities2 = 0;
      var scrambleBuffer1 = "abcdefgh";
      var scrambleBuffer2 = "ijklmnopqrstuvwxyz";
      var scrambleLength = scrambleBuffer1.length + scrambleBuffer2.length + 1;
      var responseBuffer = _createHandshake(
          10,
          serverVersion,
          threadId,
          scrambleBuffer1,
          serverCapabilities1,
          serverLanguage,
          serverStatus,
          serverCapabilities2,
          scrambleLength,
          scrambleBuffer2,
          HandshakeHandler.MYSQL_NATIVE_PASSWORD,
          true);
      var response = handler.processResponse(responseBuffer);

      expect(handler.useCompression, isFalse);
      expect(handler.useSSL, isFalse);

      expect(response, new isInstanceOf<HandlerResponse>());
      expect(response.nextHandler, new isInstanceOf<AuthHandler>());

      AuthHandler authHandler = response.nextHandler;
      expect(authHandler.username, equals(user));
      expect(authHandler.password, equals(password));
      expect(authHandler.scrambleBuffer,
          equals((scrambleBuffer1 + scrambleBuffer2).codeUnits));
      expect(authHandler.db, equals(db));
    });

    test('throws if old password authentication is requested', () {
      var serverVersion = "version 1";
      var scrambleBuffer1 = "abcdefgh";
      var threadId = 123882394;
      var serverCapabilities = CLIENT_PROTOCOL_41;

      var responseBuffer = _createHandshake(
          10, serverVersion, threadId, scrambleBuffer1, serverCapabilities);

      var handler = new HandshakeHandler("", "", MAX_PACKET_SIZE);
      expect(() {
        handler.processResponse(responseBuffer);
      }, throwsA(new isInstanceOf<MySqlClientError>()));
    });

    test('throws if plugin is set and is not mysql_native_password', () {
      var user = "bob";
      var password = "password";
      var db = "db";
      var handler =
          new HandshakeHandler(user, password, MAX_PACKET_SIZE, db, true, true);
      var serverVersion = "version 1";
      var threadId = 123882394;
      var serverLanguage = 9;
      var serverStatus = 999;
      var serverCapabilities1 = CLIENT_PROTOCOL_41 | CLIENT_SECURE_CONNECTION;
      var serverCapabilities2 = CLIENT_PLUGIN_AUTH >> 0x10;
      var scrambleBuffer1 = "abcdefgh";
      var scrambleBuffer2 = "ijklmnopqrstuvwxyz";
      var scrambleLength = scrambleBuffer1.length + scrambleBuffer2.length + 1;
      var responseBuffer = _createHandshake(
          10,
          serverVersion,
          threadId,
          scrambleBuffer1,
          serverCapabilities1,
          serverLanguage,
          serverStatus,
          serverCapabilities2,
          scrambleLength,
          scrambleBuffer2,
          "some_random_plugin",
          true);

      expect(() {
        handler.processResponse(responseBuffer);
      }, throwsA(new isInstanceOf<MySqlClientError>()));
    });

    test('works when ssl requested', () {
      var user = "bob";
      var password = "password";
      var db = "db";
      var handler =
          new HandshakeHandler(user, password, MAX_PACKET_SIZE, db, true, true);
      var serverVersion = "version 1";
      var threadId = 123882394;
      var serverLanguage = 9;
      var serverStatus = 999;
      var serverCapabilities1 =
          CLIENT_PROTOCOL_41 | CLIENT_SECURE_CONNECTION | CLIENT_SSL;
      var serverCapabilities2 = 0;
      var scrambleBuffer1 = "abcdefgh";
      var scrambleBuffer2 = "ijklmnopqrstuvwxyz";
      var scrambleLength = scrambleBuffer1.length + scrambleBuffer2.length + 1;
      var responseBuffer = _createHandshake(
          10,
          serverVersion,
          threadId,
          scrambleBuffer1,
          serverCapabilities1,
          serverLanguage,
          serverStatus,
          serverCapabilities2,
          scrambleLength,
          scrambleBuffer2);
      var response = handler.processResponse(responseBuffer);

      expect(handler.useCompression, isFalse);
      expect(handler.useSSL, isTrue);

      expect(response, new isInstanceOf<HandlerResponse>());
      expect(response.nextHandler, new isInstanceOf<SSLHandler>());

      int clientFlags = CLIENT_PROTOCOL_41 |
          CLIENT_LONG_PASSWORD |
          CLIENT_LONG_FLAG |
          CLIENT_TRANSACTIONS |
          CLIENT_SECURE_CONNECTION |
          CLIENT_SSL;

      SSLHandler sslHandler = response.nextHandler;
      expect(sslHandler.nextHandler, new isInstanceOf<AuthHandler>());
      expect(sslHandler.characterSet, equals(CharacterSet.UTF8));
      expect(sslHandler.clientFlags, equals(clientFlags));
      expect(sslHandler.maxPacketSize, equals(MAX_PACKET_SIZE));

      AuthHandler authHandler = sslHandler.nextHandler;
      expect(authHandler.characterSet, equals(CharacterSet.UTF8));
      expect(authHandler.username, equals(user));
      expect(authHandler.password, equals(password));
      expect(authHandler.scrambleBuffer,
          equals((scrambleBuffer1 + scrambleBuffer2).codeUnits));
      expect(authHandler.db, equals(db));
      expect(authHandler.clientFlags, equals(clientFlags));
      expect(authHandler.maxPacketSize, equals(MAX_PACKET_SIZE));
    });
  });
}

//TODO http://dev.mysql.com/doc/internals/en/determining-authentication-method.html
