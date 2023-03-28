module.exports = (schema) ->

  schema.defineTable 'User', [
    {col: 'uuid', type: 'uuid', default: {proc: 'makeUUID'}, unique: true}
    {col: 'login', type: {string: {max: 20}}, unique: true}
    {col: 'email', type: 'email', unique: true}
    {col: 'created', type: 'datetime', default: {proc: 'now'}}
    {col: 'modified', type: 'datetime', default: {proc: 'now'}, update: {proc: 'now'}}
    {col: 'version', type: 'integer', default: 1, update: {proc: 'increment'}}
  ]

  schema.defineTable 'Password', [
    {col: 'type', type: {string: {max: 32}}, default: 'sha256', unique: true}
    {col: 'salt', type: {'hexString': {max: 64}}, unique: true, default: {proc: 'randomBytes'}}
    {col: 'hash', type: {'hexString': {max: 64}}}
    {col: 'userUUID', type: 'uuid', unique: true, reference: {table: 'User', columns: ['uuid']}}
    {col: 'created', type: 'datetime', default: {proc: 'now'}}
    {col: 'modified', type: 'datetime', default: {proc: 'now'}, update: {proc: 'now'}}
    {col: 'version', type: 'integer', default: 1, update: {proc: 'increment'}}
  ], {
    verify: (passwd, cb) ->
      if passwd == 'mock-password'
        cb null, @
      else
        cb new Error("invalid_password")
  }

#  schema.defineIndex {
#    name: 'indexUserPassword'
#    index: ['userUUID']
#    table: 'Password'
#    reference:
#      table: 'User'
#      columns: ['uuid']
#  }

  schema
