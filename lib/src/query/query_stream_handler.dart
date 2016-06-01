part of sqljocky_impl;

class QueryStreamHandler extends _Handler {
  static const int STATE_HEADER_PACKET = 0;
  static const int STATE_FIELD_PACKETS = 1;
  static const int STATE_ROW_PACKETS = 2;
  final String _sql;
  int _state = STATE_HEADER_PACKET;

  _OkPacket _okPacket;
  _ResultSetHeaderPacket _resultSetHeaderPacket;
  List<FieldImpl> fieldPackets;
  Map<Symbol, int> _fieldIndex;

  StreamController<Row> _streamController;

  QueryStreamHandler(this._sql) {
    log = new Logger("QueryStreamHandler");
    fieldPackets = <FieldImpl>[];
  }

  Buffer createRequest() {
    var encoded = UTF8.encode(_sql);
    var buffer = new Buffer(encoded.length + 1);
    buffer.writeByte(COM_QUERY);
    buffer.writeList(encoded);
    return buffer;
  }

  _HandlerResponse processResponse(Buffer response) {
    log.fine("Processing query response");
    var packet = checkResponse(response, false, _state == STATE_ROW_PACKETS);
    if (packet == null) {
      if (response[0] == PACKET_EOF) {
        if (_state == STATE_FIELD_PACKETS) {
          return _handleEndOfFields();
        } else if (_state == STATE_ROW_PACKETS) {
          return _handleEndOfRows();
        }
      } else {
        switch (_state) {
          case STATE_HEADER_PACKET:
            _handleHeaderPacket(response);
            break;
          case STATE_FIELD_PACKETS:
            _handleFieldPacket(response);
            break;
          case STATE_ROW_PACKETS:
            _handleRowPacket(response);
            break;
        }
      }
    } else if (packet is _OkPacket) {
      return _handleOkPacket(packet);
    }
    return _HandlerResponse.notFinished;
  }

  _handleEndOfFields() {
    _state = STATE_ROW_PACKETS;
    _streamController = new StreamController<Row>(onCancel: () {
      _streamController.close();
    });
    this._fieldIndex = createFieldIndex();
    return new _HandlerResponse(result: new _ResultsImpl(
        null, null, fieldPackets,
        stream: _streamController.stream));
  }

  _handleEndOfRows() {
    // the connection's _handler field needs to have been nulled out before the stream is closed,
    // otherwise the stream will be reused in an unfinished state.
    // TODO: can we use Future.delayed elsewhere, to make reusing connections nicer?
    new Future.delayed(new Duration(seconds: 0), _streamController.close);
    return new _HandlerResponse(finished: true);
  }

  _handleHeaderPacket(Buffer response) {
    _resultSetHeaderPacket = new _ResultSetHeaderPacket(response);
    log.fine(_resultSetHeaderPacket.toString());
    _state = STATE_FIELD_PACKETS;
  }

  _handleFieldPacket(Buffer response) {
    var fieldPacket = new FieldImpl._(response);
    log.fine(fieldPacket.toString());
    fieldPackets.add(fieldPacket);
  }

  _handleRowPacket(Buffer response) {
    var dataPacket =
        new StandardDataPacket(response, fieldPackets, _fieldIndex);
    log.fine(dataPacket.toString());
    _streamController.add(dataPacket);
  }

  _handleOkPacket(packet) {
    _okPacket = packet;
    var finished = false;
    // TODO: I think this is to do with multiple queries. Will probably break.
    if ((packet.serverStatus & SERVER_MORE_RESULTS_EXISTS) == 0) {
      finished = true;
    }

    //TODO is this finished value right?
    return new _HandlerResponse(
        finished: finished,
        result: new _ResultsImpl(
            _okPacket.insertId, _okPacket.affectedRows, fieldPackets));
  }

  Map<Symbol, int> createFieldIndex() {
    var identifierPattern = new RegExp(r'^[a-zA-Z][a-zA-Z0-9_]*$');
    var fieldIndex = new Map<Symbol, int>();
    for (var i = 0; i < fieldPackets.length; i++) {
      var name = fieldPackets[i].name;
      if (identifierPattern.hasMatch(name)) {
        fieldIndex[new Symbol(name)] = i;
      }
    }
    return fieldIndex;
  }
}
