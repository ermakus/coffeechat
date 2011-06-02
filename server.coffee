pub     = __dirname + '/public'
express = require('express')
lib     = require "./common"
form    = require('connect-form')
fs      = require('fs')
            
BAD_BROWSER = /(MSIE 6)|(MSIE 5)|(MSIE 4)/g

class Server extends lib.Model
    constructor: ->
        super( null )

        @app = express.createServer(
            form({ keepExtensions: true }),
            express.compiler({ src: pub, enable: ['sass'] }),
            express.static(pub),
            express.logger(),
            express.errorHandler({ dumpExceptions: true, showStack: true }))

        @app.get '/', (req, res) ->
            bookmarklet = "javascript:(function(){document.body.appendChild(document.createElement('script')).src='#{lib.BASE_URL}/js/inject.js';})();"
            res.render 'index.jade', { 'title': 'Inject chat to any site', 'scripts': [], bookmarklet }

        @app.get '/main', (req, res) ->
            browser = req.header('User-Agent')
            url = req.param('url','default')
            if not browser or browser.match( BAD_BROWSER )
                res.render 'badagent.jade', { 'title': 'Your browser too old', 'scripts': [] }
            else
                res.render 'main.jade', {
                    'title': 'Chat room',
                    'scripts': [
                        "/socket.io/socket.io.js",
                        "/js/jquery-1.5.1.min.js",
                        "/js/jquery-ui-1.8.13.custom.min.js",
                        '/js/jquery.layout.js',
                        '/js/ui.tabs.closable.min.js',
                        '/js/json2.js',
                        '/js/common.js',
                        "/js/client.js"
                    ],
                    'url': url
                }

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
            for etype in ["Avatar","Message"]
                @send( 'create', ent.serialize(), id ) for i, ent of @indexes[ etype ]
            @send "connect", {id}
            @executor.connect {id}

        @observe 'disconnect', (id)=>
                @send 'disconnect', {id}
                @executor.disconnect {id}

    send: (action, data, client)->
        if client
            @clients[ client ].send JSON.stringify([action,data])
        else
            @socket.broadcast JSON.stringify([action,data])

    execute: (action, data) ->
        if super(action,data) then @send action, data

model = new Server()
