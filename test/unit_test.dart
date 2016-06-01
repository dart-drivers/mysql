library unittests;

import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:logging/logging.dart';
import 'package:mockito/mockito.dart';
import 'package:sqljocky/src/constants.dart';
import 'package:sqljocky/src/buffer.dart';
import 'package:sqljocky/src/buffered_socket.dart';
import 'package:sqljocky/src/results.dart';
import 'package:sqljocky/src/sqljocky_impl.dart';
import 'package:test/test.dart';

import 'unit/buffered_socket_test.dart';

part 'unit/buffer_test.dart';
part 'unit/auth_handler_test.dart';
part 'unit/prepared_statements_test.dart';
part 'unit/serialize_test.dart';
part 'unit/types_test.dart';
part 'unit/field_by_name_test.dart';
part 'unit/binary_data_packet_test.dart';
part 'unit/execute_query_handler_test.dart';
// part 'unit/handshake_handler_test.dart';
// part 'unit/connection_test.dart';

void main() {
  runBufferTests();
  runBufferedSocketTests();
  runSerializationTests();
  runTypesTests();
  runPreparedStatementTests();
  runAuthHandlerTests();
  runFieldByNameTests();
  runBinaryDataPacketTests();
  runExecuteQueryHandlerTests();
  // runHandshakeHandlerTests();
  // runConnectionTests();
}
