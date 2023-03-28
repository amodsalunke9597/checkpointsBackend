_ = require 'underscore'
uuid = require 'node-uuid'
async = require 'async'
{EventEmitter} = require 'events'
validator = require 'validator'
crypto = require 'crypto'

class Column
  constructor: (@table, @def) ->
    {col, type, optional} = @def
    @name = col
    schemaType = @table.schema.hasType type
    if not schemaType
      throw new Error("unknown_type: #{JSON.stringify(type)}")
    @type = schemaType
    @optional = optional or false
    if @def.default
      @default = @setupDefault @def.default
    if @def.update
      @update = @setupDefault @def.update
  setupDefault: (spec) ->
    # we'll have to setup something different for this...
    # 1 - we'll have to take in the whole spec.
    # 2 - we'll also have to reference the original function reference (so we can retrieve it from the again.
    if spec instanceof Object
      # when we set this up -> what
      proc = @table.schema.hasFunction spec.proc
      if not proc
        throw new Error("unknown_default_function: #{spec.proc}")
      if spec.args instanceof Array
        args = spec.args
        (v) -> proc args...
      else
        (v) ->
          if arguments.length > 0
            proc arguments...
          else
            proc()
    else
      () => spec
  destroy: () ->
    delete @table
    delete @type
    delete @default
  serialize: () ->
    @def
  validate: (val) ->
    if val != undefined and val != null
      @type.convertable val
    else if @optional
      true
    else
      throw new Error("value_required: #{@table.name}.#{@name}")
  make: (val) ->
    if val != undefined and val != null
      @type.make val
    else if @default
      @default.apply @table.schema.conn, []
    else if @optional
      null
    else
      throw new Error("value_required: #{@table.name}.#{@name}")

class OrderedMap extends Array
  constructor: (ensure, items = []) ->
    Object.defineProperty @, 'ensure', {value: ensure, enumerable: false}
    for item in items
      @ensure item
    for item in items
      @push item
      @[item.name] = item
  destroy: () ->
    for key, val of @
      if val instanceof Index
        val.destroy()
  splice: (index, removed, inserted...) ->
    for item in inserted
      @ensure item
    removedCols = super index, removed, inserted...
    for col in removedCols
      delete @[col.name]
    for col in inserted
      @[col.name] = col
    removedCols
  push: (col...) ->
    @splice @length, 0, col...
  pop: (col...) ->
    res = @splice @length - 1, 1
    res[0]
  unshift: (col...) ->
    @splice 0, 0, col...
  shift: () ->
    res = @splice 0, 1
    res[0]

class Columns extends Array
  constructor: (columns) ->
    for col in columns
      @ensureColumn col
    for col in columns
      @push col
      @[col.name] = col
  destroy: () ->
    for key, val of @
      if val instanceof Index
        val.destroy()
  ensureColumn: (col) ->
    if not (col instanceof Column)
      throw new Error("columns.ctor:not_a_column: #{col}")
  splice: (index, removed, inserted...) ->
    for col in inserted
      @ensureColumn col
    removedCols = super index, removed, inserted...
    for col in removedCols
      delete @[col.name]
    for col in inserted
      @[col.name] = col
    removedCols
  push: (col...) ->
    @splice @length, 0, col...
  pop: (col...) ->
    res = @splice @length - 1, 1
    res[0]
  unshift: (col...) ->
    @splice 0, 0, col...
  shift: () ->
    res = @splice 0, 1
    res[0]

class Reference
  constructor: (@schema, @index, @table, @columns) ->

class Index
  constructor: (@table, args) ->
    # index/primary/unique can only have one of them.
    # default is index.
    # foreign key is setting up relations between objects - that's defined at schema level as well..
    {index, primary, unique, name, reference} = args
    # order. primary > unique > index
    if primary
      @init primary, name
      @ensurePrimary()
    else if unique
      @init unique, name
      @ensureUnique()
    else
      @init index, name
    if reference
      @ensureReference reference
  destroy: () ->
    delete @table
  init: (columns, name) ->
    for col in columns
      if not @table.hasColumn col
        throw new Error("unknown_column_in_table: #{col}, #{@table.name}")
    @columns = columns
    @name = (if not name then @makeName() else name)
    @table.schema.registerIndex @
  makeName: () ->
    columnName = @columns.join('_')
    "#{@table.name}_#{columnName}"
  ensurePrimary: () ->
    @table.setPrimary @
  ensureUnique: () ->
    @unique = true
  ensureReference: (@reference) ->
    {table, columns} = @reference
    # first - the table must exist.
    refTable = @table.schema.hasTable table
    if not refTable
      throw new Error("Unknown_reference_table: #{table}")
    for col in columns
      if not refTable.hasColumn col
        throw new Error("unknown_reference_column: #{table}.#{col}")
    @table.schema.registerReference @, refTable, columns
  serialize: () ->
    index = {table: @table.name, name: @name}
    if @reference
      index.reference = @reference
    if @primary
      index.primary = @columns
    else if @unique
      index.unique = @columns
    else
      index.index = @columns
    index
  referenceQuery: (keyvals) ->
    if not @reference
      throw new Error("Index.referenceQuery:not_a_foreign_key: #{@name}")
    # first of all - create a mapping between the two sets of names.
    obj = {}
    for col, i in @reference.columns
      if keyvals.hasOwnProperty(col)
        obj[@columns[i]] = keyvals[col]
    obj
  reverseReferenceQuery: (keyvals) ->
    if not @reference
      throw new Error("Index.referenceQuery:not_a_foreign_key: #{@name}")
    # first of all - create a mapping between the two sets of names.
    obj = {}
    for col, i in @columns
      if keyvals.hasOwnProperty(col)
        obj[@reference.columns[i]] = keyvals[col]
    obj

class Table
  constructor: (@schema, @name, @defs, @mixin, @loaded = false) ->
    if @schema.hasTable @name
      throw new Error("duplicate_table_in_schema: #{@name}, #{@schema.name}")
    @initColumns()
    @initIndexes()
  destroy: () ->
    delete @schema
    for key, index of indexes
      index.destroy()
    delete @indexes
    @columns.destroy()
  ensureColumnNames: (columns) ->
    #console.log 'ensureColumNames', columns
    names = {}
    for col in columns
      if names.hasOwnProperty(col.col)
        throw new Error("duplicate_column_in_table: #{col.col}, #{@table.name}")
      else if names.hasOwnProperty(col.col.toLowerCase())
        throw new Error("duplicate_column_case_insensitive_in_table: #{col.col}, #{@table.name}")
      else
        names[col.col] = col
        names[col.col.toLowerCase()] = col
  extractColumns: (defs) ->
    _.filter defs, (obj) -> obj.col or obj.column
  initColumns: () ->
    columns = @extractColumns @defs
    @ensureColumnNames columns
    @columns = new OrderedMap(((col) -> col instanceof Column), @makeColumn(col) for col in columns)
  makeColumn: (col) ->
    new Column @, col
  extractIndexes: (defs) ->
    helper = (def) ->
      def.index or def.primary or def.unique or def.reference
    _.filter defs, helper
  initIndexes: () ->
    helper = (def) =>
      indexDef = @normalizeIndexDef def
      new Index @, indexDef
    @indexes = new OrderedMap ((idx) -> idx instanceof Index), (helper(def) for def in @extractIndexes @defs)
  normalizeIndexDef: (def) ->
    if def.col
      col =
        if def.primary
          {primary: [def.col]}
        else if def.unique
          {unique: [def.col]}
        else
          {index: [def.col]}
      if def.reference
        col.reference = def.reference
      if def.name
        col.name = def.name
      col
    else
      def
  hasColumn: (col) ->
    #console.log 'Table.hasColumn', col, @columns
    if @columns.hasOwnProperty(col)
      @columns[col]
    else
      undefined
  hasPrimary: ()  ->
    @primary
  setPrimary: (index) ->
    if @primary
      throw new Error("Table_cannot_have_multiple_primary_keys")
    index.primary = true
    @primary = index
  hasUnique: () ->
    for key, index of @indexes
      if index.unique
        return index
    undefined
  hasPrimaryOrUnique: () ->
    if @hasPrimary()
      @primary
    else
      @hasUnique()
  references: (table) ->
    for key, index of @indexes
      if index.reference?.table == table.name
        return index
    undefined
  serialize: () ->
    for col in @columns
      col.serialize()
  validate: (val) ->
    for col in @columns
      col.validate val[col.name]
  make: (val) ->
    #console.log "#{@name}.make", val
    obj = {}
    for col in @columns
      obj[col.name] = col.make val[col.name]
    type = @schema.hasType @name
    if type
      type.make obj
    else
      obj
  idQuery: (query) ->
    index = @hasPrimaryOrUnique()
    if index
      @_idQuery index, query
    else
      query
  _idQuery: (index, query) ->
    obj = {}
    for col in index.columns
      obj[col] = query[col]
    obj
  getRelationQuery: (tableName, args, record) ->
    table = @schema.hasTable tableName
    if not table
      throw new Error("ActiveRecord.select:unknown_table: #{tableName}")
    index = table.references @
    if index # we have a reference.
      query = index.referenceQuery record
      _.extend query, args
    else
      index = @references table
      if index
        query = index.reverseReferenceQuery record
        _.extend query, args
      else
        throw new Error("ActiveRecord.select:tables_not_related: #{@name}, #{tableName}")
  transpose: (records) ->
    columns = {}
    helper = (col) ->
      data = []
      for rec in records
        data.push rec[col.name]
      data
    for col in @columns
      columns[col.name] = helper col
    columns
  getColumnIndex: (column) ->
    helper = (columns) ->
      columns[0] == (if column instanceof Column then column.name else column)
    for index in @indexes
      if index.columns.length == 1 and helper index.columns
        return index
    undefined


class ActiveRecord extends EventEmitter
  constructor: (@table, @db, record) ->
    #console.log 'ActiveRecord.ctor', @table.name, record
    @record = @db.normalizeRecord @table, record
    @changed = false
    @deleted = false
    @updated = {}
    _.extend @, @table.mixin
  set: (key, val) ->
    if @deleted
      throw new Error("ActiveRecord.set:record_already_deleted")
    obj =
      if arguments.length == 2
        obj = {}
        obj[key] = val
        obj
      else
        key
    for key, val of obj
      @_setOne key, val
    for column, i in @table.columns
      if column.update and not obj.hasOwnProperty(column.name)
        @_setOne column.name, column.update(@record[column.name])
  _setOne: (key, val) ->
    col = @table.hasColumn key
    if col and not col.validate(val)
      throw new Error("#{table.name}.#{col.name}:fail_validation: #{val}")
    @updated[key] = val
    @changed = true
  get: (key) ->
    if @deleted
      throw new Error("ActiveRecord.get:record_already_deleted")
    if @updated.hasOwnProperty(key)
      @updated[key]
    else if @record.hasOwnProperty(key)
      @record[key]
    else
      undefined
  select: (tableName, args, cb) ->
    if arguments.length == 2
      cb = args
      args = {}
    try
      query = @table.getRelationQuery tableName, args, @record
      @db.select tableName, query, cb
    catch e
      cb e
  selectOne: (tableName, args, cb) ->
    if arguments.length == 2
      cb = args
      args = {}
    try
      query = @table.getRelationQuery tableName, args, @record
      @db.selectOne tableName, query, cb
    catch e
      cb e
  insert: (tableName, args, cb) ->
    table = @table.schema.hasTable tableName
    if not table
      return cb new Error("ActiveRecord.selectOne:unknown_table: #{tableName}")
    index = table.references @table
    if index # we have a reference.
      query = index.referenceQuery @record
      args = _.extend {}, args, query
      @db.insert tableName, args, cb
    else
      cb new Error("ActiveRecord.insert:tables_not_related: #{@table.name}, #{tableName}")
  idQuery: () ->
    if @deleted
      throw new Error("ActiveRecord.idQuery:record_already_deleted")
    @table.idQuery @record
  update: (keyVals, cb) ->
    if @deleted
      return cb new Error("ActiveRecord.update:record_already_deleted")
    try
      @set keyVals
      @save cb
    catch e
      cb e
  save: (cb) ->
    if @deleted
      return cb new Error("ActiveRecord.save:record_already_deleted")
    if @changed
      query = @db.generateUpdate @table, @updated, @idQuery()
      @db.query query, {}, (err, res) =>
        if err
          cb err
        else
          _.extend @record, @updated
          @updated = {}
          @changed = false
          cb null, @
    else
      cb null, @
  delete: (cb) ->
    if @deleted
      return cb new Error("ActiveRecord.delete:record_already_deleted")
    query = @db.generateDelete @table, @idQuery()
    @db.query query, {}, (err, res) =>
      if err
        cb err
      else
        @deleted = true
        cb null

# used for holding resultsets
class ActiveRecordSet
  constructor: (@table, @db, records) ->
    @records =
      for record in records
        @db.normalizeRecord @table, record
    @length = @records.length
  select: (tableName, args, cb) ->
    if arguments.length == 2
      cb = args
      args = {}
    records = []
    table = @table.schema.hasTable tableName
    if not table
      throw new Error("ActiveRecordSet.select:unknown_table: #{tableName}")
    helper = (rec, next) =>
      active = new ActiveRecord @table, @db, rec
      active.select tableName args, (err, recs) =>
        if err
          next err
        else
          for rec in recs
            if rec instanceof ActiveRecord
              records.push rec.record
            else
              records.push rec
          next null
    if @db.supports('in')
      query = @table.getRelationQuery tableName, args, @transpose()
      @select tableName, query, (err, records) =>
        if err
          cb err
        else
          cb null, new ActiveRecordSet table, @db, records
    else
      async.forEach @records, helper, (err) =>
        if err
          cb err
        else
          cb null, new ActiveRecordSet table, @db, records
  selectOne: (tableName, args, cb) ->
    @select tableName, args, (err, recordSet) =>
      if err
        cb err
      else if recordSet.length > 1
        cb null, recordSet.first()
      else
        cb new Error("ActiveRecordSet.selectOne:record_not_found: #{tableName}, #{JSON.stringify(args)}")
  delete: (cb) ->
    args = @table.idQuery @transpose()
    #console.log 'ActiveRecordSet.delete', @tableName, args
    query = @db.generateDelete @table, args
    #console.log 'ActiveRecordSet.delete', query
    @db.query query, cb
  transpose: () ->
    @table.transpose @records
  first: () ->
    #console.log 'ActiveRecordSet.first()', @table.name, @records[0]
    new ActiveRecord @table, @db, @records[0]
  filter: (args) ->
    kvOne = (rec, key, val) ->
      if rec.hasOwnProperty(key)
        return rec[key] == val
      false
    kvHelper = (rec, key, val) ->
      if val instanceof Array
        for v in val
          res = kvOne(rec, key, v)
          if res
            return true
      else
        kvOne(rec, key, val)
    helper = (rec) ->
      result = true
      for key, val of args
        res = kvHelper rec, key, val
        if not res
          return false
      return result
    filtered = _.filter @records, helper
    new ActiveRecordSet @table, @db, filtered
  append: (recordset) -> # do I want to attach it to the table itself?
    # that seems to be the way to make it completely transparent...
    # OK - I think I understand how it can be done now.
    if recordset.table != @table
      throw new Error("ActiveRecordSet.append:not_the_same_table: #{recordset.table.name} != #{@table.name}")
    # uncertain if we need validation for unique concating...
    @records = @records.concat(recordset.records)

class Tables extends Array


class Schema
  @builtInTypes: {}
  @builtInFunctions: {}
  @Record: ActiveRecord
  @RecordSet: ActiveRecordSet
  @Table: Table
  @registerType: (name, type) ->
    if @builtInTypes.hasOwnProperty(name)
      throw new Error("built_type_duplicate: #{name}")
    @builtInTypes[name] = type
  @registerFunction: (name, proc) ->
    if @builtInFunctions.hasOwnProperty(name)
      throw new Error("builtin_function_duplicate: #{name}")
    @builtInFunctions[name] = proc
  constructor: (schema) ->
    @types = {}
    @tables = new OrderedMap ((t) -> t instanceof Table)
    @indexes = new OrderedMap ((idx) -> idx instanceof Index)
    @references = {} # how are things related to another table...
    @functions = {}
    if schema
      @initialize schema
  destroy: () ->
    for key, index of @indexes
      index.destroy()
    delete @indexes
    for key, table of @tables
      table.destroy()
    delete @tables
    delete @conn
  initialize: (schema) ->
    {@name, tables, indexes} = schema
    if tables
      for key, val of tables
        @defineTable key, val
    if indexes
      for def in indexes
        @defineIndex def
  defineTable: (name, defs, mixin = {}) ->
    table = new Table @, name, defs, mixin
    @tables.push table
  defineIndex: (def) ->
    if not def.table
      throw new Error("index_requires_table: #{def}")
    table = @hasTable def.table
    if not table
      throw new Error("index_table_unknown: #{def.table}")
    new Index table, def
  registerFunction: (name, proc) ->
    if @functions.hasOwnProperty(name)
      throw new Error("function_duplicated: #{name}")
    @functions[name] = proc
  hasFunction: (name) ->
    if @functions.hasOwnProperty(name)
      @functions[name]
    else if @constructor.builtInFunctions.hasOwnProperty(name)
      @constructor.builtInFunctions[name]
    else
      undefined
  registerType: (name, type) ->
    if @types.hasOwnProperty(name)
      throw new Error("duplicate_type: #{name}")
    @types[name] = type
  registerTableType: (name, type) ->
    if not type.hasOwnProperty('spec')
      throw new Error("lack_of_table_spec: #{name}")
    if not type.make # do I want active object?
      type.make = (obj) ->
        new type obj
    @defineTable name, type.spec
    @registerType name, type
  hasType: (name) ->
    helper = (name) =>
      if @types.hasOwnProperty(name)
        @types[name]
      else if @constructor.builtInTypes.hasOwnProperty(name)
        @constructor.builtInTypes[name]
      else
        undefined
    if typeof(name) == 'string'
      helper(name)
    else # it's an object.
      for key, val of name
        type = helper(key)
        if type?.takeArgs
          return new type(val)
      return undefined
  registerIndex: (index) ->
    if @indexes.hasOwnProperty index.name
      throw new Error("index_name_duplication: #{index.name}")
    @indexes.push index
  registerReference: (index, table, columns) ->
    @references[index.name] = new Reference @, index, table, columns
  hasTable: (name) ->
    if @tables.hasOwnProperty(name)
      @tables[name]
    else
      undefined
  makeRecord: (db, tableName, arg) ->
    table = @hasTable tableName
    if not table
      throw new Error("Schema.makeRecord:invalid_table: #{tableName}")
    new ActiveRecord table, db, arg
  makeRecordSet: (db, tableName, arg) ->
    table = @hasTable tableName
    if not table
      throw new Error("Schema.makeRecord:invalid_table: #{tableName}")
    new ActiveRecordSet table, db, arg
  serialize: () ->
    tables = []
    for table in @tables
      tables.push table.serialize()
    indexes = []
    for index in @indexes
      indexes.push index.serialize()
    {name: @name, tables: tables, indexes: indexes}
  generate: (conn) ->
    result = []
    for key, table of @tables
      result.push table.generate(conn)

class STRING
  @make: (val) ->
    if typeof(val) == 'string'
      val
    else if val instanceof Object
      JSON.stringify(val)
    else
      "#{val}"
  @convertable: (val) ->
    typeof(val) == 'string'
  @postgres: 'text' # might be a function or a literal.
  @takeArgs: true
  constructor: ({max}) ->
    if typeof(max) == 'number'
      @max = max
    else
      throw new Error("string_type:unknown_argument_type: #{max}")
  convertable: (val) ->
    @constructor.convertable(val) and val.length <= @max
  make: (val) ->
    str = @constructor.make val
    if val.length <= @max
      val
    else
      throw new Error("string_type:val_exceed_size: #{val}, #{@size}")
  postgres: () ->
    "varchar(#{@max})"

Schema.registerType 'string', STRING

class UUID
  @make: (val) ->
    if @convertable(val)
      val
    else
      uuid.v4()
  @convertable: (val) ->
    val.match /^[0-9a-fA-F]{8}-?[0-9a-fA-F]{4}-?[0-9a-fA-F]{4}-?[0-9a-fA-F]{4}-?[0-9a-fA-F]{12}$/
  @postgres: 'uuid'

Schema.registerType 'uuid', UUID

class NUMBER
  @convertable: (val) ->
    typeof(val) == 'number' or (typeof(val) == 'string' and val.match(/^-?\d*\.?\d*$/))
  @make: (val) ->
    if typeof(val) == 'number'
      val
    else
      parseInt(val)
  @postgres: 'double precision'

Schema.registerType 'number', NUMBER

class INTEGER
  @convertable: (val) ->
    (typeof(val) == 'number' and Math.round(val) == val) or (typeof(val) == 'string' and val.match(/^-?\d*/))
  @make: (val) ->
    if @convertable(val)
      if typeof(val) == 'string'
        parseInt(val)
      else
        val
    else
      throw new Error("invalid_integer: #{val}")
  @postgres: 'bigint'

Schema.registerType 'integer', INTEGER

class EMAIL
  @convertable: (val) ->
    validator.isEmail(val)
  @make: (val) ->
    if @convertable(val)
      val
    else
      throw new Error("invalid_email: #{val}")
  @postgres: 'varchar(255)'

Schema.registerType 'email', EMAIL

class HEXSTRING
  @convertable: (val) ->
    validator.isHexadecimal(val)
  @make: (val) ->
    if @convertable(val)
      val
    else
      throw new Error("invalid_hexstring: #{val}")
  @postgres: 'text'
  @takeArgs: true
  constructor: ({max}) ->
    if typeof(max) == 'number'
      @max = max
    else
      throw new Error("hexstring:unknown_argument_type: #{max}")
  convertable: (val) ->
    @constructor.convertable(val) and val.length <= @max
  make: (val) ->
    str = @constructor.make val
    if val.length <= @max
      val
    else
      throw new Error("hexstring:val_exceed_size: #{val}, #{@size}")
  postgres: () ->
    "varchar(#{@max})"


Schema.registerType 'hexString', HEXSTRING

class DATETIME
  @convertable: (val) ->
    validator.isDate(val)
  @make: (val) ->
    if @convertable(val)
      new Date Date.parse(val)
    else
      throw new Error("invalid_datetime: #{val}")
  @postgres: 'timestamp with time zone'

Schema.registerType 'datetime', DATETIME

b2h = []
h2b = {}
for i in [0...256] by 1
  b2h[i] = (i ^ 0x100).toString(16).substring(1)
  h2b[b2h[i]] = i
toHex = (bytes) ->
  for byte in bytes
    b2h[byte]
Schema.registerFunction 'randomBytes',(size = 32) ->
    toHex(crypto.randomBytes(size)).join('')

Schema.registerFunction 'makeUUID', uuid.v4

Schema.registerFunction 'now', () -> new Date()

Schema.registerFunction 'increment', (i = 0) -> i + 1

module.exports = Schema
