
namespace Lago {
    int main (string[] raw_args) {
        var socket_uri = "/tmp/rofi_notification_daemon";

        HashTable<string, string ? > args;

        try {
            args = parse_args (raw_args);
        } catch (Error e) {
            printerr ("error: %s\n", e.message);
            printerr ("Run '%s --help' to see a full list of available command line options.\n", raw_args[0]);
            return 1;
        }

        if (args.contains ("-v") || args.contains ("--version")) {
            print ("lago 0.1.0 (C) 2021 Ken Gilmer\n");
            return 0;
        }

        if (args.contains ("-h") || args.contains ("--help") || raw_args.length < 2) {
            print_usage ();
            return 0;
        }

        if (args.contains ("-s")) socket_uri = args.lookup ("-s");
        var command = raw_args[1];

        try {
            Client client = new Client (socket_uri);

            switch (command) {
                case "ls":
                    var notifications = client.get_notifications ();

                    foreach (var notification in notifications) {
                        stdout.printf ("[%" + uint64.FORMAT_MODIFIER + "d] %s (%s) - %s \n\t%s\n", notification.id, notification.application, fmt_urgency(notification.urgency), notification.summary, notification.body);
                    }
                    break;
                case "rm":
                    var modifier = raw_args[2];

                    if (modifier != null) {
                        var id = int64.parse (modifier);

                        if (id == 0) {
                            client.delete_notification_by_app (modifier);
                        } else {
                            client.delete_notification_by_id (id);
                        }
                    } else {
                        print_usage ();
                        return 0;
                    }
                    break;
                case "clear":
                    var notifications = client.get_notifications ();

                    foreach (var notification in notifications) {
                        var client2 = new Client (socket_uri);
                        client2.delete_notification_by_id (notification.id);
                    }
                    break;
                default:
                    print_usage ();
                    return 1;
            }
        } catch (GLib.Error err) {
            error (err.message);
        }

        return 0;
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

    /**
     * A lazy/minimal command-line arg parser because OptionContext segfaults.
     */

    errordomain ArgParser {
        PARSE_ERROR
    }

    /**
     * Convert ["-v", "-s", "asdf", "-f", "qwe"] => {("-v", null), ("-s", "adsf"), ("-f", "qwe")}
     * Populates key of "cmd" with first arg.
     * NOTE: Currently does not support quoted parameter values.
     */
    HashTable<string, string ? > parse_args (string[] args) throws ArgParser.PARSE_ERROR {
        var arg_hashtable = new HashTable<string, string ? >(str_hash, str_equal);

        if (args == null || args.length == 0) {
            return arg_hashtable;
        }

        string last_key = null;
        foreach (string token in args) {
            if (!arg_hashtable.contains ("cmd")) {
                arg_hashtable.set ("cmd", token);
            } else if (is_key (token)) {
                if (last_key != null) {
                    arg_hashtable.set (last_key, null);
                }
                last_key = token;
            } else if (last_key != null) {
                arg_hashtable.set (last_key, token);
                last_key = null;
            } else {
                // ignore              
            }
        }

        if (last_key != null) { // Trailing single param
            arg_hashtable.set (last_key, null);
        }
        /*
           foreach (var key in arg_hashtable.get_keys ()) {
           stdout.printf ("%s => %s\n", key, arg_hashtable.lookup(key));
           }
         */

        return arg_hashtable;
    }

    bool is_key (string inval) {
        return inval.has_prefix ("-");
    }
}