express = require('express')
pub     = __dirname + '/public'
lib     = require "./common"

class ServerConnection extends lib.Connection

    constructor: (app)->
        super()
        @clients = {}
        @socket = require('socket.io').listen app
        @socket.on 'connection', (client) =>
            @clients[ client.sessionId ] = client
            @trigger 'connect', client.sessionId
            client.on 'message', (message) =>
                json = JSON.parse(message)
                @inbox = @inbox.concat json
                @trigger 'message', json
#                @socket.broadcast message
            client.on 'disconnect', =>
                @trigger 'disconnect', client.sessionId
                delete @clients[client.sessionId]

    send: (json)->
        @socket.broadcast json

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

        @io.observe 'connect', (id)=>
            console.log @entitiesCount
            @io.clients[id].send(
                JSON.stringify(
                    ['create',{'entity':ent.className(),'id':ent.id,'x':ent.x,'y':ent.y } ] for id, ent of @entities
                )
            ) if @entitiesCount

        @io.observe 'disconnect', (id)=>
                @send 'disconnect', {'id':id }

    execute: (action, data) ->
        if super(action,data) then @send action, data

world = new ServerWorld()
world.start()
