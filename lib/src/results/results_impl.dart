library sqljocky.results_impl;

import 'dart:async';
import 'dart:collection';

import 'field.dart';
import 'results.dart';
import 'row.dart';

class ResultsImpl extends StreamView<Row> implements Results {
  final int insertId;
  final int affectedRows;

  final List<Field> fields;

  factory ResultsImpl(int insertId, int affectedRows, List<Field> fields,
      {Stream<Row> stream: null}) {
    if (stream != null) {
      var newStream = stream.transform(
          new StreamTransformer.fromHandlers(handleDone: (EventSink<Row> sink) {
        sink.close();
      }));
      return new ResultsImpl._fromStream(
          insertId, affectedRows, fields, newStream);
    } else {
      var newStream = new Stream.fromIterable(new List<Row>());
      return new ResultsImpl._fromStream(
          insertId, affectedRows, fields, newStream);
    }
  }

  ResultsImpl._fromStream(
      this.insertId, this.affectedRows, List<Field> fields, Stream<Row> stream)
      : this.fields = new UnmodifiableListView(fields),
        super(stream);

  /**
   * Takes a _ResultsImpl and destreams it. That is, it listens to the stream, collecting
   * all the rows into a list until the stream has finished. It then returns a new
   * _ResultsImpl which wraps that list of rows.
   */
  static Future<ResultsImpl> destream(ResultsImpl results) async {
    var rows = await results.toList();
    var newStream = new Stream<Row>.fromIterable(rows);
    return new ResultsImpl._fromStream(
        results.insertId, results.affectedRows, results.fields, newStream);
  }
}
