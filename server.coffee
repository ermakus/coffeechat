pub     = __dirname + '/public'
express = require('express')
lib     = require "./common"
connect = require('connect')
form    = require('connect-form')
fs      = require('fs')

BAD_BROWSER = /(MSIE 6)|(MSIE 5)|(MSIE 4)/g

class ServerModel extends lib.Model
    constructor: (@site)->
        # Server model has null view
        super( null )
        @connections = {}
        # Create socket.io
        @socket = require('socket.io').listen @site.app

        # socket.io connection handlers
        @socket.on 'connection', (client) =>
            # Message handler
            client.on 'message', (message) =>
                message = JSON.parse(message)
                # Handle 'connect' event separately
                if message.action == 'connect'
                    # Get HTTP session
                    @site.sessionStore.get message.sid, (error, session) =>
                        # Create 'save' helper for session instance
                        session.save = (cb) => @site.sessionStore.set(message.sid,session,cb)
                        # Execute connect handler
                        @connections[ client.sessionId ] = @connectAvatar client, session
                else
                    # Handle other messages
                    if @execute( message ) then @send message
            # Disconnect handler
            client.on 'disconnect', =>
                avatar = @connections[ client.sessionId ]
                delete @connections[ client.sessionId ]
                avatar.sockets.remove client
                # Remove avatar if all sockets disconnected
                if avatar.sockets.length == 0
                    # Handle at server
                    @controller.disconnect {'id':avatar.id}
                    # Broadcast disconnect event
                    @send {'action':'disconnect','id':avatar.id}


    # 'connect' event handler
    connectAvatar: (socket,session) ->
        # Avatar ID = user login
        id = session.user.login

        # Create/find avatar
        avatar = @controller.connect {'id':id}
        avatar.name = id

        # Add socket to avatar collection
        avatar.sockets ||= []
        avatar.sockets.push socket

        # Link to HTTP session
        avatar.session = session

        # Send channels avatar connected to
        for i, ent of @indexes[ "Channel" ]
            @send ent.serialize {'action':'create','avatar':id } if ent.hasLink( avatar )

        # Send all avatars
        for i, ent of @indexes[ "Avatar" ]
            @send ent.serialize {'action':'create','avatar':id }

        # Send messages to connected channels
        for i, ent of @indexes[ "Message" ]
            @send ent.serialize {'action':'create','avatar':id } if ent.channel.hasLink( avatar )

        # Broadcast connect event for first connected avatar
        if avatar.sockets.length == 1
            @send avatar.serialize {"action":"connect"}

        return avatar

    # Send event
    send: (data)->
        json = JSON.stringify data
        console.log " -> " + json
        # Send to avatar
        if data.avatar?
            avatar = @get( data.avatar )
            if avatar then socket.send json for socket in avatar.sockets
            return
        # Send to channel
        if data.channel?
            for avatar in @get( data.channel ).links()
                if avatar then socket.send json for socket in avatar.sockets
            return
         # Send to all
        @socket.broadcast json

class Site
    constructor: ->

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

        # Filter all requests
        @app.get '*', (req, res, next)->
            # Check for old browser
            browser = req.header('User-Agent')
            if not browser or browser.match( BAD_BROWSER )
                res.render 'badagent.jade', { 'title': 'Your browser too old', 'scripts': [] }
                return
            # Exclude login page
            if req.url in ['/','/login'] then return next()
            # Ensure user logged in
            if !req.session['user']
                res.redirect '/login'
            else
                return next()
 
        # Home page
        @app.get '/', (req, res) ->
            bookmarklet = "javascript:(function(){document.body.appendChild(document.createElement('script')).src='#{lib.BASE_URL}/js/inject.js';})();"
            res.render 'index.jade', { 'title': 'Inject chat to any site', 'scripts': [], bookmarklet }

        # Main GUI
        @app.get '/main', (req, res) ->
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
                'url': req.param('url','default'),
                'sid': req.sessionID,
                'uid': req.session.user.login
            }

        # Login form
        @app.get '/login', (req, res) ->
                res.render 'login.jade', { 'title': 'Please login', 'scripts': [] }

        # Login handler
        @app.post '/login', (req, res) ->
            req.form.complete (err,fields,files) ->
                req.session.user = {'login':fields.login}
                res.redirect '/main'

        # Logout handler
        @app.get '/logout', (req, res) ->
            req.session.user = undefined
            res.redirect '/login'

        # Upload handler
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


    ensureLogin: (req,res)->

    listen: ->
        # Start server
        @app.listen(process.env.PORT || 8000)


# Create site
site = new Site()
# Create server and run
model = new ServerModel( site )
# Start request processing
site.listen()
