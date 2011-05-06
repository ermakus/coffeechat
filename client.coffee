# Client socket.io connection
class ClientConnection extends window.Global.Connection
    constructor: ->
        super()
        @socket = new io.Socket()
        @observe "connect", =>
            @id = @socket.transport.sessionid
            console.log( "Connected: " + @id )
        @observe 'disconnect', =>
            console.log( "Disconnected: " + @id )
        @observe 'message', (data) =>
            @inbox = @inbox.concat data
        @socket.connect()

    observe: (msg, fn) ->
        super msg, fn
        @observingSocket ||= {}
        return if @observingSocket[msg]
        @observingSocket[msg] = true
        @socket.on msg, (json) =>
            data = JSON.parse(json) if json
            @trigger msg, data

    send: (json) ->
        @socket.send json


# Class to receive events from mouse/kbd and issue commands
class Controller
    constructor: (@world) ->
        canvas = $('#canvas')
        canvas.bind "mousedown", (e) =>
            @click e.pageX, e.pageY
        canvas.bind "mouseup", (e) =>
            @release e.pageX, e.pageY
        canvas.bind "mousemove", (e) =>
            @move e.pageX, e.pageY
        canvas.bind "keydown", (e) =>
            alert "Down"

        @selection = []

    # Select object by coordinate
    select: (x,y) ->
        @selection = @world.find(x,y)
        e.select() for e in @selection
        @selection.length

    # Deselect all objects
    deselect: ->
        e.deselect() for e in @selection
        @selection = []

    # Mouse click handler
    click: (@x,@y) ->
       @down = true
       @deselect()
       if not @select(x,y) then @world.send "create", {'entity':'Entity','x':x,'y':y }

    # Mouse release handler
    release: (@x,@y) ->
       @down = false

    # Mouse move handler
    move: (x,y) ->
        if @down then @world.send( "move", { "id":e.id, "dx": x - @x,  "dy": y - @y } ) for e in @selection
        @x = x
        @y = y
Global.Controller = Controller


# Entry point
$(document).ready ->
    world = new window.Global.World( new Raphael('canvas',window.innerWidth,window.innerHeight), new ClientConnection()  )
    ctrl = new Controller( world )
    world.start()
