## Lago 

A command line interface to the [Rofication desktop notification system](https://github.com/DaveDavenport/Rofication).  Lago can be used to view and delete desktop notifications.

## Usage

```bash
src/lago -h

        Usage:
        lago [ ls | rm <id> | rm <app> | clear ]
        
        Help Options:
        -h, --help                           Show help options
        
        Application Options:
        -v, --version                        Display version number
        -s <Socket URI>                      Socket path to connect to notification server
```

### List Notifications

```bash
lago ls
```

Each notification is printed as `[<id>] <application> (<urgency>) - <summary>`, followed by its body, one tab-indented line per body line.

### Delete Notification by ID

```bash
lago rm 4
```

An operand made only of digits that fits a signed 64-bit integer is a notification ID. Anything else is an application name.

### Delete Notification by Source

```bash
lago rm Slack
```

### Delete all Notifications

```bash
lago clear
```

### Use Another Socket

```bash
lago -s /path/to/socket ls
```

Options can come before or after the command. Arguments after `--` are never read as options.

If the daemon can't be reached, stops answering for 3 seconds, or sends a reply lago can't read, lago prints one `lago: ` line on stderr and exits with status 1.

## Compatibility

Lago should be compatible with both the original [Rofication project](https://github.com/DaveDavenport/Rofication) as well as the [Regolith version](https://github.com/regolith-linux/regolith-rofication).

## Build

```bash
git clone https://github.com/regolith-linux/lago
cd lago && mkdir build && cd build
meson ..
ninja
sudo ninja install
sudo ldconfig
```

## Status

Lago can be considered alpha quality.  Fixes in PR welcome.  Feature additions, ask first please.

