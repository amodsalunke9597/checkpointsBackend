DBConnect = require '../src/main'
schemaInit = require '../example/schema'
uuid = require 'node-uuid'

#schema = new DBConnect.Schema('auth')

conn = null

#DBConnect.setup
#  name: 'test2'
#  type: 'postgres'
#  database: 'test'
#  schema: schemaInit(schema)

describe 'schema generation test', () ->
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

  it 'can serialize', (done) ->
    try
      console.log '********** SERIALIZE START **********'
      console.log ''
      console.log JSON.stringify(conn.schema.serialize(), null, 2)
      console.log ''
      console.log '**********  SERIALIZE END  **********'
      done null
    catch e
      done e

  it 'can generate schema', (done) ->
    try
      console.log '********** SCHEMA START **********'
      console.log ''
      console.log conn.generateSchema()
      console.log ''
      console.log '**********  SCHEMA END  **********'
      done null
    catch e
      done e


  it 'can disconnect', (done) ->
    try
      conn.disconnect (err) ->
        done err
    catch e
      done e
