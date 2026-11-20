
namespace Lago {
    int main (string[] raw_args) {
        var socket_uri = "/tmp/rofi_notification_daemon";
        bool show_help = false;
        bool show_version = false;
        bool options_done = false;
        string[] operands = {};

        // Options may appear anywhere; "--" makes every later argument an operand.
        for (int i = 1; i < raw_args.length; i++) {
            var arg = raw_args[i];

            if (options_done || arg == "-" || !arg.has_prefix ("-")) {
                operands += arg;
                continue;
            }

            switch (arg) {
                case "--":
                    options_done = true;
                    break;
                case "-s":
                    if (i + 1 >= raw_args.length) {
                        return fail ("option '-s' needs a socket path");
                    }
                    socket_uri = raw_args[++i];
                    break;
                case "-h":
                case "--help":
                    show_help = true;
                    break;
                case "-v":
                case "--version":
                    show_version = true;
                    break;
                default:
                    return fail ("unknown option '%s'".printf (arg));
            }
        }

        if (show_version) {
            print ("lago 0.1.0 (C) 2021 Ken Gilmer\n");
            return 0;
        }

        if (show_help || operands.length == 0) {
            print_usage ();
            return 0;
        }

        var command = operands[0];

        try {
            Client client = new Client (socket_uri);

            switch (command) {
                case "ls":
                    if (operands.length > 1) return fail ("'ls' takes no operand");

                    var notifications = client.get_notifications ();

                    restore_default_sigpipe ();
                    foreach (var notification in notifications) {
                        stdout.printf ("[%s] %s (%s) - %s \n", notification.id, notification.application, fmt_urgency (notification.urgency), notification.summary);
                        print_body (notification.body);
                    }
                    stdout.flush ();
                    if (stdout.error () != 0) return fail ("cannot write the listing");
                    break;
                case "rm":
                    if (operands.length != 2) return fail ("'rm' takes exactly one notification id or application name");

                    var modifier = operands[1];

                    if (modifier.strip () == "") return fail ("'rm' needs a notification id or application name that is not blank");
                    if ("\n" in modifier) return fail ("'rm' cannot dismiss an application name holding a newline");

                    var id = parse_id (modifier);
                    if (id != null) {
                        client.delete_notification_by_id (id);
                    } else {
                        client.delete_notification_by_app (modifier);
                    }
                    break;
                case "clear":
                    if (operands.length > 1) return fail ("'clear' takes no operand");

                    var notifications = client.get_notifications ();

                    foreach (var notification in notifications) {
                        client.delete_notification_by_id (notification.id);
                    }
                    break;
                default:
                    print_usage ();
                    return 1;
            }
        } catch (ClientError err) {
            return fail (err.message);
        }

        return 0;
    }

    /**
     * Reports a failure as a single line on stderr and returns the exit status.
     */
    int fail (string message) {
        var line = new StringBuilder ("lago: ");

        // Arguments and paths are echoed: keep control characters from breaking the line.
        for (int i = 0; i < message.length; i++) {
            uchar c = (uchar) message[i];
            if (c < 0x20 || c == 0x7f) {
                line.append_printf ("\\x%02x", c);
            } else {
                line.append_c ((char) c);
            }
        }
        line.append_c ('\n');
        restore_default_sigpipe ();
        printerr ("%s", line.str);

        return 1;
    }

    /**
     * GSocket sets SIGPIPE to ignored for the whole process when lago opens
     * its first socket. lago writes its output only after the daemon
     * exchange, so the default is put back before writing: when nothing reads
     * the output any more (lago ls | head -1), lago ends quietly by SIGPIPE,
     * as it already does for the help and version text.
     */
    void restore_default_sigpipe () {
        Posix.signal (Posix.Signal.PIPE, Posix.SIG_DFL);
    }

    /**
     * An operand made only of ASCII digits names a notification id when it fits
     * a signed 64-bit integer. Returns the id in decimal, or null for an
     * application name.
     */
    string? parse_id (string operand) {
        for (int i = 0; i < operand.length; i++) {
            if (!(operand[i] >= '0' && operand[i] <= '9')) return null;
        }

        int start = 0;
        while (start < operand.length - 1 && operand[start] == '0') start++;
        var digits = operand.substring (start);

        var max = int64.MAX.to_string ();
        if (digits.length > max.length || (digits.length == max.length && strcmp (digits, max) > 0)) {
            return null;
        }

        return digits;
    }

    /**
     * Prints each line of the body on its own line, preceded by a tab.
     */
    void print_body (string body) {
        int start = 0;
        int end;

        while ((end = body.index_of_char ('\n', start)) >= 0) {
            stdout.printf ("\t%s\n", body.substring (start, end - start));
            start = end + 1;
        }
        stdout.printf ("\t%s\n", body.substring (start));
    }

    // https://specifications.freedesktop.org/notification-spec/notification-spec-latest.html#urgency-levels
    private string fmt_urgency(int64 urgency) {
        switch (urgency) {
            case 0: return "Low";
            case 1: return "Normal";
            case 2: return "Critical";
            default: return "Unknown";
        }
    }

    void print_usage () {
        print ("""
        Usage:
        lago [ ls | rm <id> | rm <app> | clear ]
        
        Help Options:
        -h, --help                           Show help options
        
        Application Options:
        -v, --version                        Display version number
        -s <Socket URI>                      Socket path to connect to notification server
        """);

        print ("\n");
    }
}
