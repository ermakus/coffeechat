if process?
  Global = exports
else
  Global = window.Global = {}
  # for those w/o console...  sad.
  window.console ||= {}
  window.console[fn] ||= (->) for fn in ['log', 'dir', 'error', 'warn']

# Remove function for arrays
Array::remove = (e) -> @[t..t] = [] if (t = @.indexOf(e)) > -1

# Buffered send and receive
class IOQueue
  constructor: ->
    @outbox = []
    @inbox = []
    @connection = new Connection()

  send: (args...) ->
    @outbox.push args

  flush: ->
    return unless @outbox.length and @connection.id?
    @connection.send @outbox
    @outbox = []

  read: ->
    ret = @inbox
    @inbox = []
    ret

  connect: ->
    @connection.observe 'message', (data) =>
      @inbox = @inbox.concat data
    @connection.connect()

# Observer pattern
class Observable
  observe: (name, fn) ->
    @observers(name).push fn

  trigger: (name, args...) ->
    callback args... for callback in @observers(name)

  observers: (name) ->
    (@_observers ||= {})[name] ||= []

class Connection extends Observable
  constructor: ->
    @socket = new io.Socket()
    @setupObservers()

  send: (obj) ->
    @socket.send JSON.stringify(obj)

  observe: (msg, fn) ->
    super msg, fn
    @observeSocket msg

  connect: ->
    @socket.connect()

  setupObservers: ->
    @observingSocket = {}
    @observe "connect", =>
      @id = @socket.transport.sessionid

  observeSocket: (eventName) ->
    return if @observingSocket[eventName]
    @observingSocket[eventName] = true

    @socket.on eventName, (json) =>
      data = JSON.parse(json) if json
      @trigger eventName, data

ENTITY_LAST_ID=1

# Visual element
class Entity
    constructor: (@world) ->
        @id = ENTITY_LAST_ID
        ENTITY_LAST_ID += 1
        @view = world.view.set()


    create: (x,y) ->
        @view.push(
            @world.view.circle( x, y, 50 ).attr({fill: "red"})
        )

    remove: ->
        @view.remove()
        @world.entities.remove( this )

    has: (x,y) ->
        p = @view.getBBox()
        (p.x < x < (p.x + p.width)) and (p.y < y < (p.y + p.height))

    x: ->
        @view.getBBox().x

    y: ->
        @view.getBBox().y

    select: ->
        return if @selection
        p = @view.getBBox()
        @selection = @world.view.rect(p.x,p.y,p.width,p.height)

    deselect: ->
        return unless @selection
        @selection.remove()
        @selection = undefined

    move: (dx,dy) ->
        @view.translate(dx,dy)
        @selection.translate(dx,dy) if @selection

    main: ->
Global.Entity = Entity

class Creature extends Entity
Global.Creature = Creature

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

    select: (x,y) ->
        @selection = @world.find(x,y)
        e.select() for e in @selection
        @selection.length

    deselect: ->
        e.deselect() for e in @selection
        @selection = []

    click: (@x,@y) ->
       @down = true
       @deselect()
       if not @select(x,y) then @world.send "create", {'entity':'Creature','x':x,'y':y }

    release: (@x,@y) ->
       @down = false

    move: (x,y) ->
        if @down then @world.send( "move", { "id":e.id, "dx": x - @x,  "dy": y - @y } ) for e in @selection
        @x = x
        @y = y


class Executor
    constructor: (@world)->

    create: (data)->
        e = new Global[data.entity](@world)
        e.create data.x, data.y
        @world.entities[ e.id ] = e

    move: (data)->
        @world.entities[ data.id ].move( data.dx, data.dy )

# Main class
class World
    constructor: ->
        @view = Raphael('canvas',window.innerWidth,window.innerHeight)
        @entities = {}
        @controller = new Controller(this)
        @executor = new Executor(this)
        @tick = 0
        @io = new IOQueue()
        @io.connection.observe 'connect', =>
            console.log( "Connected" + @io.connection.id )
        @io.connection.observe 'disconnect', =>
            console.log( "Disconnected" + @io.connection.id )

    send: (action, data) ->
        console.log " -> " + action + ":" + JSON.stringify( data )
        @io.send action, data

    network: ->
        ex = @executor
        for [action, data] in @io.read()
            console.log " <- " + action + ":" + JSON.stringify( data )
            ex[ action ]( data )
        @io.flush()

    start: ->
        @io.connect()
        setInterval ( => @loop() ), 100

    loop: ->
        @tick += 1
        @network()
        @main()

    find: (x,y) ->
        hits = []
        for k,e of @entities
            hits.push(e) if e.has(x,y)
        return hits

    main: ->
        for k,e of @entities
            e.main()

$(document).ready ->
    world = new World()
    world.start()

