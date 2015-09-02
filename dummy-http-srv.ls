#!/usr/bin/env lsc
require! <[optimist express http colors moment]>
commons = require \./lib/commons

opt = optimist.usage 'Usage: $0'
  .alias \p, \port
  .describe \p, 'the port for http-dummy server to listen, default: 8000'
  .default \p, 8000
  .alias \h, \help
  .boolean <[h]>

argv = opt.argv
if argv.h
  argv.showHelp!
  process.exit 1

okay_empty = (req, res) -> return res.status 200 .send ""
hello = (req, res) -> return res.status 200 .send "hello world!!\n"


main = ->
  app = express!
  app.use commons.pre
  app.use commons.cache-req-data
  app.use commons.dump-req
  app.use hello
  # app.use okay_empty

  server = http.createServer app
  server.listen argv.p, (err) ->
    return ERR "failed to listen #{argv.p}, err: #{err}" if err?
    return DBG "listening #{argv.p} ..."

# Entry point
#
main!

