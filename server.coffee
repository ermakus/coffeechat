express = require('express')
pub     = __dirname + '/public'
lib     = require "./common"

class ServerConnection extends lib.Connection
    constructor: (app)->
       super( require('socket.io').listen app )

    connect: ->
        @socket.on 'connection', (client) =>
            @trigger 'connect', client.sessionId
            client.on 'message', (message) =>
                @trigger 'message', JSON.parse(message)
                @socket.broadcast message
            client.on 'disconnect', ->
                client.broadcast JSON.stringify([['disconnect', client.sessionId]])


class ServerWorld extends lib.World
    constructor: ->
        @app = express.createServer(
            express.compiler({ src: pub, enable: ['sass'] }),
            express.static(pub),
            express.logger(),
            express.errorHandler({ dumpExceptions: true, showStack: true }))

        @app.get '/', (req, res) ->
            res.render 'index.jade'

        @app.get '/client.js', (req, res) ->
            res.sendfile 'client.js'

        @app.get '/common.js', (req, res) ->
            res.sendfile 'common.js'

        @app.listen(process.env.PORT || 8000)
        super( null, new ServerConnection( @app ) )


world = new ServerWorld()
world.start()
