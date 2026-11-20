/**
 * A strict reader for the reply to rofication's `list` request.
 *
 * A reply is exactly one JSON value (RFC 8259, no extensions), surrounded only by
 * whitespace. It must be an array of objects, and every object must carry an
 * integer `id`. Ids are kept as decimal text: rofication does not limit them to
 * 64 bits.
 */
namespace Lago {
    internal class ReplyParser {
        private enum Kind {
            STRING,
            INTEGER,
            NUMBER,
            LITERAL,
            NULL,
            CONTAINER
        }

        private uint8* data;
        private size_t length;
        private size_t pos = 0;

        private ReplyParser (uint8[] data) {
            this.data = data;
            this.length = data.length;
        }

        public static List<NotificationDesc> parse (uint8[] data) throws ClientError {
            if (data.length == 0) {
                throw new ClientError.INVALID_REPLY ("the reply is empty");
            }
            // With an explicit length this also rejects NUL bytes.
            if (!((string) data).validate (data.length)) {
                throw new ClientError.INVALID_REPLY ("the reply is not valid UTF-8");
            }

            return new ReplyParser (data).read_reply ();
        }

        private List<NotificationDesc> read_reply () throws ClientError {
            var list = new List<NotificationDesc> ();

            skip_whitespace ();
            if (peek () != '[') {
                skip_value ();
                expect_end ();
                throw new ClientError.INVALID_REPLY ("the reply is not a JSON array");
            }
            pos++;
            skip_whitespace ();
            if (peek () == ']') {
                pos++;
            } else {
                while (true) {
                    skip_whitespace ();
                    list.prepend (read_notification ());
                    skip_whitespace ();
                    if (peek () != ',') break;
                    pos++;
                }
                expect (']');
            }
            expect_end ();
            list.reverse ();

            return list;
        }

        private NotificationDesc read_notification () throws ClientError {
            if (peek () != '{') {
                skip_value ();
                throw new ClientError.INVALID_REPLY ("the reply holds an element that is not an object");
            }
            pos++;

            string? id = null;
            string summary = "";
            string body = "";
            string application = "";
            // A missing urgency is Normal, the daemon's own default.
            int urgency = 1;

            skip_whitespace ();
            if (peek () == '}') {
                pos++;
            } else {
                while (true) {
                    skip_whitespace ();
                    var name = read_string (true);
                    skip_whitespace ();
                    expect (':');
                    skip_whitespace ();

                    string? text;
                    switch (name) {
                        case "id":
                            id = read_value (out text) == Kind.INTEGER ? canonical_integer (text) : null;
                            break;
                        case "summary":
                            summary = read_value (out text) == Kind.STRING ? text : "";
                            break;
                        case "body":
                            body = read_value (out text) == Kind.STRING ? text : "";
                            break;
                        case "application":
                            application = read_value (out text) == Kind.STRING ? text : "";
                            break;
                        case "urgency":
                            switch (read_value (out text)) {
                                case Kind.NULL:
                                    urgency = 1;
                                    break;
                                case Kind.INTEGER:
                                    urgency = urgency_level (canonical_integer (text));
                                    break;
                                default:
                                    urgency = NotificationDesc.URGENCY_UNKNOWN;
                                    break;
                            }
                            break;
                        default:
                            skip_value ();
                            break;
                    }

                    skip_whitespace ();
                    if (peek () != ',') break;
                    pos++;
                }
                expect ('}');
            }

            if (id == null) {
                throw new ClientError.INVALID_REPLY ("the reply holds an element without an integer id");
            }

            return new NotificationDesc (id, summary, body, application, urgency);
        }

        private static string canonical_integer (string literal) {
            return literal == "-0" ? "0" : literal;
        }

        private static int urgency_level (string integer) {
            switch (integer) {
                case "0": return 0;
                case "1": return 1;
                case "2": return 2;
                default: return NotificationDesc.URGENCY_UNKNOWN;
            }
        }

        /**
         * Reads one value. Strings are decoded and numbers returned as written;
         * arrays and objects are checked and skipped.
         */
        private Kind read_value (out string? text) throws ClientError {
            text = null;
            switch (peek ()) {
                case '"':
                    text = read_string (true);
                    return Kind.STRING;
                case '[':
                case '{':
                    skip_value ();
                    return Kind.CONTAINER;
                case 't':
                    read_literal ("true");
                    return Kind.LITERAL;
                case 'f':
                    read_literal ("false");
                    return Kind.LITERAL;
                case 'n':
                    read_literal ("null");
                    return Kind.NULL;
                default:
                    return read_number (out text);
            }
        }

        /**
         * Checks and skips any value. Nesting is tracked on an explicit stack, so
         * deeply nested replies cannot exhaust the call stack.
         */
        private void skip_value () throws ClientError {
            var open = new ByteArray ();
            string? text;

            while (true) {
                bool complete = true;
                uint8 c = peek ();

                if (c == '[' || c == '{') {
                    pos++;
                    skip_whitespace ();
                    if (peek () == closing (c)) {
                        pos++;
                    } else {
                        open.append ({ c });
                        if (c == '{') skip_member_name ();
                        complete = false;
                    }
                } else if (c == '"') {
                    read_string (false);
                } else if (c == 't') {
                    read_literal ("true");
                } else if (c == 'f') {
                    read_literal ("false");
                } else if (c == 'n') {
                    read_literal ("null");
                } else {
                    read_number (out text);
                }

                // Close finished containers until one expects another value.
                while (complete && open.len > 0) {
                    uint8 top = open.data[open.len - 1];

                    skip_whitespace ();
                    if (peek () == ',') {
                        pos++;
                        if (top == '{') skip_member_name ();
                        complete = false;
                    } else {
                        expect (closing (top));
                        open.set_size (open.len - 1);
                    }
                }

                if (complete) return;
                skip_whitespace ();
            }
        }

        private void skip_member_name () throws ClientError {
            skip_whitespace ();
            read_string (false);
            skip_whitespace ();
            expect (':');
            skip_whitespace ();
        }

        private static uint8 closing (uint8 opening) {
            return opening == '[' ? ']' : '}';
        }

        private string? read_string (bool decode) throws ClientError {
            expect ('"');

            StringBuilder? builder = null;
            if (decode) builder = new StringBuilder ();
            size_t run = pos;

            while (true) {
                if (pos >= length) {
                    throw syntax_error ("unterminated string");
                }

                uint8 c = data[pos];
                if (c == '"') {
                    if (builder != null) builder.append_len ((string) (data + run), (ssize_t) (pos - run));
                    pos++;
                    return builder != null ? builder.str : null;
                } else if (c < 0x20) {
                    throw syntax_error ("unescaped control character in a string");
                } else if (c != '\\') {
                    pos++;
                    continue;
                }

                if (builder != null) builder.append_len ((string) (data + run), (ssize_t) (pos - run));
                pos++;
                c = peek ();
                pos++;
                switch (c) {
                    case '"':
                    case '\\':
                    case '/':
                        builder?.append_c ((char) c);
                        break;
                    case 'b':
                        builder?.append_c ('\b');
                        break;
                    case 'f':
                        builder?.append_c ('\f');
                        break;
                    case 'n':
                        builder?.append_c ('\n');
                        break;
                    case 'r':
                        builder?.append_c ('\r');
                        break;
                    case 't':
                        builder?.append_c ('\t');
                        break;
                    case 'u':
                        unichar u = read_escaped_char ();
                        builder?.append_unichar (u);
                        break;
                    default:
                        throw syntax_error ("invalid escape in a string");
                }
                run = pos;
            }
        }

        /**
         * Decodes the hex digits of a \u escape, combining a surrogate pair.
         * Lone surrogates and U+0000 cannot be held in the client's strings and
         * become U+FFFD.
         */
        private unichar read_escaped_char () throws ClientError {
            unichar u = read_hex4 ();

            if (u >= 0xD800 && u <= 0xDBFF) {
                if (pos + 1 < length && data[pos] == '\\' && data[pos + 1] == 'u') {
                    size_t mark = pos;
                    pos += 2;
                    unichar low = read_hex4 ();
                    if (low >= 0xDC00 && low <= 0xDFFF) {
                        return 0x10000 + ((u - 0xD800) << 10) + (low - 0xDC00);
                    }
                    // Not a pair: decode the second escape on its own.
                    pos = mark;
                }
                return 0xFFFD;
            }
            if ((u >= 0xDC00 && u <= 0xDFFF) || u == 0) {
                return 0xFFFD;
            }

            return u;
        }

        private unichar read_hex4 () throws ClientError {
            unichar u = 0;

            for (int i = 0; i < 4; i++) {
                int digit = ((char) peek ()).xdigit_value ();
                if (digit < 0) {
                    throw syntax_error ("invalid \\u escape in a string");
                }
                u = (u << 4) | digit;
                pos++;
            }

            return u;
        }

        private Kind read_number (out string text) throws ClientError {
            size_t start = pos;
            bool integer = true;

            if (peek () == '-') pos++;
            if (peek () == '0') {
                pos++;
            } else if (is_digit (peek ())) {
                skip_digits ();
            } else {
                throw syntax_error ("expected a JSON value");
            }
            if (peek () == '.') {
                integer = false;
                pos++;
                if (!is_digit (peek ())) throw syntax_error ("invalid number");
                skip_digits ();
            }
            if (peek () == 'e' || peek () == 'E') {
                integer = false;
                pos++;
                if (peek () == '+' || peek () == '-') pos++;
                if (!is_digit (peek ())) throw syntax_error ("invalid number");
                skip_digits ();
            }

            text = ((string) (data + start)).substring (0, (long) (pos - start));

            return integer ? Kind.INTEGER : Kind.NUMBER;
        }

        private void skip_digits () {
            while (is_digit (peek ())) pos++;
        }

        private static bool is_digit (uint8 c) {
            return c >= '0' && c <= '9';
        }

        private void read_literal (string literal) throws ClientError {
            if (length - pos < literal.length || Memory.cmp (data + pos, literal, literal.length) != 0) {
                throw syntax_error ("expected a JSON value");
            }
            pos += literal.length;
        }

        private void skip_whitespace () {
            while (pos < length) {
                switch (data[pos]) {
                    case ' ':
                    case '\t':
                    case '\n':
                    case '\r':
                        pos++;
                        break;
                    default:
                        return;
                }
            }
        }

        private void expect (uint8 c) throws ClientError {
            if (peek () != c) {
                throw syntax_error ("expected '%c'".printf (c));
            }
            pos++;
        }

        private void expect_end () throws ClientError {
            skip_whitespace ();
            if (pos != length) {
                throw syntax_error ("unexpected data after the JSON value");
            }
        }

        /** The next byte, or NUL at the end: a validated reply holds no NUL bytes. */
        private uint8 peek () {
            return pos < length ? data[pos] : 0;
        }

        private ClientError syntax_error (string what) {
            if (pos >= length) {
                return new ClientError.INVALID_REPLY ("the reply is not valid JSON (%s at its end)", what);
            }
            return new ClientError.INVALID_REPLY ("the reply is not valid JSON (%s at byte %" + size_t.FORMAT + ")", what, pos);
        }
    }
}
