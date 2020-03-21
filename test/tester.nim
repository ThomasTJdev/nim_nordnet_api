# Copyright 2020 - Thomas T. Jarløv

import unittest, json
import nordnet

const
  name = "Novo"
  url = "16256554-novo-nordisk-b"

var
  stockOut: Nordnet
  nordnetapi: Nordnetapi

suite "test suite nordnet":

  test "get data on Novo stock":
    let nn = nordnetData(name, url)

    check(nn.name == "Novo")
    check(nn.epochtime > 1584771256)
    check(nn.priceLatest > 0)
    check(nn.priceLatest < 999)
    check(nn.success == true)

    stockOut = nn

  test "format stock to Json":
    let json = nordnetJson(stockOut)

    check(json["Novo"].hasKey("priceLatest"))
    check(json["Novo"]["priceLatest"].getFloat() > 1.0)

  test "check config.json":
    let
      config = parseJson(readFile("config/config.json"))
      nn   = config["nordnet"]

    check(nn["urls"].len() > 0)
    check(nn["waitBetweenCalls"].getInt() > 0)
    check(nn["refreshTime"].getInt() > 0)

