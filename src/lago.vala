
namespace Lago {
    void main (string[] args) {
        Client client = new Client("/tmp/rofi_notification_daemon");
        var count = client.get_notification_count();

        stdout.printf ("Hello world! %s\n", count);
    }
}