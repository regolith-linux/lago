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

### Delete Notification by ID

```bash
lago rm 4
```

### Delete Notification by Source

```bash
lago rm Slack
```

### Delete all Notifications

```bash
lago clear
```

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

