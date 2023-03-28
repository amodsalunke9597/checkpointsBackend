###
  generic database pool. use this to wrap around the regular non-pooled db.

  pool = new Pool(inner, 100)

###

DBConnect = require './dbconnect'
{EventEmitter} = require 'events'

class DBPool extends EventEmitter
  constructor: (@inner, @maxSize = 20) ->
    if not DBConnect.has @inner.name
      DBConnect.setup @inner
    @active = []
    @free = []
    @queue = []
    @on 'release', @onRelease
  acquire: (cb) ->
    if @hasFree()
      @acquireFree cb
    else if @poolNotFull()
      @acquireNew cb
    else
      @waitToAcquire cb
  poolNotFull: () ->
    (@active.length + @free.length) < @maxSize
  acquireNew: (cb) ->
    conn = DBConnect.make @inner.name
    @active.push conn
    conn.connect (err, res) =>
      if err
        @removeFromActive conn
        cb err
      else
        cb null, conn
  hasFree: () ->
    @free.length > 0
  acquireFree: (cb) ->
    conn = @free.shift()
    @active.push conn
    cb null, conn
  waitToAcquire: (cb) ->
    @queue.push cb
  removeFromActive: (conn) ->
    index = @active.indexOf(conn)
    if index >= 0
      @active.splice index, 1
    conn
  release: (conn) ->
    @removeFromActive conn
    @free.push conn
    @emit 'release'
  onRelease: () =>
    if @queue.length > 0
      @acquireFree @queue.shift()

class DBPoolProxy extends DBConnect
  @pools: {}
  @hasPool: (name) ->
    if @pools.hasOwnProperty(name)
      @pools[name]
    else
      undefined
  @makePool: (name, inner, maxSize) ->
    if @hasPool name
      throw new Error("DBPool.duplicate: #{name}")
    @pools[name] = new DBPool(inner, maxSize)
    @pools[name]
  constructor: (@args) ->
    {name, inner, maxSize} = @args
    @pool = @constructor.hasPool name
    if not @pool
      @pool = @makePool name, inner, maxSize
  connect: (cb) ->
    @pool.acquire (err, res) =>
      if err
        cb err
      else
        @inner = res
        cb null, @
  query: (args...) ->
    @inner.query args...
  disconnect: (cb) ->
    @pool.release @inner
    cb null, @

DBConnect.register 'pool', DBPoolProxy

module.exports = DBPoolProxy
