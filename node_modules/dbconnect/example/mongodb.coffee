module.exports =
  getUser:
    select: 'User'
    query: {login: ':login'}
