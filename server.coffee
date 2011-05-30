pub     = __dirname + '/public'
express = require('express')
lib     = require "./common"
form    = require('connect-form')
fs      = require('fs')

class ServerWorld extends lib.World
    constructor: ->
        super()

        @app = express.createServer(
            form({ keepExtensions: true }),
            express.compiler({ src: pub, enable: ['sass'] }),
            express.static(pub),
            express.logger(),
            express.errorHandler({ dumpExceptions: true, showStack: true }))

        @app.get '/', (req, res) ->
            res.render 'index.jade'

        @app.get '/inject.js', (req, res) ->
            res.sendfile 'inject.js'

        @app.get '/client.js', (req, res) ->
            res.sendfile 'client.js'

        @app.get '/common.js', (req, res) ->
            res.sendfile 'common.js'

        @app.post '/upload', (req, res, next) ->

            req.form.complete (err, fields, files) ->
                console.log 'Uploaded %s to %s', files.image.filename, files.image.path
                if err
                    res.writeHead(500,{})
                    res.write(err.message)
                else
                    fs.renameSync files.image.path, pub + "/upload/" + files.image.filename
                    res.writeHead(200, {})
                    res.write("/upload/" + files.image.filename )
                res.end()
   
            req.form.on 'progress', (bytesReceived, bytesExpected) ->
                percent = (bytesReceived / bytesExpected * 100) | 0
                console.log 'Uploading: %' + percent

        @app.listen(process.env.PORT || 8000)

        @clients = {}

        @socket = require('socket.io').listen @app

        @socket.on 'connection', (client) =>
            sid = client.sessionId
            @clients[ sid ] = client
            @trigger 'connect', sid
            client.on 'message', (message) =>
                json = JSON.parse(message)
                @execute json[0], json[1]
                @trigger 'message', json
            client.on 'disconnect', =>
                @trigger 'disconnect', sid
                delete @clients[sid]

        @observe 'connect', (id)=>
            @clients[id].send(
                JSON.stringify(
                    ['create',ent.serialize()]
                )
            ) for i, ent of @entities
            @send "connect", {id}
            @executor.connect {id}

        @observe 'disconnect', (id)=>
                @send 'disconnect', {id}
                @executor.disconnect {id}

    socket_send: (json)->
        @socket.broadcast json

    execute: (action, data) ->
        if super(action,data) then @send action, data

world = new ServerWorld()
