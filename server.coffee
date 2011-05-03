express = require('express')
coffee = require 'coffee-script'
fs = require 'fs'
pub = __dirname + '/public'
app = express.createServer(
  express.compiler({ src: pub, enable: ['sass'] }),
  express.static(pub),
  express.logger(),
  express.errorHandler({ dumpExceptions: true, showStack: true }))

app.get '/', (req, res) ->
  res.render 'index.jade'

app.get '/client.js', (req, res) ->
  res.sendfile 'client.js'

app.listen(process.env.PORT || 8000)

socket = require('socket.io').listen app
socket.on 'connection', (client) ->
  client.on 'message', (message) ->
    socket.broadcast message
  client.on 'disconnect', ->
    client.broadcast JSON.stringify([['disconnect', client.sessionId]])
