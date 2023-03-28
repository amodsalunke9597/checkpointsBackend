mongodb = require 'mongodb'
DBConnect = require './dbconnect'
_ = require 'underscore'
Schema = require './schema'

# we do not want to kill the connection unti
class MongoDBDriver extends DBConnect
  @defaultOptions:
    host: '127.0.0.1'
    port: 27017
    database: 'test'
  @connections: {}
  tableName: (name) ->
    name.replace /^[A-Z]+/, (str) -> str.toLowerCase()
  id: () ->
    {host, port, database} = @args
    "#{host}:#{port}/#{database}"
  @hasConn: (id) ->
    if @connections.hasOwnProperty(id)
      @connections[id]
    else
      undefined
  @setConn: (id, conn) ->
    @connections[id] = conn
  connect: (cb) ->
    conn = @constructor.hasConn @id()
    if conn
      @inner = conn
      cb null, @
    else
      @innerConnect cb
  innerConnect: (cb) ->
    {host, port, database, queries} = @args
    id = @id()
    try
      server = new mongodb.Server host or '127.0.0.1', port or 27017
      conn = new mongodb.Db database or 'test', server
      conn.open (err, inner) =>
        if err
          conn.close()
          cb err
        else
          @inner = inner
          @constructor.setConn id, inner
          process.on 'exit', () ->
            console.log 'closing mongodb', id
            console.log 'done'
            inner.close()
          cb null, @
    catch e
      console.error 'ERROR: MongoConnection.connect', e
      cb e
  disconnect: (cb) ->
    cb null
  # query:
  # {insert: 'table', args: [ list_of_recs ] }
  # {update: 'table', $set: <set_exp>, query: <query_exp> }
  # {select: 'table', query: <query_exp> }
  # {delete: 'table', query: <query_exp> }
  _query: (stmt, args, cb) ->
    if arguments.length == 2
      cb = args
      args = {}
    if not (stmt instanceof Object)
      throw new Error("MongodBDriver.query_invalid_adhoc_query: #{stmt}")
    if stmt.insert # an insert statement.
      try
        table = @tableName stmt.insert
        @inner.collection(table).insert stmt.args, {safe: true}, (err, res) ->
          if err
            cb err
          else
            cb null, (if stmt.args instanceof Array then res else res[0])
      catch e
        cb e
    else if stmt.select
      try
        table = @tableName stmt.select
        #console.log 'MongoDBDriver._query:select', table, args
        if stmt.query instanceof Object
          @inner.collection(table).find(stmt.query or {}).toArray (err, recs) ->
            if err
              cb err
            else
              cb null, recs
        else
          @inner.collection(table).find().toArray (err, recs) ->
            if err
              cb err
            else
              cb null, recs
      catch e
        cb e
    else if stmt.selectOne
      console.log 'MongoDBDriver.selectOne', stmt
      try
        table = @tableName stmt.selectOne
        if stmt.query instanceof Object
          @inner.collection(table).find(stmt.query or {}).toArray (err, recs) ->
            if err
              cb err
            else
              rec = if recs.length > 0 then recs[0] else null
              #console.log 'MongoDBDriver.selectOne', stmt, rec
              cb null, rec
        else
          @inner.collection(table).find().toArray (err, recs) ->
            if err
              cb err
            else
              rec = if recs.length > 0 then recs[0] else null
              #console.log 'MongoDBDriver.selectOne', stmt, rec
              cb null, rec
      catch e
        cb e
    else if stmt.update
      try
        table = @tableName stmt.update
        @inner.collection(table).update stmt.query or {}, {$set: stmt.$set}, {safe: true, multi: true}, (err, res) ->
          if err
            cb err
          else
            cb null, res
      catch e
        cb e
    else if stmt.delete
      try
        table = @tableName stmt.delete
        @inner.collection(table).remove stmt.query, {safe: true}, (err, res) ->
          if err
            cb err
          else
            cb null, res
      catch e
        cb e
    else if stmt.save
      try
        table = @tableName stmt.save
        @inner.collection(table).save stmt.args, {safe: true}, (err, res) ->
          if err
            cb err
          else
            cb null, res
      catch e
        cb e
    else
      cb new Error("MongoDBDriver.query_unsupported_adhoc_query: #{stmt}")
  prepareSpecial: (key, args) ->
    if _.find(['select', 'selectOne', 'delete', 'update', 'insert', 'save'], ((key) -> args.hasOwnProperty(key)))
      @prepare key, @prepareStmt args
    else
      throw new Error("MongoDBDriver.unknown_prepare_special_args: #{JSON.stringify(args)}")
  prepareStmt: (stmt) ->
    (args, cb) ->
      try
        normalized = @mergeQuery stmt, args
        @_query normalized, cb
      catch e
        cb e
  mergeQuery: (stmt, args) ->
    helper = (obj, args) ->
      if obj instanceof Object
        res = {}
        for key, val of obj
          if obj.hasOwnProperty(key)
            if val.match /^:/
              if args.hasOwnProperty(val.substring(1))
                res[key] = args[val.substring(1)]
              else
                res[key] = helper(val, args)
        res
      else
        obj
    verifyRequired = (args, required = stmt.required) ->
      helper = (args) ->
        for key in required
          if not args.hasOwnProperty(key)
            throw new Error("missing_required_attribute: #{key} in #{JSON.stringify(args)}")
      if args instanceof Array
        helper item for item in args
      else
        helper args
      args
    if stmt.insert
      {insert: stmt.insert, args: verifyRequired(args, stmt.required)}
    else if stmt.select
      {select: stmt.select, query: helper(stmt.query, args)}
    else if stmt.selectOne
      {selectOne: stmt.selectOne, query: helper(stmt.query, args)}
    else if stmt.delete
      {delete: stmt.delete, query: helper(stmt.query, args)}
    else if stmt.update
      {update: stmt.update, $set: helper(stmt.$set, args), query: helper(stmt.query, args)}
    else if stmt.save
      {save: stmt.save, args: args}
    else
      throw new Error("MongoDBDriver.mergeQuery_unsupported_stmt: #{JSON.stringify(stmt)}")
  generateSelect: (table, query) ->
    for key, val of query
      if not table.hasColumn key
        throw new Error("dbconnect.query:unknown_column: #{key}")
    {select: table.name, query: query}
  generateSelectOne: (table, query) ->
    for key, val of query
      if not table.hasColumn key
        throw new Error("dbconnect.query:unknown_column: #{key}")
    {selectOne: table.name, query: query}
  generateInsert: (table, rec) ->
    obj = table.make rec
    {insert: table.name, args: obj}
  generateUpdate: (table, rec, query) ->
    {update: table.name, query: query, $set: rec}
  generateDelete: (table, query) ->
    {delete: table.name, query: query}
  supports: (key) ->
    if key == 'in'
      true
    else if key == 'insertMulti'
      true
    else if key == 'deleteMulti'
      false
    else
      false



DBConnect.register 'mongo', MongoDBDriver

module.exports = MongoDBDriver

