/**
 * A client library for rofication.
 *
 * Every request uses its own connection to the daemon.
 */
namespace Lago {
    enum ROFICATION_COMMAND {
        COUNT
    }

    public errordomain ClientError {
        /** The daemon's socket could not be reached. */
        UNREACHABLE,
        /** The daemon stopped making progress. */
        TIMED_OUT,
        /** The connection failed after it was made. */
        CONNECTION,
        /** The reply to a list request could not be understood. */
        INVALID_REPLY
    }

    public class NotificationDesc {
        /** The urgency level of any urgency other than Low, Normal or Critical. */
        public const int URGENCY_UNKNOWN = -1;

        /** The id in decimal. Ids are not limited to 64 bits. */
        public string id { get; private set; }
        public string summary { get; private set; }
        public string body { get; private set; }
        public string application { get; private set; }
        /** 0, 1 or 2 for Low, Normal or Critical; otherwise URGENCY_UNKNOWN. */
        public int urgency { get; private set; }
        // TODO add 'actions' (list of string)

        internal NotificationDesc (string id, string summary, string body, string application, int urgency) {
            this.id = id;
            this.summary = summary;
            this.body = body;
            this.application = application;
            this.urgency = urgency;
        }
    }

    public class Client {
        /** Seconds the daemon may go without progress before a request fails. */
        private const uint TIMEOUT_SECONDS = 3;
        /** Microseconds between connection attempts while the daemon's queue is full. */
        private const ulong CONNECT_RETRY_INTERVAL = 20000;
        /** The longest socket path that fits, with its terminating NUL, in sun_path. */
        private const int MAX_SOCKET_PATH = 107;

        private string socket_path;
        private UnixSocketAddress socket_addr;
        private int buffer_size = 1024 * 64;

        public Client (string socket_path) {
            this.socket_path = socket_path;
            this.socket_addr = new UnixSocketAddress (socket_path);
        }

        /**
         * Returns the queued notifications, after reading the whole reply.
         */
        public List<NotificationDesc> get_notifications () throws ClientError {
            var socket = open_socket ();
            var reply = new ByteArray ();

            try {
                send_all (socket, "list\n".data);

                // The reply ends when the daemon closes the connection.
                uint8[] buffer = new uint8[buffer_size];
                while (true) {
                    ssize_t len = receive (socket, buffer);
                    if (len == 0) break;
                    reply.append (buffer[0:len]);
                }
            } finally {
                close_socket (socket);
            }

            return ReplyParser.parse (reply.data);
        }

        /**
         * Dismisses a notification by id, given in decimal.
         */
        public void delete_notification_by_id (string id) throws ClientError {
            send_request ("del:" + id + "\n");
        }

        public void delete_notification_by_app (string app) throws ClientError {
            send_request ("dela:" + app + "\n");
        }

        /**
         * Sends a request that has no reply.
         */
        private void send_request (string message) throws ClientError {
            var socket = open_socket ();

            try {
                send_all (socket, message.data);
            } finally {
                close_socket (socket);
            }
        }

        private Socket open_socket () throws ClientError {
            Socket socket;

            // GLib would silently shorten a path that does not fit in sun_path.
            if (socket_path.length > MAX_SOCKET_PATH) {
                throw new ClientError.UNREACHABLE ("cannot connect to %s: the path is longer than %d bytes", socket_path, MAX_SOCKET_PATH);
            }

            try {
                socket = new Socket (SocketFamily.UNIX, SocketType.STREAM, SocketProtocol.DEFAULT);
            } catch (GLib.Error err) {
                throw new ClientError.UNREACHABLE ("cannot connect to %s: %s", socket_path, err.message);
            }
            socket.set_blocking (true);
            socket.timeout = TIMEOUT_SECONDS;

            int64 deadline = get_monotonic_time () + TIMEOUT_SECONDS * TimeSpan.SECOND;
            while (true) {
                try {
                    socket.connect (socket_addr);
                    return socket;
                } catch (IOError.WOULD_BLOCK err) {
                    // The daemon has not yet accepted the connections queued before this one.
                    int64 now = get_monotonic_time ();
                    if (now >= deadline) {
                        close_socket (socket);
                        throw new ClientError.TIMED_OUT ("cannot connect to %s: the daemon did not accept the connection within %u seconds", socket_path, TIMEOUT_SECONDS);
                    }
                    Thread.usleep ((ulong) int64.min (deadline - now, (int64) CONNECT_RETRY_INTERVAL));
                } catch (GLib.Error err) {
                    close_socket (socket);
                    throw new ClientError.UNREACHABLE ("cannot connect to %s: %s", socket_path, err.message);
                }
            }
        }

        private void send_all (Socket socket, uint8[] data) throws ClientError {
            size_t sent = 0;

            while (sent < data.length) {
                try {
                    sent += socket.send (data[sent:data.length]);
                } catch (IOError.TIMED_OUT err) {
                    throw new ClientError.TIMED_OUT ("the daemon at %s did not take the request within %u seconds", socket_path, TIMEOUT_SECONDS);
                } catch (GLib.Error err) {
                    throw new ClientError.CONNECTION ("cannot send the request to %s: %s", socket_path, err.message);
                }
            }
        }

        private ssize_t receive (Socket socket, uint8[] buffer) throws ClientError {
            try {
                return socket.receive (buffer);
            } catch (IOError.TIMED_OUT err) {
                throw new ClientError.TIMED_OUT ("the daemon at %s stopped replying for %u seconds", socket_path, TIMEOUT_SECONDS);
            } catch (GLib.Error err) {
                throw new ClientError.CONNECTION ("cannot read the reply from %s: %s", socket_path, err.message);
            }
        }

        private void close_socket (Socket socket) {
            try {
                socket.close ();
            } catch (GLib.Error err) {
                // Nothing is left to do with this connection.
            }
        }
    }
}
