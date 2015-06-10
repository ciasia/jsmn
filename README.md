
JSMN
====

jsmn (pronounced like 'jasmine') is a minimalistic JSON parser. 

You can find more information about JSON format at [json.org][1]

This is a NetLinx port of the original C implementation. Further information on jsmn can be found at [http://zserge.com/jsmn.html][2]

Philosophy
----------

Most JSON parsers offer you a bunch of functions to load JSON data, parse it and extract any value by its name. jsmn proves that checking the correctness of every JSON packet or allocating temporary objects to store parsed JSON fields often is an overkill. 

JSON format itself is extremely simple, so why should we complicate it?

jsmn is designed to be  **robust** (it should work fine even with erroneous data), **fast** (it should parse data on the fly), **portable** (no superfluous dependencies). And of course, **simplicity** is a key feature - simple code style, simple algorithm, simple integration into other projects.

Features
--------

* no dependencies
* extremely small code footprint
* API contains only 2 functions
* incremental single-pass parsing

Design
------

The rudimentary jsmn object is a **token**. Let's consider a JSON string:

    '{ "name" : "Jack", "age" : 27 }'

It holds the following tokens:

* Object: `{ "name" : "Jack", "age" : 27}` (the whole object)
* Strings: `"name"`, `"Jack"`, `"age"` (keys and some values)
* Number: `27`

In jsmn, tokens do not hold any data, but point to token boundaries in JSON string instead. In the example above jsmn will create tokens like: Object [1..32], String [4..8], String [13..17], String [21..24], Number [28..30].

Every jsmn token has a type, which indicates the type of corresponding JSON token. jsmn supports the following token types:

* Object - a container of key-value pairs, e.g.:
    `{ "foo":"bar", "x":0.3 }`
* Array - a sequence of values, e.g.:
    `[ 1, 2, 3 ]`
* String - a quoted sequence of chars, e.g.: `"foo"`
* Primitive - a number, a boolean (`true`, `false`) or `null`

Besides start/end positions, jsmn tokens for complex types (like arrays or objects) also contain a number of child items, so you can easily follow object hierarchy.

This approach provides enough information for parsing any JSON data and makes it possible to use zero-copy techniques.

Install
-------

To clone the repository you should have git installed. Just run:

    $ git clone https://bitbucket.org/KimBurgess/jsmn

Once you have a local copy, bring into your workspace and include where required. Multiple includes will be ignored.

    include 'jsmn.axi'


API
---

Token types are described the following set of constants and are declared as such within jsmn.axi:

    JSMN_PRIMITIVE = 0
    JSMN_OBJECT = 1
    JSMN_ARRAY = 2
    JSMN_STRING = 3

**Note:** Unlike JSON data types, primitive tokens are not divided into
numbers, booleans and null, because one can easily tell the type using the
first character:

* `'t', 'f'` - boolean 
* `'n'` - null
* `'-', '0'..'9'` - number

Token is an structure of `jsmn_token` type:

    structure jsmn_token {
        integer type    // Token type
        int start       // Token start position (inclusive)
        int end         // Token end position (exclusive)
        int size        // Number of child (nested) tokens
    }

**Note:** string tokens point to the first character after
the opening quote and the previous symbol before final quote. This was made 
to simplify string extraction from JSON data.

All work is done by `jsmn_parser` object. You can initialize a new parser using:

    stack_var jsmn_parser parser;
    stack_var jsmn_token tokens[10];

    jsmn_init(parser);

    // json - character array containing the JSON to parse
    // tokens - an array of tokens available
    // 10 - number of tokens available
    jsmn_parse(parser, json, tokens);

This will create a parser, and then it tries to parse up to `max_length_array(tokens)` JSON tokens from the `json` string.

A non-negative reutrn value of `jsmn_parse` is the number of tokens actually
used by the parser.

If something goes wrong, you will get an error. Error will be one of these:

* `JSMN_ERROR_INVAL` - bad token, JSON string is corrupted
* `JSMN_ERROR_NOMEM` - not enough tokens, JSON string is too large
* `JSMN_ERROR_PART` - JSON string is too short, expecting more JSON data

If you get `JSON_ERROR_NOMEM`, you can re-allocate more tokens and call
`jsmn_parse` once more.  If you read json data from the stream, you can
periodically call `jsmn_parse` and check if return value is `JSON_ERROR_PART`.
You will get this error until you reach the end of JSON data.

Other info
----------

This software is distributed under [MIT license](http://www.opensource.org/licenses/mit-license.php), so feel free to integrate it in your commercial products.

[1]: http://www.json.org/
[2]: http://zserge.com/jsmn.html