#!/usr/bin/env lsc
require! <[optimist express http colors moment http-proxy]>
commons = require \./lib/commons


opt = optimist.usage 'Usage: $0'
  .alias \t, \target
  .describe \t, 'the target server to proxy, e.g. 127.0.0.1:8000'
  .default \t, \127.0.0.1:8000
  .alias \p, \port
  .describe \p, 'the port for proxy server to listen, default: 8001'
  .default \p, 8001
  .alias \h, \help
  .demand <[t]>
  .boolean <[h]>

argv = opt.argv
if argv.h
  opt.showHelp!
  process.exit 1


forward = (req, res) -> return global.proxy.web req, res


main = ->
  proxy = global.proxy = httpProxy.createProxyServer xfwd: true, target: "http://#{argv.t}"
  proxy.on 'error', (err, req, res) ->
    ERR "something went wrong: #{err}"
    res.writeHead 500, {'Content-Type': 'text/plain'}
    res.end "something went wrong: #{err}"

  proxy.on 'proxyRes', (proxyRes, req, res) -> return commons.dump-proxy-res proxyRes, req, res

  app = express!
  app.use commons.pre
  app.use commons.hook-res-stream
  app.use commons.cache-req-data
  app.use commons.dump-req
  app.use forward

  server = http.createServer app
  server.listen argv.p, (err) ->
    return ERR "failed to listen #{argv.p}, err: #{err}" if err?
    return DBG "listening #{argv.p} ..."


# Entry point
#
main!
