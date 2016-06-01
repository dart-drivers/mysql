part of sqljocky_impl;

class PreparedQuery {
  final String sql;
  final List<FieldImpl> parameters;
  final List<FieldImpl> columns;
  final int statementHandlerId;
  Connection cnx;

  PreparedQuery(_PrepareHandler handler)
      : sql = handler.sql,
        parameters = handler.parameters,
        columns = handler.columns,
        statementHandlerId = handler.okPacket.statementHandlerId;
}
