require! <[colors moment]>
{sprintf} = require \sprintf-js
{pd} = require \pretty-data

global.index = 1


verbose = (level, message) ->
  now = moment! .format "MM/DD hh:mm:ss"
  console.log "#{now.blue} [#{level}] #{message}"


DBG = global.DBG = (message) -> return verbose "DBG".gray, message
ERR = global.ERR = (message) -> return verbose "ERR".red, message
EMP = global.EMP = (message) -> return console.log "                     #{message}"
NXT = global.NXT = -> return console.log ""


print-line = (alignments, logger, hex_array, char_array) ->
  t1 = sprintf "%-#{alignments * 3}s", hex_array.join " "
  t2 = char_array.join ""
  logger.emp "#{t1.gray} | #{t2}"


print-lines = (logger, text) ->
  some-lines = text.split "\n"
  for let line, i in some-lines
    logger.emp "#{line.green}"


dump-bytes = (logger, buffer) ->
  hex_array = []
  char_array = []
  count = 0
  alignments = 32
  for b in buffer
    count = count + 1
    t = if b < 16 then "0#{b.toString 16}" else b.toString 16
    c = if b >= 0x20 and b < 0x7F then String.fromCharCode b else " ".bgWhite
    c = "t".bgMagenta.cyan.underline if b == '\t'.charCodeAt!
    c = "n".bgMagenta.cyan.underline if b == '\n'.charCodeAt!
    c = "r".bgMagenta.cyan.underline if b == '\r'.charCodeAt!
    hex_array.push t.toUpperCase!
    char_array.push c
    if count >= alignments
      print-line alignments, logger, hex_array, char_array
      count = 0
      hex_array = []
      char_array = []
  print-line alignments, logger, hex_array, char_array if hex_array.length > 0
  logger.emp ""


dump-headers = (logger, headers) ->
  for let key, value of headers
    logger.emp "#{key}: #{value.magenta}"
  logger.emp ""


dump-json = (logger, type, buffer) ->
  logger.emp "(#{type.yellow})"
  text = "#{buffer}"
  data = JSON.parse text
  print-lines logger, JSON.stringify data, null, ' '


dump-xml = (logger, type, buffer) ->
  logger.emp "(#{type.yellow})"
  print-lines logger, pd.xml "#{buffer}"


dump-text = (logger, type, buffer) ->
  logger.emp "(#{type.yellow})"
  print-lines logger, "#{buffer}"


dump-if-applicable = (logger, content-type, buffer) ->
  return dump-xml logger, content-type, buffer if 0 <= (content-type.indexOf "soap") or 0 <= (content-type.indexOf "xml")
  return dump-json logger, content-type, buffer if 0 <= (content-type.indexOf "json")
  return dump-text logger, content-type, buffer if 0 <= (content-type.indexOf "text/plain")
  return dump-text logger, content-type, buffer if 0 <= (content-type.indexOf "text/")


class Logger
  (@index, @direction) ->
    idx = sprintf "%4s", "#{index}"
    @prefix = "[#{idx.cyan}]"
    return

  dbg: (message) -> return DBG "#{@prefix} #{@direction} #{message}"
  emp: (message) -> return EMP "#{@prefix} #{@direction} #{message}"



module.exports = exports =
  pre: (req, res, next) ->
    {index} = global
    req.metadata = index: index, logger: new Logger index, "->"
    res.metadata = index: index, logger: new Logger index, "<-"
    global.index = global.index + 1
    next!


  cache-req-data: (req, res, next) ->
    data = []
    req.on \data, (chunk) ->
      for let c in chunk
        data.push c
    req.on \end, ->
      b = new Buffer data
      req.data = b
      req.removeAllListeners \data
      req.removeAllListeners \end
      next!
      process.nextTick ->
        req.emit \data, b
        req.emit \end


  hook-res-stream: (req, res, next) ->
    {logger} = res.metadata
    _write = res.write
    _end = res.end
    data = []
    res.write = (chunk) ->
      for let c in chunk
        data.push c
      return _write.apply res, [chunk]
    res.end = ->
      res.dump-at-end new Buffer data if res.dump-at-end?
      return _end.apply res, []
    next!


  dump-req: (req, res, next) ->
    {data, metadata} = req
    {logger} = metadata
    text = "#{data}"
    type = req.headers[\content-type]

    logger.dbg "#{req.method} #{req.url.yellow} HTTP/#{req.httpVersion}"
    logger.emp "(from #{req.socket.remoteAddress.red})"

    dump-headers logger, req.headers
    dump-bytes logger, data
    dump-if-applicable logger, type, data
    NXT!
    next!


  dump-proxy-res: (proxy-res, req, res) ->
    {metadata} = res
    {logger} = metadata
    code = "#{proxy-res.statusCode}"
    type = proxy-res.headers[\content-type]

    logger.dbg "HTTP #{code.yellow}"
    dump-headers logger, proxy-res.headers

    res.dump-at-end = (data) ->
      dump-bytes logger, data
      logger.emp "type = #{type}"
      dump-if-applicable logger, type, data if type?
      NXT!

