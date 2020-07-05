# crystowl-nest

Crystowl-Nest is a telegram bot which implements a shopping list.

## Installation

Install crystal, download the repository and then execute the following commands in the folder:

```bash
shards install
crystal build src/crystowl-nest.cr
```

## Usage

Run the program using:

```bash
./crystowl-nest XXX:XXX CONFIG_NAME
```

Replace ```XXX:XXX``` with the Telegram bot API key and ```CONFIG_NAME``` with the name of your configuration.

Make also sure to create a whitelist with the following content:

```yaml
---
content:
  XXXXXXXXX : true
  YYYYYYYYY : true
```

Save it as ```whitelist_CONFIG_NAME.yml``` in a folder called ```configs```.

Here, ```XXXXXXXXX``` and ```YYYYYYYYY``` are Telegram user IDs of users you want to allow access to the bot.
You can get these IDs by sending a ```/replace``` command to the bot and checking the command line standard output.

Currently, the bot texts are written in German. To translate them, edit them in ```src/crystowl-nest.cr``` to your liking.

## Features:

* [X] Shopping list creator
* [X] Whitelist
* [X] Checklist
* [X] Cache

## Contributing

1. Fork it (<https://github.com/Hadeweka/crystowl-nest/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

- [Hadeweka](https://github.com/Hadeweka) - creator and maintainer
