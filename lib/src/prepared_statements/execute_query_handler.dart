library sqljocky.execute_query_handler;

import 'dart:async';
import 'dart:convert';

import 'package:logging/logging.dart';

import '../../constants.dart';
import '../buffer.dart';
import '../handlers/handler.dart';
import '../handlers/ok_packet.dart';

import 'binary_data_packet.dart';
import 'prepared_query.dart';

import '../results/results_impl.dart';
import '../results/field_impl.dart';
import '../results/row.dart';
import '../query/result_set_header_packet.dart';
import '../blob.dart';

class ExecuteQueryHandler extends Handler {
  static const int STATE_HEADER_PACKET = 0;
  static const int STATE_FIELD_PACKETS = 1;
  static const int STATE_ROW_PACKETS = 2;

  int _state = STATE_HEADER_PACKET;

  ResultSetHeaderPacket _resultSetHeaderPacket;
  List<FieldImpl> fieldPackets;
  Map<Symbol, int> _fieldIndex;
  StreamController<Row> _streamController;

  final PreparedQuery _preparedQuery;
  final List _values;
  List preparedValues;
  OkPacket _okPacket;
  bool _executed;
  bool _cancelled = false;

  ExecuteQueryHandler(
      PreparedQuery this._preparedQuery, bool this._executed, List this._values)
      : super(new Logger("ExecuteQueryHandler")) {
    fieldPackets = <FieldImpl>[];
  }

  Buffer createRequest() {
    var length = 0;
    var types = new List<int>(_values.length * 2);
    var nullMap = createNullMap();
    preparedValues = new List(_values.length);
    for (var i = 0; i < _values.length; i++) {
      types[i * 2] = _getType(_values[i]);
      types[i * 2 + 1] = 0;
      preparedValues[i] = prepareValue(_values[i]);
      length += measureValue(_values[i], preparedValues[i]);
    }

    var buffer = writeValuesToBuffer(nullMap, length, types);
//    log.fine(Buffer.listChars(buffer._list));
    return buffer;
  }

  prepareValue(value) {
    if (value != null) {
      if (value is int) {
        return _prepareInt(value);
      } else if (value is double) {
        return _prepareDouble(value);
      } else if (value is DateTime) {
        return _prepareDateTime(value);
      } else if (value is bool) {
        return _prepareBool(value);
      } else if (value is List<int>) {
        return _prepareList(value);
      } else if (value is Blob) {
        return _prepareBlob(value);
      } else {
        return _prepareString(value);
      }
    }
    return value;
  }

  measureValue(value, preparedValue) {
    if (value != null) {
      if (value is int) {
        return _measureInt(value, preparedValue);
      } else if (value is double) {
        return _measureDouble(value, preparedValue);
      } else if (value is DateTime) {
        return _measureDateTime(value, preparedValue);
      } else if (value is bool) {
        return _measureBool(value, preparedValue);
      } else if (value is List<int>) {
        return _measureList(value, preparedValue);
      } else if (value is Blob) {
        return _measureBlob(value, preparedValue);
      } else {
        return _measureString(value, preparedValue);
      }
    }
    return 0;
  }

  _getType(value) {
    if (value != null) {
      if (value is int) {
        return FIELD_TYPE_LONGLONG;
      } else if (value is double) {
        return FIELD_TYPE_VARCHAR;
      } else if (value is DateTime) {
        return FIELD_TYPE_DATETIME;
      } else if (value is bool) {
        return FIELD_TYPE_TINY;
      } else if (value is List<int>) {
        return FIELD_TYPE_BLOB;
      } else if (value is Blob) {
        return FIELD_TYPE_BLOB;
      } else {
        return FIELD_TYPE_VARCHAR;
      }
    } else {
      return FIELD_TYPE_NULL;
    }
  }

  _writeValue(value, preparedValue, Buffer buffer) {
    if (value != null) {
      if (value is int) {
        _writeInt(value, preparedValue, buffer);
      } else if (value is double) {
        _writeDouble(value, preparedValue, buffer);
      } else if (value is DateTime) {
        _writeDateTime(value, preparedValue, buffer);
      } else if (value is bool) {
        _writeBool(value, preparedValue, buffer);
      } else if (value is List<int>) {
        _writeList(value, preparedValue, buffer);
      } else if (value is Blob) {
        _writeBlob(value, preparedValue, buffer);
      } else {
        _writeString(value, preparedValue, buffer);
      }
    }
  }

  _prepareInt(value) {
    return value;
  }

  int _measureInt(value, preparedValue) {
    return 8;
  }

  _writeInt(value, preparedValue, Buffer buffer) {
//          if (value < 128 && value > -127) {
//            log.fine("TINYINT: value");
//            types.add(FIELD_TYPE_TINY);
//            types.add(0);
//            values.add(value & 0xFF);
//          } else {
    log.fine("LONG: $value");
    buffer.writeByte(value >> 0x00 & 0xFF);
    buffer.writeByte(value >> 0x08 & 0xFF);
    buffer.writeByte(value >> 0x10 & 0xFF);
    buffer.writeByte(value >> 0x18 & 0xFF);
    buffer.writeByte(value >> 0x20 & 0xFF);
    buffer.writeByte(value >> 0x28 & 0xFF);
    buffer.writeByte(value >> 0x30 & 0xFF);
    buffer.writeByte(value >> 0x38 & 0xFF);
//          }
  }

  _prepareDouble(value) {
    return UTF8.encode(value.toString());
  }

  int _measureDouble(value, preparedValue) {
    return Buffer.measureLengthCodedBinary(preparedValue.length) +
        preparedValue.length;
  }

  _writeDouble(value, preparedValue, Buffer buffer) {
    log.fine("DOUBLE: $value");

    buffer.writeLengthCodedBinary(preparedValue.length);
    buffer.writeList(preparedValue);

    // TODO: if you send a double value for a decimal field, it doesn't like it
//          types.add(FIELD_TYPE_FLOAT);
//          types.add(0);
//          values.addAll(doubleToList(value));
  }

  _prepareDateTime(value) {
    return value;
  }

  int _measureDateTime(value, preparedValue) {
    return 8;
  }

  _writeDateTime(value, preparedValue, Buffer buffer) {
    // TODO remove Date eventually
    log.fine("DATE: $value");
    buffer.writeByte(7);
    buffer.writeByte(value.year >> 0x00 & 0xFF);
    buffer.writeByte(value.year >> 0x08 & 0xFF);
    buffer.writeByte(value.month);
    buffer.writeByte(value.day);
    buffer.writeByte(value.hour);
    buffer.writeByte(value.minute);
    buffer.writeByte(value.second);
  }

  _prepareBool(value) {
    return value;
  }

  int _measureBool(value, preparedValue) {
    return 1;
  }

  _writeBool(value, preparedValue, Buffer buffer) {
    log.fine("BOOL: $value");
    buffer.writeByte(value ? 1 : 0);
  }

  _prepareList(value) {
    return value;
  }

  int _measureList(value, preparedValue) {
    return Buffer.measureLengthCodedBinary(value.length) + value.length;
  }

  _writeList(value, preparedValue, Buffer buffer) {
    log.fine("LIST: $value");
    buffer.writeLengthCodedBinary(value.length);
    buffer.writeList(value);
  }

  _prepareBlob(value) {
    return (value as Blob).toBytes();
  }

  int _measureBlob(value, preparedValue) {
    return Buffer.measureLengthCodedBinary(preparedValue.length) +
        preparedValue.length;
  }

  _writeBlob(value, preparedValue, Buffer buffer) {
    log.fine("BLOB: $value");
    buffer.writeLengthCodedBinary(preparedValue.length);
    buffer.writeList(preparedValue);
  }

  _prepareString(value) {
    return UTF8.encode(value.toString());
  }

  int _measureString(value, preparedValue) {
    return Buffer.measureLengthCodedBinary(preparedValue.length) +
        preparedValue.length;
  }

  _writeString(value, preparedValue, Buffer buffer) {
    log.fine("STRING: $value");
    buffer.writeLengthCodedBinary(preparedValue.length);
    buffer.writeList(preparedValue);
  }

  List<int> createNullMap() {
    var bytes = ((_values.length + 7) / 8).floor().toInt();
    var nullMap = new List<int>(bytes);
    var byte = 0;
    var bit = 0;
    for (var i = 0; i < _values.length; i++) {
      if (nullMap[byte] == null) {
        nullMap[byte] = 0;
      }
      if (_values[i] == null) {
        nullMap[byte] = nullMap[byte] + (1 << bit);
      }
      bit++;
      if (bit > 7) {
        bit = 0;
        byte++;
      }
    }

    return nullMap;
  }

  Buffer writeValuesToBuffer(List<int> nullMap, int length, List<int> types) {
    var buffer = new Buffer(10 + nullMap.length + 1 + types.length + length);
    buffer.writeByte(COM_STMT_EXECUTE);
    buffer.writeUint32(_preparedQuery.statementHandlerId);
    buffer.writeByte(0);
    buffer.writeUint32(1);
    buffer.writeList(nullMap);
    if (!_executed) {
      buffer.writeByte(1);
      buffer.writeList(types);
      for (int i = 0; i < _values.length; i++) {
        _writeValue(_values[i], preparedValues[i], buffer);
      }
    } else {
      buffer.writeByte(0);
    }
    return buffer;
  }

  HandlerResponse processResponse(Buffer response) {
    var packet;
    if (_cancelled) {
      _streamController.close();
      return new HandlerResponse(finished: true);
    }
    if (_state == STATE_HEADER_PACKET) {
      packet = checkResponse(response);
    }
    if (packet == null) {
      if (response[0] == PACKET_EOF) {
        log.fine('Got an EOF');
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
    } else if (packet is OkPacket) {
      _okPacket = packet;
      if ((packet.serverStatus & SERVER_MORE_RESULTS_EXISTS) == 0) {
        return new HandlerResponse(
            finished: true,
            result: new ResultsImpl(
                _okPacket.insertId, _okPacket.affectedRows, null));
      }
    }
    return HandlerResponse.notFinished;
  }

  _handleEndOfFields() {
    _state = STATE_ROW_PACKETS;
    _streamController = new StreamController<Row>();
    _streamController.onCancel = () {
      _cancelled = true;
    };
    this._fieldIndex = createFieldIndex();
    return new HandlerResponse(
        result: new ResultsImpl(null, null, fieldPackets,
            stream: _streamController.stream));
  }

  _handleEndOfRows() {
    _streamController.close();
    return new HandlerResponse(finished: true);
  }

  _handleHeaderPacket(Buffer response) {
    log.fine('Got a header packet');
    _resultSetHeaderPacket = new ResultSetHeaderPacket(response);
    log.fine(_resultSetHeaderPacket.toString());
    _state = STATE_FIELD_PACKETS;
  }

  _handleFieldPacket(Buffer response) {
    log.fine('Got a field packet');
    var fieldPacket = new FieldImpl(response);
    log.fine(fieldPacket.toString());
    fieldPackets.add(fieldPacket);
  }

  _handleRowPacket(Buffer response) {
    log.fine('Got a row packet');
    var dataPacket = new BinaryDataPacket(response, fieldPackets, _fieldIndex);
    log.fine(dataPacket.toString());
    _streamController.add(dataPacket);
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
