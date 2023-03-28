# http://stackoverflow.com/questions/6906916/collisions-when-generating-uuids-in-javascript
#random = if window?.crypto?.getRandomBytes
#http://www.broofa.com/2008/09/javascript-uuid-function/
#
# Math.random might not be random enough...
crypto = require 'crypto'

v4 = b = (a) ->
  if a
    (a ^ Math.random() * 16 >> a/4).toString(16)
  else
    ([1e7] + -1e3 + -4e3 + -8e3 + -1e11).replace /[018]/g, b

v4iter = (a,b) ->
  b = a = ''
  while a++ < 36
    b += if a * 51&52
      (if a ^ 15 then 8 ^ Math.random() * (if a ^ 20 then 16 else 4) else 4).toString(16)
    else
      '-'
  b

b2h = []
h2b = {}
for i in [0...256] by 1
  b2h[i] = (i ^ 0x100).toString(16).substring(1)
  h2b[b2h[i]] = i

v42 = () ->
  bytes = crypto.randomBytes(16) # hopefully better random numbers.
  bytes[6] = (bytes[6] & 0x0f) | 0x40 # for v4
  bytes[8] = (bytes[8] & 0x3f) | 0x80
  output = for byte in bytes
    b2h[byte]
  output.splice(4, 0, '-') # another way to join?
  output.splice(7, 0, '-')
  output.splice(10, 0, '-')
  output.splice(13, 0, '-')
  output.join('')

###
// from https://gist.github.com/jed/982883
// and https://gist.github.com/LeverOne/1308368
v4 = function(
  a,b                // placeholders
){
  for(               // loop :)
      b=a='';        // b - result , a - numeric variable
      a++<36;        //
      b+=a*51&52  // if "a" is not 9 or 14 or 19 or 24
                  ?  //  return a random number or 4
         (
           a^15      // if "a" is not 15
              ?      // genetate a random number from 0 to 15
           8^Math.random()*
           (a^20?16:4)  // unless "a" is 20, in which case a random number from 8 to 11
              :
           4            //  otherwise 4
           ).toString(16)
                  :
         '-'            //  in other cases (if "a" is 9,14,19,24) insert "-"
      );
  return b
 }

v4recur = function b(
  a                  // placeholder
){
  return a           // if the placeholder was passed, return
    ? (              // a random number from 0 to 15
      a ^            // unless b is 8,
      Math.random()  // in which case
      * 16           // a random number from
      >> a/4         // 8 to 11
      ).toString(16) // in hexadecimal
    : (              // or otherwise a concatenated string:
      [1e7] +        // 10000000 +
      -1e3 +         // -1000 +
      -4e3 +         // -4000 +
      -8e3 +         // -80000000 +
      -1e11          // -100000000000,
      ).replace(     // replacing
        /[018]/g,    // zeroes, ones, and eights with
        b            // random hex digits
      )
}


// from node-uuid

  // **`parse()` - Parse a UUID into it's component bytes**
  function parse(s, buf, offset) {
    var i = (buf && offset) || 0, ii = 0;

    buf = buf || [];
    s.toLowerCase().replace(/[0-9a-f]{2}/g, function(oct) {
      if (ii < 16) { // Don't overflow!
        buf[i + ii++] = _hexToByte[oct];
      }
    });

    // Zero out remaining bytes if string was short
    while (ii < 16) {
      buf[i + ii++] = 0;
    }

    return buf;
  }

  // **`unparse()` - Convert UUID byte array (ala parse()) into a string**
  function unparse(buf, offset) {
    var i = offset || 0, bth = _byteToHex;
    return  bth[buf[i++]] + bth[buf[i++]] +
            bth[buf[i++]] + bth[buf[i++]] + '-' +
            bth[buf[i++]] + bth[buf[i++]] + '-' +
            bth[buf[i++]] + bth[buf[i++]] + '-' +
            bth[buf[i++]] + bth[buf[i++]] + '-' +
            bth[buf[i++]] + bth[buf[i++]] +
            bth[buf[i++]] + bth[buf[i++]] +
            bth[buf[i++]] + bth[buf[i++]];
  }

###


module.exports =
  v4: v4
  v4iter: v4iter
  v42: v42
