pub     = __dirname + '/public'
express = require('express')
lib     = require "./common"
connect = require('connect')
form    = require('connect-form')
fs      = require('fs')

BAD_BROWSER = /(MSIE 6)|(MSIE 5)|(MSIE 4)/g

USER_ID=0

class Server extends lib.Model
    constructor: ->
        # Server model has null view
        super( null )

        @sessionStore = new express.session.MemoryStore()

        # Create express HTTP server
        @app = express.createServer(
            form({ keepExtensions: true }),
            express.compiler({ src: pub, enable: ['sass'] }),
            express.static(pub),
            express.logger(),
            express.cookieParser(),
            express.session({ secret: 'HIf89dsghK', store: @sessionStore }),
            express.errorHandler({ dumpExceptions: true, showStack: true }))

        # Home page
        @app.get '/', (req, res) ->
            bookmarklet = "javascript:(function(){document.body.appendChild(document.createElement('script')).src='#{lib.BASE_URL}/js/inject.js';})();"
            res.render 'index.jade', { 'title': 'Inject chat to any site', 'scripts': [], bookmarklet }

        # Main GUI
        @app.get '/main', (req, res) ->
            # Check for old browsers
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
                    'url': url,
                    'sid': req.sessionID
                }

        # Upload file handler
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

        # Create socket.io
        @socket = require('socket.io').listen @app

        # socket.io connection handlers
        @socket.on 'connection', (client) =>
            # Message handler
            client.on 'message', (message) =>
                message = JSON.parse(message)
                # Handle 'connect' event separately
                if message.action == 'connect'
                    # Get HTTP session
                    @sessionStore.get message.sid, (error, session) =>
                        # Execute connect handler
                        @onConnect client.sessionId, client, message.sid, session
                else
                    # Handle other messages
                    @trigger 'message', message
            # Disconnect handler
            client.on 'disconnect', =>
                @trigger 'disconnect', client.sessionId

        @observe 'disconnect', (id)=>
                # Handle at server
                @controller.disconnect {id}
                # Broadcast disconnect event
                @send {'action':'disconnect',id}

        # Handle incoming event
        @observe 'message', (data)=>
            if @execute( data ) then @send data


        # Start server
        @app.listen(process.env.PORT || 8000)

    # 'connect' event handler
    onConnect: (id,socket,sid,session) ->
        # Handle connect at server model
        @controller.connect {id}
        avatar = @get( id )
        avatar.socket = socket
        avatar.session = session
        session.save = (cb) =>
            @sessionStore.set(sid,session,cb)

        session.nick ||= ("Anon" + (USER_ID+=1))
        avatar.name = session.nick
        session.save()

        # Send model to connected avatar
        for etype in ["Channel","Avatar","Message"]
            for i, ent of @indexes[ etype ]
                @send ent.serialize {'action':'create','avatar':id}
        # Broadcast connect event
        @send {"action":"connect",id,'name':session.nick}

    # Send event
    send: (data)->
        console.log " -> " + JSON.stringify data
        # Send to avatar
        if data.avatar?
            @get( data.avatar ).socket.send JSON.stringify(data)
            return
        # Send to channel
        if data.channel?
            for avatar in @get( data.channel ).links()
                avatar.socket.send JSON.stringify(data)
            return
         # Send to all
        @socket.broadcast JSON.stringify(data)

# Create server and run
model = new Server()
