DBConnect = require '../src/main'
schemaInit = require '../example/schema'
uuid = require 'node-uuid'

schema = new DBConnect.Schema('auth')

conn = null

DBConnect.setup
  name: 'test'
  type: 'mongo'
  module: ['../example/mongodb']
  database: 'auth'
  schema: schemaInit(schema)

userArg = {login: 'test', email: 'testa.testing111@gmail.com', uuid: uuid.v4() }

user = null

describe 'can connect', () ->
  it 'can connect', (done) ->
    try
      conn = DBConnect.make 'test'
      conn.open done
    catch e
      done e

  it 'can insert', (done) ->
    try
      conn.query {insert: 'User', args: userArg}, (err, res) ->
        if err
          done err
        else
          try
            test.equal userArg.login, res.login
            test.equal userArg.email, res.email
            test.equal userArg.uuid, res.uuid
            done null
          catch e2
            done e2
    catch e
      done e

  it 'can select', (done) ->
    try
      conn.query {select: 'User'}, (err, recs) ->
        try
          test.ok () -> recs.length > 0
          done err
        catch e2
          done e2
    catch e
      done e

  it 'can call prepared query', (done) ->
    try
      conn.getUser {login: 'test'}, (err, recs) ->
        if err
          done err
        else
          try
            test.equal recs.length, 1
            done null
          catch err
            done err
    catch e
      done e

  it 'can remove', (done) ->
    try
      conn.query {delete: 'test'}, done
    catch e

  it 'can insert', (done) ->
    try
      conn.query {insert: 'test', args: {abc: 1, id: 1}}, (err) ->
        if err
          done err
        else
          conn.query {select: 'test'}, (err, recs) ->
            if err
              done err
            else
              try
                test.equal recs.length, 1
                done null
              catch err
                done err
    catch e
      done e

  it 'can update', (done) ->
    try
      conn.query {update: 'test', $set: {abc: 2}, query: {id: 1}}, (err) ->
        if err
          done err
        else
          conn.query {select: 'test', query: {id: 1}}, (err, recs) ->
            if err
              done err
            else
              try
                test.equal recs.length, 1, "length == 1"
                test.equal recs[0].abc, 2, "abc should be 2 but is #{recs[0].abc}"
                done null
              catch err
                done err
    catch e
      done e

  it 'can save', (done) ->
    try
      conn.query {save: 'test', args: {abc: 2, id: 2}}, (err, recs) ->
        console.log err, recs
        done err
    catch e
      done e
  it 'can delete', (done) ->
    try
      conn.query {delete: 'User', query: {login: 'test'}}, done
    catch e
      done e

  it 'can insert via .insert()', (done) ->
    try
      conn.insert 'User', userArg, (err, u) ->
        if err
          done err
        else
          user = u
          try
            console.log 'User.instanceof.ActiveRecord', user instanceof DBConnect.Schema.Record, user
            test.ok () -> user instanceof DBConnect.Schema.Record
            done null
          catch err
            done err
    catch e
      done e

  it 'can select via .select()', (done) ->
    try
      conn.selectOne 'User', {login: 'test'}, (err, res) ->
        if err
          done err
        else
          user = res
          done null
    catch e
      done e

  it 'can save via .update()', (done) ->
    try
      user.update {
        email: 'test@gmail.com'
        firstName: 'yinso'
        lastName: 'chen'
      }, (err, res) ->
        if err
          done err
        else
          conn.selectOne 'User', {login: 'test'}, (err, res) ->
            if err
              done err
            else
              try
                #console.log 'updated_user', res
                test.equal res.get('email'), user.get('email')
                test.equal res.get('firstName'), user.get('firstName')
                test.equal res.get('lastName'), user.get('lastName')
                done null
              catch err
                done err
    catch e
      done e

  it 'can delete via .delete()', (done) ->
    try
      # this will ensure that the object cannot be used...
      # if we delete from other instantiations we don't really know.
      user.delete (err, res) ->
        if err
          done err
        else
          # user will now not be usable.
          done null
    catch e
      done e

  it 'can remove', (done) ->
    try
      conn.query {delete: 'test'}, done
    catch e

  it 'can disconnect', (done) ->
    try
      conn.close done
    catch e
      done e
