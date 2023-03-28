DBConnect = require '../src/main'
schemaInit = require '../example/schema'
uuid = require 'node-uuid'

schema = new DBConnect.Schema('auth')

conn = null

DBConnect.setup
  name: 'test2'
  type: 'postgres'
  database: 'test'
  user: 'test'
  password: 'password'
  schema: schemaInit(schema)

userArg = {login: 'test', email: 'testa.testing111@gmail.com', uuid: uuid.v4() }

user = null

describe 'postgresql test', () ->

  it 'can connect', (done) ->
    try
      conn = DBConnect.make 'test2'
      conn.connect (err, res) ->
        if err
          done err
        else
          done null
    catch e
      done e

  it 'can create', (done) ->
    try
      conn.query 'create table if not exists test1 (col1 int, col2 int)', {}, (err, res) ->
        console.log 'pg.createTable', err, res
        done err
    catch e
      done e

  it 'can insert', (done) ->
    try
      conn.query "insert into test1 (col1, col2) values ($col1, $col2)", {col1: 1, col2: 2}, (err, res) ->
        console.log 'pg.insert', err, res
        done err
    catch e
      done e

  it 'can select', (done) ->
    try
      conn.query "select * from test1 where col1 = $col1", {col1: 1}, (err, res) ->
        console.log 'pg.select', err, res
        done err
    catch e
      done e

  it 'can selectOne', (done) ->
    try
      conn.queryOne "select * from test1 where col1 = $col1", {col1: 1}, (err, res) ->
        console.log 'pg.selectOne', err, res
        done err
    catch e
      done e

  it 'can update', (done) ->
    try
      conn.query "update test1 set col2 = $col2 where col1 = $col1", {col1: 1, col2: 3}, (err, res) ->
        console.log 'pg.update', err, res
        done err
    catch e
      done e

  it 'can delete', (done) ->
    try
      conn.query "delete from test1 where col2 = $col2", {col2: 3}, (err, res) ->
        console.log 'pg.delete', err, res
        done err
    catch e
      done e

  it 'can use prepare statement', (done) ->
    try
      conn.prepare 'insertTest', (args, cb) ->
        @query "insert into test1 (col1, col2) values ($col1, $col2)", args, cb
      conn.insertTest {col1: 1, col2: 2}, (err, res) ->
        done err
    catch e
      done e

  it 'can use prepare statement', (done) ->
    try
      conn.prepare 'selectTest', (args, cb) ->
        @query "select * from test1 where col1 = $col1", args, cb
      conn.selectTest {col1: 1}, done
    catch e
      done e

  it 'can use prepare statement', (done) ->
    try
      conn.prepare 'deleteTest', (args, cb) ->
        @query "delete from test1", args, cb
      conn.deleteTest {col1: 1, col2: 2}, (err, res) ->
        done err
    catch e
      done e

  it 'can create user', (done) ->
    try
      conn.query 'create table if not exists user_t (id serial primary key, uuid uuid unique not null default uuid_generate_v4(), login varchar(20) unique not null, email varchar(384) unique not null, created timestamp default current_timestamp, modified timestamp default current_timestamp, version int default 1)', {}, (err, res) ->
        console.log 'pg.createTable.password_t', err, res
        done err
    catch e
      done e

  it 'can create password', (done) ->
    try
      conn.query "create table if not exists password_t (id serial primary key, type varchar(32) default 'sha256' not null, salt varchar(64), hash varchar(64), userUUID uuid references user_t (uuid) not null, created timestamp default current_timestamp, modified timestamp default current_timestamp, version int default 1)", {}, (err, res) ->
        console.log 'pg.createTable.user_t', err, res
        done err
    catch e
      done e

  it 'can delete', (done) ->
    try
      conn.query 'delete from user_t', {}, done
    catch e
      done e

  it 'can insert via .insert()', (done) ->
    myDone = (err, res) ->
      if err
        conn.rollback () -> done err
      else
        conn.commit done
    try
      conn.beginTrans (err) ->
        if err
          myDone err
        else
          conn.insert 'User', {login: 'test', email: 'testa.testing111@gmail.com'}, (err, u) ->
            console.log 'user.insert', err, u
            if err
              myDone err
            else
              conn.insert 'Password', {salt: '0000000000', hash: '0000000000', userUUID: u.get('uuid')}, (err, p) ->
                if err
                  myDone err
                else
                  user = u
                  myDone null
    catch e
      done e

  it 'can insert multiple via .insert()', (done) ->
    myDone = conn.doneTrans done
    try
      conn.beginTrans (err) ->
        if err
          return done err
        conn.insert 'User', [{login: 'test1', email: 'test1@gmail.com'}, {login: 'test2', email: 'test2@gmail.com'}], (err, users) ->
          if err
            myDone err
          else
            users.delete myDone
    catch e
      done e

  it 'can select via .selectOne()', (done) ->
    try
      conn.selectOne 'User', {email: 'testa.testing111@gmail.com'}, (err, u) ->
        if err
          done err
        else
          user = u
          done null
    catch e
      done e

  it 'can select via .selectOne() with IN query', (done) ->
    try
      conn.selectOne 'User', {email: ['testa.testing111@gmail.com']}, (err, u) ->
        if err
          done err
        else
          user = u
          done null
    catch e
      done e

  it 'can use mixin', (done) ->
    try
      # conn.select ought to return a recordset that can be further used to select via IN.
      # this is something that'll
      conn.selectOne 'Password', {userUUID: user.get('uuid')}, (err, p) ->
        if err
          done err
        else
          p.verify 'mock-password', (err) ->
            if err
              done err
            else
              done null
    catch e
      done e

  it 'can use record.selectOne()', (done) ->
    try
      user.selectOne 'Password', (err, p) ->
        if err
          done err
        else
          p.verify 'mock-password', (err) ->
            if err
              done err
            else
              done null
    catch e
      done e

  it 'can update via .update()', (done) ->
    try
      user.update {email: 'test@gmail.com'}, (err) ->
        if err
          done err
        else
          done null
    catch e
      done e

  it 'can delete via .delete()', (done) ->
    myDone = (err, res) ->
      if err
        conn.rollback () -> done err
      else
        conn.commit done
    try
      conn.beginTrans (err) ->
        if err
          myDone err
        else
          conn.query 'delete from password_t where userUUID = $uuid', {uuid: user.get('uuid')}, (err) ->
            if err
              myDone err
            else
              user.delete myDone
    catch e
      done e

  it 'can issue transaction', (done) ->
    myDone = (err, res) ->
      if err
        conn.rollback () -> done err
      else
        conn.commit done
    try
      conn.beginTrans (err) ->
        if err
          myDone err
        else
          conn.query "insert into test1 (col1, col2) values ($col1, $col2)", {col1: 1, col2: 2}, (err) ->
            if err
              myDone err
            else
              conn.query 'delete from test1', {}, (err) ->
                if err
                  myDone err
                else
                  myDone null
    catch e
      done e

  it 'can disconnect', (done) ->
    try
      conn.disconnect (err) ->
        done err
    catch e
      done e
