# Client socket.io connection
class ClientConnection extends window.Global.Connection
    constructor: ->
        super( new io.Socket() )

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
       if not @select(x,y) then @world.send "create", {'entity':'Creature','x':x,'y':y }

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
