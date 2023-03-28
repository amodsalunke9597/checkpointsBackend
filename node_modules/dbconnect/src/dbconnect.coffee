_ = require 'underscore'
uuid = require './uuid'
{EventEmitter} = require 'events'
Schema = require './schema'

class DBConnect extends EventEmitter
  @Schema: Schema
  @connTypes: {}
  @uuid: uuid.v4
  @register: (type, connector) ->
    if @connTypes.hasOwnProperty(type)
      throw new Error("DBConnect.register_type_exists: #{type}")
    @connTypes[type] = connector
  @hasType: (type) ->
    if @connTypes.hasOwnProperty(type)
      @connTypes[type]
    else
      undefined
  @inners: {}
  @has: (name) ->
    if @inners.hasOwnProperty(name)
      @inners[name]
    else
      undefined
  @setup: (args) ->
    if @inners.hasOwnProperty(args.name)
      throw new Error("DBConnect.setup_connection_exists: #{args.name}")
    if not @connTypes.hasOwnProperty(args.type)
      throw new Error("DBConnect.unknown_type: #{args.type}")
    @inners[args.name] = args
    args.loaders ||= {}
    if args.hasOwnProperty('module')
      if args['module'] instanceof Array
        for module in args['module']
          args.loaders[module] = require(module)
      else
        args.loaders[args.module] = require(args.module)
  @make: (args) ->
    if not @inners.hasOwnProperty(args)
      throw new Error("DBConnect.unknownSetup: #{args}")
    else
      args = @inners[args]
      type = @connTypes[args.type]
      conn = new type(args)
      if args.schema instanceof Schema
        conn.attachSchema args.schema
      if args.tableName instanceof Function
        conn.tableName = args.tableName
      conn
  @defaultOptions: {}
  tableName: (name) -> name
  constructor: (args) ->
    @args = _.extend {}, @constructor.defaultOptions, args
    @modules = {}
    @prepared = {}
    @currentUser = null
    for key, val of @args.loaders
      @loadModule key, val
  loadModule: (key, loader) ->
    if @modules.hasOwnProperty(key)
      console.error 'conn.loadModule:duplicate_loader_key', key
      throw {duplicate_loader_key: key}
    else
      @modules[key] = loader
      if loader instanceof Function
        loader @
      else if loader instanceof Object
        for key, val of loader
          if loader.hasOwnProperty(key)
            #console.log 'dbconnect.loadModule', key, val
            if val instanceof Function
              @prepare key, val
            else
              @prepareSpecial key, val
      else # OK if no loader
        console.error 'conn.loadModule:not_a_loader', key, loader
        return
  attachSchema: (schema) ->
    if not (schema instanceof Schema)
      throw new Error("attachSchema:not_a_schema #{schema}")
    @schema = schema
    schema.conn = @ # is this a good idea? I think so.
  connect: (cb) ->
  query: (stmt, args, cb) ->
    if @prepared.hasOwnProperty(stmt)
      @prepared[stmt] @, args, cb
    else
      @_query arguments...
  queryOne: (stmt, args, cb) ->
    @query stmt, args, (err, res) =>
      if err
        cb err
      else if not res or res.length == 0
        cb {error: 'no_records_found'}
      else
        cb null, res[0]
  prepare: (key, func) ->
    if @prepared.hasOwnProperty(key)
      throw new Error("#{@constructor.name}.duplicate_prepare_stmt: #{key}")
    if @hasOwnProperty(key)
      throw new Error("#{@constructor.name}.duplicate_prepare_stmt: #{key}")
    if func instanceof Function
      @prepared[key] = func
      @[key] = func
    else
      throw new Error("#{@constructor.name}.invalid_prepare_stmt_not_a_function: #{func}")
  prepareSpecial: (args...) ->
    @prepare args...
  disconnect: (cb) ->
  open: (cb) ->
    @connect cb
  close: (cb) ->
    @disconnect cb
  beginTrans: (cb) ->
    cb null, @
  commit: (cb) ->
    cb null, @
  rollback: (cb) ->
    cb null, @
  doneTrans: (cb) ->
    (err, res) =>
      if err
        @rollback () -> cb err
      else
        @commit (err) ->
          if err
            cb err
          else
            cb null, res
  insert: (tableName, obj, cb) ->
    try
      if not @schema
        throw new Error("dbconnect.insert:schema_missing")
      table = @schema.hasTable(tableName)
      if not table
        throw new Error("dbconnect:insert:unknown_table: #{tableName}")
      res =
        if obj instanceof Array
          if not @supports('insertMulti')
            throw new Error("#{@constructor.name}.insert:multiple_records_not_supported")
          else
            for rec in obj
              table.make(rec)
        else
          table.make obj
      query = @generateInsert table, res
      @query query, res, (err, results) =>
        if err
          cb err
        else
          #console.log "#{@constructor.name}.insert:result", results instanceof Array
          if results instanceof Array
            cb null, @makeRecordSet(tableName, results)
          else
            cb null, @makeRecord(tableName, results)
    catch e
      cb e
  delete: (tableName, args, cb) ->
    if arguments.length == 2
      cb = args
      args = {}
    try
      if not @schema
        return cb new Error("dbconnect.delete:schema_missing")
      table = @schema.hasTable(tableName)
      if not table
        return cb new Error("dbconnect:delete:unknown_table: #{tableName}")
      query = @generateDelete table, args
      @query query, {}, (err) =>
        if err
          cb err
        else
          cb null
    catch e
      cb e
  select: (tableName, query, cb) ->
    if arguments.length == 2
      cb = query
      query = {}
    try
      if not @schema
        return cb new Error("dbconnect.select:schema_missing")
      table = @schema.hasTable(tableName)
      if not table
        return cb new Error("dbconnect:select:unknown_table: #{tableName}")
      query = @generateSelect table, query
      @query query, {}, (err, results) =>
        try
          if err
            cb err
          else
            #console.log "#{@constructor.name}.select", tableName
            cb null, @makeRecordSet tableName, results
        catch err
          cb err
    catch e
      cb e
  selectOne: (tableName, query, cb) ->
    @select tableName, query, (err, recordset) =>
      if err
        return cb err
      else
        if recordset.length > 0
          cb null, recordset.first()
        else
          cb new Error("dbconnect.selectOne:no_record_returned: #{tableName}, #{JSON.stringify(query)}")
  uuid: uuid.v4
  normalizeRecord: (table, rec) -> rec
  makeRecord: (tableName, rec) ->
    @schema.makeRecord @, tableName, rec
  makeRecordSet: (tableName, recs) ->
    @schema.makeRecordSet @, tableName, recs
  supports: (key) ->
    false
  generateInQuery: () -> throw new Error("DBConnect.generateInQuery:not_supported")
  generateSchema: (schema = @schema) ->

module.exports = DBConnect

