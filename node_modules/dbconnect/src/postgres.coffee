
postgres = require 'pg'
DBConnect = require './dbconnect'
_ = require 'underscore'
Schema = require './schema'

class PostgresDriver extends DBConnect
  @defaultOptions:
    host: 'localhost'
    port: 5432
    database: 'postgres'
  connString: () ->
    # take the args and create a connection string from it.
    # format of connection string.
    # postgres://user:password@host:port/database
    {user, password, host, port, database} = @args
    if user and password
      "postgres://#{user}:#{password}@#{host}:#{port}/#{database}"
    else
      "postgres://#{host}:#{port}/#{database}"
  tableName: (name) ->
    helper = (name) ->
      # TableName
      # ==>
      # table_name_t
      splitted = name.split /([A-Z]+)/ # allow for consecutive capital chars to stay together.
      i = 0
      normalized =
        for str in splitted
          if str.match /[A-Z]+/
            if i++ == 0
              str.toLowerCase()
            else
              "_" + str.toLowerCase()
          else
            str
      normalized.join('') + "_t"
    if typeof(name) == 'string'
      helper name
    else
      helper name.name
  connect: (cb) ->
    postgres.connect @connString(), (err, client, done) =>
      if err
        cb err
      else
        @inner = client
        @done = done
        cb null, @
  _query: (stmt, args, cb) ->
    if arguments.length == 2
      cb = args
      args = {}
    # we'll need to parse the query to convert $key to $n
    parsed = @parseStmt stmt, args
    @inner.query parsed.stmt, parsed.args, (err, res) =>
      if err
        cb err
      else if stmt.selectOne
        cb null, res.rows[0]
      else if stmt.next
        @_query stmt.next, {}, cb
      else
        cb null, res.rows
  parseStmt: (stmt, args) ->
    if stmt instanceof Object and stmt.stmt and stmt.args
      {stmt, args} = stmt
    splitted = stmt.split /(\$[\w]+)/
    i = 1
    normalized = []
    normedArgs = []
    for s in splitted
      matched = s.match /^\$([\w]+)$/
      if matched
        if not args.hasOwnProperty(matched[1])
          throw new Error("Postgresql.query:stmt_missing_key: #{s}")
        normedArgs.push args[matched[1]]
        normalized.push "$#{i++}"
      else
        normalized.push s
    {stmt: normalized.join(''), args: normedArgs}
  disconnect: (cb) ->
    try
      @done()
      cb null
    catch e
      cb e
  beginTrans: (cb) ->
    @_query 'begin', {}, cb
  commit: (cb) ->
    @_query 'commit', {}, cb
  rollback: (cb) ->
    @_query 'rollback', {}, cb
  ensureInsertColumns: (table, kv) ->
    for col in table.columns
      if kv.hasOwnProperty(col.name)
        continue
      else if not col.optional
        throw new Error("Postgresql.ensureInsertColumns:missing_required_column: #{col.name}")
  valuesStmt: (table, args, i = 0) ->
    keys = []
    vals = {}
    for col in table.columns
      if args.hasOwnProperty(col.name)
        newKey = "#{col.name}#{i}"
        keys.push "$#{newKey}"
        vals[newKey] = args[col.name]
    stmt = "(" + keys.join(', ') + ")"
    {stmt: stmt, values: vals}
  generateInsert: (table, args) ->
    stmts =
      if args instanceof Array
        stmts =
          for arg, i in args
            @valuesStmt(table, arg, i)
      else
        [ @valuesStmt table, args, 0 ]
    columnText =
      '(' + (col.name for col in table.columns).join(', ') + ')'
    phText =
      (stmt.stmt for stmt in stmts).join(', ')
    values =
      _.extend.apply {}, [{}].concat(stmt.values for stmt in stmts)
    idQuery =
       if args instanceof Array
         table.idQuery table.transpose(args)
       else
         table.idQuery args
    select =
      if args instanceof Array
        @generateSelect table, idQuery
      else
        @generateSelectOne table, idQuery
    {stmt: "insert into #{@tableName(table.name)} #{columnText} values #{phText}", args: values, next: select}
  escapeVal: (val) ->
    strHelper = (val) ->
      "'" + val.replace(/\'/g, "''") + "'"
    if typeof(val) == 'number'
      "#{val}"
    else if typeof(val) == 'string'
      strHelper val
    else
      strHelper val.toString()
  criteriaQuery: (table, query, sep = ' and ') ->
    criteria = []
    for key, val of query
      if table.columns.hasOwnProperty(key)
        if val instanceof Array
          criteria.push "#{key} in (#{(@escapeVal(v) for v in val).join(', ')})"
        else
          criteria.push "#{key} = $#{key}"
    criteria.join(sep)
  generateDelete: (table, query) ->
    if Object.keys(query).length == 0
      {stmt: "delete from #{@tableName(table.name)}", args: query}
    else
      stmt = @criteriaQuery table, query
      {stmt: "delete from #{@tableName(table.name)} where #{stmt}", args: query}
  generateSelect: (table, query) ->
    if Object.keys(query).length == 0
      {stmt: "select * from #{@tableName(table.name)}", args: query}
    else
      stmt = @criteriaQuery table, query
      {stmt: "select * from #{@tableName(table.name)} where #{stmt}", args: query}
  generateSelectOne: (table, query) ->
    if Object.keys(query).length == 0
      {stmt: "select * from #{@tableName(table.name)}", args: query, selectOne: true}
    else
      stmt = @criteriaQuery table, query
      {stmt: "select * from #{@tableName(table.name)} where #{stmt}", args: query, selectOne: true}
  generateUpdate: (table, setExp, query) ->
    setGen = @criteriaQuery table, setExp, ', '
    if Object.keys(query).length == 0
      {stmt: "update #{@tableName(table.name)} set #{setGen}", args: setExp}
    else
      queryGen = @criteriaQuery table, query
      {stmt: "update #{@tableName(table.name)} set #{setGen} where #{queryGen}", args: _.extend({}, setExp, query)}
  normalizeRecord: (table, rec) ->
    # postgres stores the columns case-insensitively, so we'll need to remap the records.
    obj = {}
    for col in table.columns
      lc = col.name.toLowerCase()
      if rec.hasOwnProperty(col.name)
        obj[col.name] = rec[col.name]
      else if rec.hasOwnProperty(lc)
        obj[col.name] = rec[lc]
      else
        throw new Error("PostgresDriver.normalizeRecord:unknown_column: #{col.name}")
    obj
  prepareSpecial: (key, val) ->
    if typeof(val) == 'string'
      @prepare key, (args, cb) ->
        @query val, args, cb
    else
      throw new Error("PostgresDriver.prepareSpecial:unsupported_query_type: #{val}")
  supports: (key) ->
    if key == 'in'
      true
    else if key == 'insertMulti'
      true
    else
      false
  generateCreateTable: (table) ->
    columns = @generateColumns table
    indexes = @generateEmbeddedIndexes table
    specs = ['  id serial not null primary key'].concat(columns, indexes).join('\n  , ')
    "create table if not exists #{@tableName(table)} (\n#{specs}\n  );"
  generateDropTable: (table) ->
    "drop table if exists #{@tableName(table)};\n"
  generateEmbeddedIndexes: (table) ->
    helper = (index) ->
      result = []
      if index.primary
        result.push 'primary'
      else if index.unique
        result.push 'unique'
      else
        result.push 'index'
      result.push "("
      result.push (col for col in index.columns).join(', ')
      result.push ")"
      result.join('')
    result = []
    for index in table.indexes
      if index.columns.length == 1
        continue
      else
        result.push helper(index)
    result
  generateColumns: (table, columns = table.columns) ->
    @generateColumn(table, col) for col in columns
  generateColumn: (table, column) ->
    result = []
    result.push column.name
    result.push @generateType column
    if column.optional
      result.push "null"
    else
      result.push "not null"
    if column.default
      result.push @generateDefault column
    index = table.getColumnIndex column
    if index
      if index.unique
        result.push 'unique'
      else if index.primary
        result.push 'primary'
    result.join ' '
  generateType: (col) ->
    type = col.type
    if not type.postgres
      throw new Error("postgres.generateType:type_has_no_postgres_equiv: #{type.name}")
    else if type.postgres instanceof Function
      type.postgres()
    else
      type.postgres
  generateDefault: (col) ->
    def = col.def.default
    if def instanceof Object
      if @functions.hasOwnProperty(def.proc)
        converter = @functions[def.proc]
        if converter instanceof Function
          "default #{converter(def.args)}"
        else
          "default #{converter}(#{(@escapeVal(v) for v in def.args or []).join(', ')})"
      else
        ""
    else
      "default #{@escapeVal(def)}"
  generateForeignKeys: (index) ->
    table = @tableName(index.table)
    columns = index.columns.join(', ')
    refTable = @tableName(index.reference.table)
    refColumns = index.reference.columns.join(', ')
    "alter #{table} add foreign key (#{columns}) references #{refTable} (#{refColumns});"
  generateCreateIndex: (index) ->
    table = @tableName(index.table)
    columns = index.columns.join(', ')
    primaryOrUnique =
      if index.primary
        "primary"
      else if index.unique
        "unique"
      else
        ""
    "create #{primaryOrUnique} index #{index.name} on #{table} (#{columns});"
  generateDropIndex: (index) ->
    "drop index if exists #{index.name};"
  #
  # time to figure out how to deal with migration scripts.
  #
  # we can generate the script - but if we do, then we'll have to deal with certain things manually
  # or we can create script running via .coffee...
  #
  # let's see what sequelize does.
  #
  # they have something called migration object.
  #
  # we'll still need something that tells us how big a particular object is.
  #
  # in order to create it - we'll need to know whether or not something has been previously executed.
  # but it means we'll be generating the script twice.
  #
  # I should really get cranking on the C# version...!!!
  # it is of course *best* when we don't have to
  #
  generateSchema: (schema = @schema) ->
    scripts = []
    for table in schema.tables
      scripts.push @generateCreateTable table
    for index in schema.indexes
      if index.reference
        scripts.push @generateForeignKeys index
      if not (index.unique or index.primary)
        scripts.push @generateCreateIndex index
    scripts.join('\n')
  functions:
    now: 'now'

DBConnect.register 'postgres', PostgresDriver

module.exports = PostgresDriver


