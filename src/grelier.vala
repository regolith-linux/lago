/** 
 * A client library for i3-wm that deserializes into idomatic Vala response objects. 
 */
namespace Lago {
  enum ROFICATION_COMMAND {
    COUNT
  }

  public errordomain ROFICATION_ERROR {
    RPC_ERROR
  }

  public class Client {
    private Socket socket;
    private uint8[] terminator = { '\0' };
    private int bytes_to_payload = 14;
    private int buffer_size = 1024 * 128;

    public Client(string i3Socket) throws GLib.Error {
      var socketAddress = new UnixSocketAddress(i3Socket);

      socket = new Socket (SocketFamily.UNIX, SocketType.STREAM, SocketProtocol.DEFAULT);
      assert (socket != null);
    
      socket.connect (socketAddress);
      socket.set_blocking(true);
    }

    ~Client() {
      if (socket != null) {
        socket.close();
      }
    }

    public string get_notification_count() throws ROFICATION_ERROR, GLib.Error {
      ssize_t sent = socket.send("num\n".data);

      debug("Sent " + sent.to_string() + " bytes to i3.\n");

      uint8[] buffer = new uint8[buffer_size];

      ssize_t len = socket.receive (buffer);

      debug("Received  " + len.to_string() + " bytes from i3.\n");

      //Bytes responseBytes = new Bytes.take(buffer[0:len]);

      return (string) buffer;
    }
  }
}
