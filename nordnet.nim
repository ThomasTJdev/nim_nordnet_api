# Copyright 2020 - Thomas T. Jarløv

import httpClient, json, strutils, nmqtt, asyncdispatch, times, os
import q, xmltree, re

type
  MqttInfo* = object
    host*: string
    port*: int
    username*: string
    password*: string
    topic*: string
    ssl*: bool
    clientname*: string

  Hass* = object
    autoDiscover*: bool
    birthTopic*: string
    birthPayload*: string

  Nordnetapi* = object
    urls*: seq[string]
    wait*: int
    refresh*: int

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

var
  mqttInfo*: MqttInfo
  nordnetapi*: Nordnetapi
  hass*: Hass

const
  baseUrlDK = "https://www.nordnet.dk/markedet/aktiekurser/"
  #baseUrlSE = "https://www.nordnet.se/marknaden/aktiekurser/"
  #baseUrlNO = "https://www.nordnet.no/market/stocks/"
  #baseUrlFI = "https://www.nordnet.fi/markkinakatsaus/osakekurssit/"
  baseUrl   = baseUrlDK

  discoveryTopic  = "home/sensor/nordnet/stock_"
  discovery       = """{"name": "$2", "icon": "mdi:chart-line", "unique_id": "stock_$1", "state_topic": "home/sensor/nordnet/stock_$1",  "value_template": "{{ value_json['$2']['priceLatest']}}"}"""


proc nordnetConfig*(configPath = "config/config.json") =
  ## Load the config

  var config = parseJson(readFile(configPath))
  if config["config"].getStr() != "":
    config = parseJson(readFile(config["config"].getStr()))
  if config.len() == 0:
    echo "Err missing config.json"
    quit()

  let
    mqtt = config["MQTT"]
    nn   = config["nordnet"]
    ha   = config["HASS"]

  mqttInfo.host         = mqtt["host"].getStr()
  mqttInfo.port         = mqtt["port"].getInt()
  mqttInfo.username     = mqtt["username"].getStr()
  mqttInfo.password     = mqtt["password"].getStr()
  mqttInfo.topic        = mqtt["topic"].getStr()
  mqttInfo.ssl          = mqtt["ssl"].getBool()
  mqttInfo.clientname   = mqtt["clientname"].getStr()

  hass.autoDiscover     = ha["autodiscover"].getBool()
  hass.birthTopic       = ha["birthTopic"].getStr()
  hass.birthPayload     = ha["birthPayload"].getStr()

  for url in nn["urls"]:
    nordnetapi.urls.add(url.getStr())

  nordnetapi.wait     = nn["waitBetweenCalls"].getInt()
  nordnetapi.refresh  = nn["refreshTime"].getInt()
  if nordnetapi.refresh < 15:
    nordnetapi.refresh = 15


proc parseNnFloat(d: string): float =
  ## Parse the value to float
  if "%" in d:
    return parseFloat(d.multiReplace([(",", "."), ("%", "")]))
  elif "," in d:
    return parseFloat(d.replace(",", "."))


proc clearHtml(d: XmlNode): string =
  ## Remove any trace of HTML
  return ($d).multiReplace([(re"<[^>]*>", "")])


proc nordnetData*(name, url: string): Nordnet =
  ## Scrape the data and return the Nordnet object
  ##
  ## (success: true, name: "Novo", epochtime: 1584771256, priceLatest: 359.35, priceBuy: 359.35, priceSell: 359.35, priceHighest: 381.5, priceLowest: 355.75, percentToday: -1.55, plusminusToday: -5.65, tradeTotal: 6914045, orderdepthSell: 0, orderdepthBuy: 0)


  var
    client = newHttpClient()
    nn: Nordnet
    loopValue: string
    #loopValue2: string
    loopMain: bool = true

  let
    htmlRaw   = client.getContent(baseUrl & url)
    qHtmlRaw  = q(htmlRaw)
    qHtml     = qHtmlRaw.select("main>div span")

  nn.name = name
  nn.epochtime = toInt(epochTime())

  for i in qHtml:
    let value = clearHtml(i).strip()

    if value == "":
      continue

    # Loop through main data
    if loopMain:
      if loopValue == "Senest":
        nn.priceLatest = parseNnFloat(value)

      elif loopValue == "I dag %":
        nn.percentToday = parseNnFloat(value)

      elif loopValue == "I dag +/-":
        nn.plusminusToday = parseNnFloat(value)

      elif loopValue == "Køb":
        nn.priceBuy = parseNnFloat(value)

      elif loopValue == "Sælg":
        nn.priceSell = parseNnFloat(value)

      elif loopValue == "Højest":
        nn.priceHighest = parseNnFloat(value)

      elif loopValue == "Lavest":
        nn.priceLowest = parseNnFloat(value)

      elif loopValue == "Omsætning (Antal)":
        nn.tradeTotal = parseInt(value.replace(".", ""))
        nn.success = true
        loopMain = false

    #[else:
      if loopValue == "Køb" and loopValue2 == "Antal":
        nn.orderdepthBuy = parseInt(value)
        echo value
      elif loopValue == "Antal" and loopValue2 == "Sælg":
        nn.orderdepthSell = parseInt(value)
        echo value

      if value in ["Antal", "Sælg"]:
        loopValue2 = value
    ]#

    loopValue = value

  if not nn.success:
    echo "Err getting values"

  when defined(dev):
    echo nn

  return nn


proc nordnetJson*(nn: Nordnet): JsonNode =
  ## Transform the Nordnet object to a JsonNode

  var json = %*
    { nn.name:
      {
        "priceLatest": nn.priceLatest,
        "percentToday": nn.percentToday,
        "plusminusToday": nn.plusminusToday,
        "priceBuy": nn.priceBuy,
        "priceSell": nn.priceSell,
        "priceHighest": nn.priceHighest,
        "priceLowest": nn.priceLowest,
        "tradeTotal": nn.tradeTotal,
        "orderdepthBuy": nn.orderdepthBuy,
        "orderdepthSell": nn.orderdepthSell,
        "epochtime": nn.epochtime,
        "success": nn.success
      }
    }

  return json


proc apiDiscover(ctx: MqttCtx, url: string) {.async.} =
  let
    name    = split(url, "-")[1].capitalizeAscii()
    nameRaw = split(url, "-")[1]

  await ctx.publish(discoveryTopic & nameRaw & "/config", discovery.format(nameRaw, name), 0, true)


proc apiGetData(ctx: MqttCtx, url: string, autoDiscover: bool) {.async.} =
  let
    name    = split(url, "-")[1].capitalizeAscii()
    nameRaw = split(url, "-")[1]

  let nn = nordnetData(name, url)

  let json = nordnetJson(nn)

  if autoDiscover:
    await ctx.publish(discoveryTopic & nameRaw, $json, 0, false)
  else:
    await ctx.publish(mqttInfo.topic & "/" & name, $json, 0, false)


proc apiRun*() {.async.} =
  ## Run the async scraping. This will first load the config into
  ## memory, then connect to the mqtt broker, and then do the
  ## first scraping. After the first scraping the loading time
  ## will start.

  nordnetConfig()

  let ctx = newMqttCtx(mqttInfo.clientname)
  ctx.set_auth(mqttInfo.username, mqttInfo.password)
  ctx.set_host(mqttInfo.host, mqttInfo.port, mqttInfo.ssl)
  ctx.set_ping_interval(60)
  await ctx.start()
  await sleepAsync(3000)

  proc rediscoverOnHassRestart(topic, message: string) =
    ## This will resend the config for the devices, when it receives
    ## Hassio birth message. This message needs to be setup through
    ## Hassio automation.
    if message == hass.birthPayload:
      for url in nordnetapi.urls:
        let
          name    = split(url, "-")[1].capitalizeAscii()
          nameRaw = split(url, "-")[1]
        waitFor ctx.publish(discoveryTopic & nameRaw & "/config", discovery.format(nameRaw, name), 0, true)

  if hass.autoDiscover:
    await ctx.subscribe(hass.birthTopic, 0, rediscoverOnHassRestart)

  for url in nordnetapi.urls:
    await apiDiscover(ctx, url)
    await apiGetData(ctx, url, hass.autoDiscover)
    await sleepAsync(nordnetapi.wait * 1000)

  while true:
    await sleepAsync(nordnetapi.refresh * 1000)
    for url in nordnetapi.urls:
      await apiGetData(ctx, url, hass.autoDiscover)
      await sleepAsync(nordnetapi.wait * 1000)

  await ctx.disconnect()


when isMainModule:
  if paramCount() > 0:
    for i in countUp(1, paramCount()):
      let nn = nordnetData(paramStr(i).strip(), paramStr(i).strip())
      let json = nordnetJson(nn)
      echo pretty(json)
  else:
    waitFor apiRun()