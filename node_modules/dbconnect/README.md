# DBConnect - A Simple Database Interface for NodeJS

DBConnect is a simple database interface for NodeJS.

By default DBConnect comes with MongoDB and Postgresql interface.

# Installation

    npm install dbconnect

# Usage

    var DBConnect = require('dbconnect');
    DBConnect.setup({
        name: 'test',
        type: 'mongo',
        module: <path_to_require_module>,
        args...
    });

    var conn = DBConnect.make('test');

    conn.open(function(err) {
        // handle processing here...

        // query the database.
        conn.query(..., cb);

        // to close.
        conn.close(cb);
    });

## Setup

DBConnect has a setup process that's a bit different from other database interfaces. The design is meant to make
the abstraction over the different drivers as uniform as possible.

`DBConnect.setup` takes the following options

* `name` - this is the key to the name of the connection. You can refer to this later in `DBConnect.make`
* `type` - this is the type of the driver for the connection.

  For example, the built-in MongoDBDriver's type is `mongo`.

* `module` - this points to a node module that holds an initiation routine for the prepared statements
* `other_args` - these are driver specific args that are expected by the driver.

  For example, `MongoDBDriver` expects the foll

## Connection Creation

`DBConnect.make` creates the connection object (without connecting).

You just need to pass in the name of the option that are previously registered via `DBConnect.setup` call.

## Opening the Connection

Either `.connect` or `.open` will do the same thing. It expects a callback.

## Closing the Connection

Either `.disconnect` or `.close` will close the connection. It expects a callback.

## Database Query

The database query is specific to the underlying driver. For example, the built-in MongoDBDriver expects the following

    // for selection
    conn.query({select: 'table', query: {id: 2}}, cb);

    // for insertion
    conn.query({insert: 'table', args: {id: 3, name: 'test'}}, cb);

    // for update
    conn.query({update: 'table', $set: {name: 'foo'}, query: {id: 3}}, cb);

    // for delete
    conn.query({delete: 'table', query: {id: 3}}, cb);

For the Postgresql driver it would look like the following

    conn.query("select * from table", cb);

    conn.query("insert into table (id, name) values (3, 'test')", cb)

    ...

The way DBConnect abstracts over these differences is via prepared statements.

`queryOne` is used the same way as `query`, except that it will return the first item in the result (i.e. using it
with insert/update/delete will result in errors).

## Prepared Statements

A prepared statements has the following signature.

    conn.prepare(<key>, <procedure_running_the_prepare_statement>);

The prepare procedure is a function that has the following signature

    function(conn, args, cb) { ... }

Given that it's an Javascript function, you can do anything you want within the function.

For example, let's say that we have a prepared statement called 'getUser' for the MongoDBDriver.

    conn.prepare('getUser', function(conn, args, cb) {
       conn.query({select: 'user', query: args}, cb);
    });

And we can also have the following prepared statement called 'getUser' for an RDBMS driver.

    conn.prepare('getUser', function(conn, args, cb) {
       conn.query("select * from user where id = ?", args.id, cb);
    });

With the above, we can swap out the underlying driver as long as we setup the appropriate prepare statement function, as
we just have to call the following.

    conn.query('getUser', {id: 5}, cb);

As a matter of fact, `getUser` is also now available from `conn` itself

    conn.getUser({id: 5}, cb);

Yes, `prepare` is equivalent of an extension method. So take care when you are choosing the name of the query,
you don't want to override the existing methods on the `conn` object and its prototype.

## Module for Prepare Statements

You can organize all your prepare statements in a module, and specify it in the `module` parameter of the option object
passed to `DBConnect.setup`.

The module can export the following

* a `Function` expecting the connection object. You can manually call `prepare` or perform any other task as required.
* an object where the key is the name of the prepared statement, and the value is the body for the prepared statement.

## Special Prepare

There is one more function that's called `prepareSpecial`, and this is driver-specific helper to handle mundane task
of generating prepare statement.

For example, the following is what `prepareSpecial` does for MongoDBDriver.

* it expects an object and convert the object into the appropriate prepare function
* the prepare function closes over the object and use it for converting the incoming args into the appropriate query object
  then pass into `.query`.

## ORM & Schema

`dbconnect` has its own mini-ORM. You can access it via the `DBConnect.Schema` object.

    // create a schema object.
    var schema = new DBConnect.Schema('test');

    // add table

    schema.defineTable('User', [
        {col: 'uuid', type: 'uuid', default: {proc: 'makeUUID'}, primary: true}
        {col: 'login', type: 'string', unique: true}
        // more columns ...
    ]);

    // ... more schema options.

    DBConnect.setup({
        name: 'test',
        type: 'mongo',
        schema: schema // NOTE - adding schema here.
    });

    var conn = DBConnect.make('test');

    // now the schema object is accessible via conn.schema

    // insert a record into User table
    // NOTE - these functions will throw error unless a schema object is registered.
    conn.insert('User', {login: 'foobar'}, // NOTE - uuid has a default function to auto-generate an UUID.
      function(err, user) {
        // ...



        conn.delete('User', user, function(err, user) { ... });
      });

The object returned by `conn.insert` is an `DBConnect.Schema.Record` object, which also holds the table it represents
as well as the connection object, so it can perform the following functions.

    // the object returned is user
    user.update({key: val, ...}, function(err) { /* callback */ });

    user.delete(function(err) { /* callback */ });

### Active Record Relation

Based on your schema definition (by using the `reference` in the index), you can setup relationship for the tables.

For example, let's say that we have the following schema:

    schema.defineTable('User', [
      {col: 'uuid', type: 'uuid', default: {proc: 'makeUUID'}, unique: true}
      , {col: 'login', type: 'string', unique: true}
      , {col: 'email', type: 'email', unique: true}
    ]);

    schema.defineTable('Password', [
      {col: 'type', type: 'string', default: 'sha256'}
      , {col: 'salt', type: 'hexString', unique: true, default: {proc: 'randomBytes'}}
      , {col: 'hash', type: 'hexString'}
      , {col: 'userUUID', type: 'uuid', index: true, reference: {table: 'User', columns: ['uuid']}}
    ]);

Once you have created an `user` object via either `conn.insert`, `conn.select`, or `conn.selectOne`, you can then
access a password object via

    user.selectOne('Password', {}, function(err, pass) {
      if (err) {

      } else {
        // pass is an active record as well.
      }
    });

The `object.insert`, `object.select`, and `object.selectOne` has exactly the same interface as the `conn` version, but
the valid tables are currently limited to those that have direct reference to `object.table`.




