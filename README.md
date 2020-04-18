# nim_nordnet_api

Okay, not really an API. Actually not even close to an API. Nordnet wasn't gonna
play with me, so this ended up as an oldschool scraper.

The originale purpose to develop a sensor for [https://www.home-assistant.io/](https://www.home-assistant.io/)


## What is Nordnet
Nordnet is an online stockbroker with customers in Denmark, Norway, Sweden, and Finland. It serves stock from around the world. Checkout their website www.nordnet.dk and start trading with a low fee and an excellent UI.

## What is this?
Well, this is a simple scraper. You provide the URL to the stock, and this little Nim program provide you with the latest data on the stock.

You can use this library in 3 ways:
1. Normal library, either by cloning the repo or installing with Nimble
2. CLI tool which outputs the data to the console
3. Home Assistant "plugin" to serve data to your dashboard with automatic adding of sensors

## What not to do
You should absolutely not set the scraping interval too low (!!). This is **not** an API provided by Nordnet, so please use it with care for Nordnets servers.

## What's next?
Nothing. Nordnet properly changes their div-structure on monday, and then the scraping is failing.

_Currently been working for a month..._

# How to use it

For all the 3 methods, you have to provide the URL to stock page. Navigate to the site, e.g. for Novo:
```url
https://www.nordnet.dk/markedet/aktiekurser/16256554-novo-nordisk-b
```

Now grab the last part of the url, which is what you need:
```url
16256554-novo-nordisk-b
```

You can provide multiple URLs, so repeat the above until satisfied.


# Normal library

```nim
import nordnet
let nnObject = nordnetData("Novo", "16256554-novo-nordisk-b")
echo nnObject.priceLatest # The price
echo nordnetJson(nnObject) # JsonNode
```


# CLI tool
Just find the url path and run:
```bash
$ nim c -d:ssl -d:release nordnet.nim
$ ./nordnet 16256554-novo-nordisk-b
```

# Home Assistant
The following is for implementing the data in [https://www.home-assistant.io/](https://www.home-assistant.io/).

## Compile
First compile the file:
```nim
nim c -d:ssl -d:release nordnet.nim
```

## Config file
Then edit the config file, `config.json`, to your needs.

If you need to place your config file elsewhere, just edit the `"config"` path. Otherwise leave blank.
```nim
nano config/config.json
```

## Auto run
Now adjust the service file and deploy for autorun:
```nim
nano nordnet.service
sudo cp nordnet.service /etc/systemd/system/nordnet.service
sudo systemctl enable nordnet
sudo systemctl start nordnet
sudo systemctl status nordnet
```

## Add as sensor to Home Assistant

As default the stocks will automatic be added as sensors named `sensor.stock_{stockname}`. So just run it, and you can directly after add the sensors to your lovelace frontpage.

If you **dont** want the sensors added automatic, then set the `autodiscover: false` in the `config.json` - but then you have to add them manually, see the example with Node red below.

### Node red

We are making 3 nodes:

* MQTT-in node - convert to JSON object
* Switch node - prepared for more stocks
* HA entity node - make the sensor

<details><summary>Node red JSON code</summary>
[
    {
        "id": "99ad52.619902b",
        "type": "mqtt in",
        "z": "f9f7e30c.acb0a",
        "name": "",
        "topic": "nordnet/#",
        "qos": "2",
        "datatype": "json",
        "broker": "6e85e811.77a988",
        "x": 160,
        "y": 460,
        "wires": [
            [
                "a55a5b7e.c1b6f8"
            ]
        ]
    },
    {
        "id": "a55a5b7e.c1b6f8",
        "type": "switch",
        "z": "f9f7e30c.acb0a",
        "name": "Determine stock",
        "property": "topic",
        "propertyType": "msg",
        "rules": [
            {
                "t": "eq",
                "v": "nordnet/Novo",
                "vt": "str"
            },
            {
                "t": "eq",
                "v": "nordnet/Alibaba",
                "vt": "str"
            }
        ],
        "checkall": "false",
        "repair": false,
        "outputs": 2,
        "x": 360,
        "y": 460,
        "wires": [
            [
                "7ec6bbab.c507a4"
            ],
            [
                "447985cf.024a3c"
            ]
        ]
    },
    {
        "id": "7ec6bbab.c507a4",
        "type": "ha-entity",
        "z": "f9f7e30c.acb0a",
        "name": "Stock Novo",
        "server": "b95e3a52.453dc8",
        "version": 1,
        "debugenabled": true,
        "outputs": 1,
        "entityType": "sensor",
        "config": [
            {
                "property": "name",
                "value": "nordnet_novo"
            },
            {
                "property": "device_class",
                "value": ""
            },
            {
                "property": "icon",
                "value": ""
            },
            {
                "property": "unit_of_measurement",
                "value": "DKK"
            }
        ],
        "state": "payload.Novo.priceLatest",
        "stateType": "msg",
        "attributes": [
            {
                "property": "percentToday",
                "value": "payload.Novo.percentToday",
                "valueType": "msg"
            },
            {
                "property": "plusminusToday",
                "value": "payload.Novo.plusminusToday",
                "valueType": "msg"
            },
            {
                "property": "priceBuy",
                "value": "payload.Novo.priceBuy",
                "valueType": "msg"
            },
            {
                "property": "priceSell",
                "value": "payload.Novo.priceSell",
                "valueType": "msg"
            },
            {
                "property": "priceHighest",
                "value": "payload.Novo.priceHighest",
                "valueType": "msg"
            },
            {
                "property": "priceLowest",
                "value": "payload.Novo.priceLowest",
                "valueType": "msg"
            },
            {
                "property": "tradeTotal",
                "value": "payload.Novo.tradeTotal",
                "valueType": "msg"
            },
            {
                "property": "orderdepthBuy",
                "value": "payload.Novo.orderdepthBuy",
                "valueType": "msg"
            },
            {
                "property": "orderdepthSell",
                "value": "payload.Novo.orderdepthSell",
                "valueType": "msg"
            },
            {
                "property": "epochtime",
                "value": "payload.Novo.epochtime",
                "valueType": "msg"
            },
            {
                "property": "success",
                "value": "payload.Novo.success",
                "valueType": "msg"
            }
        ],
        "resend": true,
        "outputLocation": "",
        "outputLocationType": "none",
        "inputOverride": "allow",
        "x": 590,
        "y": 420,
        "wires": [
            []
        ]
    },
    {
        "id": "6a83e811.77a988",
        "type": "mqtt-broker",
        "z": "",
        "name": "Main MQTT",
        "broker": "127.0.0.1",
        "port": "1883",
        "clientid": "noderedmqtt",
        "usetls": false,
        "compatmode": false,
        "keepalive": "60",
        "cleansession": true,
        "birthTopic": "",
        "birthQos": "0",
        "birthPayload": "",
        "closeTopic": "",
        "closeQos": "0",
        "closePayload": "",
        "willTopic": "",
        "willQos": "0",
        "willPayload": ""
    },
    {
        "id": "b93f3a12.453dc8",
        "type": "server",
        "z": "",
        "name": "Home Assistant",
        "legacy": false,
        "addon": true,
        "rejectUnauthorizedCerts": true,
        "ha_boolean": "y|yes|true|on|home|open",
        "connectionDelay": true,
        "cacheJson": true
    }
]
</details>

### Graph
Now just create a sensor-graph with the sensor `sensor.nordnet_novo`, or use the
[mini-graph](https://github.com/kalkih/mini-graph-card) with the following code:
```yaml
type: 'custom:mini-graph-card'
name: 'Stock: Novo'
icon: 'mdi:chart-bell-curve'
entities:
  - entity: sensor.nordnet_novo
    name: Latest price
hours_to_show: 168
points_per_hour: 30

```


# Types

## MqttInfo* = object


```nim
  MqttInfo* = object
    host*: string
    port*: int
    username*: string
    password*: string
    topic*: string
    ssl*: bool
    clientname*: string
```

____



## Nordnetapi* = object


```nim
  Nordnetapi* = object
    urls*: seq[string]
    wait*: int
    refresh*: int
```

____



## Nordnet* = object


```nim
  Nordnet* = object
    success*: bool
    name*: string
    epochtime*: int
    priceLatest*: float
    priceBuy*: float
    priceSell*: float
    priceHighest*: float
    priceLowest*: float
    percentToday*: float
    plusminusToday*: float
    tradeTotal*: int
    orderdepthSell*: int
    orderdepthBuy*: int
```

____



# Procs

## nordnetConfig*

```nim
proc nordnetConfig*(configPath = "config/config.json") =
```

Load the config


____

## nordnetData*

```nim
proc nordnetData*(name, url: string): Nordnet =
```

Scrape the data and return the Nordnet object

```nim
(success: true, name: "Novo", epochtime: 1584771256, priceLatest: 359.35, priceBuy: 359.35, priceSell: 359.35, priceHighest: 381.5, priceLowest: 355.75, percentToday: -1.55, plusminusToday: -5.65, tradeTotal: 6914045, orderdepthSell: 0, orderdepthBuy: 0)
```


____

## nordnetJson*

```nim
proc nordnetJson*(nn: Nordnet): JsonNode =
```

Transform the Nordnet object to a JsonNode

```json
{
    "Novo": {
        "priceLatest": 359.35,
        "percentToday": -1.55,
        "plusminusToday": -5.65,
        "priceBuy": 359.35,
        "priceSell": 359.35,
        "priceHighest": 381.5,
        "priceLowest": 355.75,
        "tradeTotal": 6914045,
        "orderdepthBuy": 0,
        "orderdepthSell": 0,
        "epochtime": 1584771256,
        "success": true
    }
}
```


____

## apiRun*

```nim
proc apiRun*() {.async.} =
```

Run the async scraping. This will first load the config into
memory, then connect to the mqtt broker, and then do the
first scraping. After the first scraping the loading time
will start.


____

