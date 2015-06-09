PROGRAM_NAME='jsmn'
#if_not_defined __JSMN_LIB_
#define __JSMN_LIB_


#define JSMN_STRICT


DEFINE_CONSTANT

// Token types
integer JSMN_PRIMITIVE = 0;
integer JSMN_OBJECT = 1;
integer JSMN_ARRAY = 2;
integer JSMN_STRING = 3;

// Parse errors
sinteger JSMN_ERROR_NOMEM = -1;     // Not enough tokens provided
sinteger JSMN_ERROR_INVAL = -2;     // Invalid character inside JSON string
sinteger JSMN_ERROR_PART = -3;      // The string is not a full JSON packet, more bytes expected

// Non-printable chars
char JSMN_CHAR_NULL = $00;
char JSMN_CHAR_TAB = $09;
char JSMN_CHAR_LF = $0a;
char JSMN_CHAR_CR = $0d;


DEFINE_TYPE

structure jsmn_token {
    integer type
    integer start
    integer end
    integer size
};

structure jsmn_parser {
    integer pos
    integer toknext
    integer toksuper
};


/**
 * Allocates a fresh unused token from the token pool.
 *
 * @param   parser      the parser state object in use
 * @param   tokens      token pool array
 * @return              a index into tokens providing the token to use, 0 if
 *                      all are in use
 */
define_function integer jsmn_alloc_token(jsmn_parser parser, jsmn_token tokens[]) {
    stack_var integer idx;

    if (parser.toknext >= max_length_array(tokens)) {
        return 0;
    }

    idx = parser.toknext;
    parser.toknext++;
    tokens[idx].start = 0;
    tokens[idx].end = 0;
    tokens[idx].size = 0;

    set_length_array(tokens, idx);

    return idx;
}


/**
 * Fills token type and boundaries.
 */
define_function jsmn_fill_token(integer token_idx, jsmn_token tokens[],
        integer type, integer start, integer end) {
    tokens[token_idx].type = type;
    tokens[token_idx].start = start;
    tokens[token_idx].end = end;
    tokens[token_idx].size = 0;
}


/**
 * Fills next available token with JSON primitive.
 */
define_function sinteger jsmn_parse_primitive(jsmn_parser parser, char json[],
        jsmn_token tokens[]) {
    stack_var integer len;
    stack_var integer token_idx;
    stack_var integer start;
    stack_var char found;

    len = length_string(json);
    start = parser.pos;
    found = false;

    for (; parser.pos <= len && json[parser.pos] != JSMN_CHAR_NULL; parser.pos++) {
        switch (json[parser.pos]) {
#if_not_defined JSMN_STRICT
            case ':':
#end_if
            case JSMN_CHAR_TAB:
            case JSMN_CHAR_LF:
            case JSMN_CHAR_CR:
            case ' ':
            case ',':
            case ']':
            case '}': {
                found = true;
            }
        }

        if (found) {
            break;
        }

        if (json[parser.pos] < 32 || json[parser.pos] >= 127) {
            parser.pos = start;
            return JSMN_ERROR_INVAL;
        }
    }

#if_defined JSMN_STRICT
    if (!found) {
        parser.pos = start;
        return JSMN_ERROR_PART;
    }
#end_if

    token_idx = jsmn_alloc_token(parser, tokens);
    if (!token_idx) {
        parser.pos = start;
        return JSMN_ERROR_NOMEM;
    }

    jsmn_fill_token(token_idx, tokens, JSMN_PRIMITIVE, start, parser.pos);
    parser.pos--;
    return 0;
}


/**
 * Fills the next token with JSON string.
 */
define_function sinteger jsmn_parse_string(jsmn_parser parser, char json[],
        jsmn_token tokens[]) {
    stack_var integer len;
    stack_var integer token_idx;
    stack_var integer start;

    len = length_string(json);
    start = parser.pos;

    // Skip starting quote
    parser.pos++;

    for (; parser.pos <= len && json[parser.pos] != JSMN_CHAR_NULL; parser.pos++) {
        stack_var char c;

        c = json[parser.pos];

        // Quote: end of string
        if (c == '"') {
            token_idx = jsmn_alloc_token(parser, tokens);
            if (!token_idx) {
                parser.pos = start;
                return JSMN_ERROR_NOMEM;
            }
            jsmn_fill_token(token_idx, tokens, JSMN_STRING, start+1, parser.pos);
            return 0;
        }

        // Backslash: Quoted symbol expected
        if (c == '\' && parser.pos + 1 <= len) {
            stack_var integer i;

            parser.pos++;

            switch (json[parser.pos]) {
                case '"':
                case '/':
                case '\':
                case 'b':
                case 'f':
                case 'r':
                case 'n':
                case 't': {
                    break;
                }

                case 'u': {
                    parser.pos++;
                    for(i = 0; i < 4 && parser.pos <= len && json[parser.pos] != JSMN_CHAR_NULL; i++) {
                        // If it isn't a hex character we have an error
                        if(!((json[parser.pos] >= '0' && json[parser.pos] <= '9') ||
                                (json[parser.pos] >= 'A' && json[parser.pos] <= 'F') ||
                                (json[parser.pos] >= 'a' && json[parser.pos] <= 'f'))) {
                            parser.pos = start;
                            return JSMN_ERROR_INVAL;
                        }
                        parser.pos++;
                    }
                    parser.pos--;
                    break;
                }

                default:
                    parser.pos = start;
                    return JSMN_ERROR_INVAL;
            }
        }
    }

    parser.pos = start;
    return JSMN_ERROR_PART;
}


/**
 * Parse JSON string and fill tokens.
 */
define_function slong jsmn_parse(jsmn_parser parser, char json[],
        jsmn_token tokens[]) {
    stack_var sinteger r;
    stack_var integer len;
    stack_var integer i;
    stack_var integer token_idx;
    stack_var integer count;
    
    len = length_string(json);
    count = 0;

    for (; parser.pos <= len && json[parser.pos] != JSMN_CHAR_NULL; parser.pos++) {
        stack_var char c;
        stack_var integer type;

        c = json[parser.pos];
        switch (c) {
            case '{':   
            case '[': {
                count++;
                token_idx = jsmn_alloc_token(parser, tokens);
                if (!token_idx) {
                    return JSMN_ERROR_NOMEM;
                }

                if (parser.toksuper) {
                    tokens[parser.toksuper].size++;
                }

                if (c == '{') {
                    tokens[token_idx].type = JSMN_OBJECT
                } else {
                    tokens[token_idx].type = JSMN_ARRAY
                }

                tokens[token_idx].start = parser.pos;
                parser.toksuper = parser.toknext - 1;
            }

            case '}':
            case ']': {
                if (c == '}') {
                    type = JSMN_OBJECT
                } else {
                    type = JSMN_ARRAY
                }

                for (i = parser.toknext - 1; i > 0; i--) {
                    if (tokens[i].start && !tokens[i].end) {
                        if (tokens[i].type != type) {
                            return JSMN_ERROR_INVAL;
                        }
                        parser.toksuper = 0;
                        tokens[i].end = parser.pos + 1;
                        break;
                    }
                }

                // Error if unmatched closing bracket
                if (!i){
                    return JSMN_ERROR_INVAL;
                }

                for (; i > 0; i--) {
                    if (tokens[i].start && !tokens[i].end) {
                        parser.toksuper = i;
                        break;
                    }
                }
            }

            case '"': {
                r = jsmn_parse_string(parser, json, tokens);
                if (r < 0) {
                    return r;
                }
                count++;
                if (parser.toksuper) {
                    tokens[parser.toksuper].size++;
                }
            }

            case JSMN_CHAR_TAB:
            case JSMN_CHAR_CR:
            case JSMN_CHAR_LF:
            case ' ': {
                break;
            }

            case ':': {
                parser.toksuper = parser.toknext - 1;
            }

            case ',': {
                if (tokens[parser.toksuper].type != JSMN_ARRAY &&
                        tokens[parser.toksuper].type != JSMN_OBJECT) {
                    for (i = parser.toknext - 1; i > 0; i--) {
                        if (tokens[i].type == JSMN_ARRAY ||
                                tokens[i].type == JSMN_OBJECT) {
                            if (tokens[i].start && !tokens[i].end) {
                                parser.toksuper = i;
                                break;
                            }
                        }
                    }
                }
            }

#if_defined JSMN_STRICT
            // In strict mode primitives are: numbers, booleans or null
            case '-':
            case '0':
            case '1':
            case '2':
            case '3':
            case '4':
            case '5':
            case '6':
            case '7':
            case '8':
            case '9':
            case 't':
            case 'f':
            case 'n': {
                // And they must not be keys of the object
                if (tokens[parser.toksuper].type == JSMN_OBJECT ||
                        (tokens[parser.toksuper].type == JSMN_STRING &&
                        tokens[parser.toksuper].size != 0)) {
                    return JSMN_ERROR_INVAL;
                }
#else
            // In non-strict mode every unquoted value is a primitive
            default: {
#end_if
                r = jsmn_parse_primitive(parser, json, tokens);
                if (r < 0){
                    return r;
                }
                count++;
                if (parser.toksuper) {
                    tokens[parser.toksuper].size++;
                }
            }

#if_defined JSMN_STRICT
            // Unexpected char in strict mode
            default: {
                return JSMN_ERROR_INVAL;
            }
#end_if
        }
    }

    for (i = parser.toknext - 1; i > 0; i--) {
        // Unmatched opened object or array
        if (tokens[i].start && !tokens[i].end) {
            return JSMN_ERROR_PART;
        }
    }

    set_length_array(tokens, count);

    return count;
}


/**
 * Creates a new parser based over a given  buffer with an array of tokens
 * available.
 */
define_function jsmn_init(jsmn_parser parser) {
    parser.pos = 1;
    parser.toknext = 1;
    parser.toksuper = 0;
}


/**
 * Tokenise a JSON string
 */
define_function slong json_tokenise(char json[], jsmn_token tokens[]) {
    stack_var jsmn_parser parser;

    jsmn_init(parser);

    return jsmn_parse(parser, json, tokens);
}


/**
 * Compare a string to a JSON token
 */
define_function char json_token_str_eq(char json[], jsmn_token t, char s[]) {
    return mid_string(json, t.start, t.end - t.start) == s;
}


#end_if __JSMN_LIB_

