if process?
  Global = exports
else
  Global = window.Global = {}
  window.console ||= {}
  window.console[fn] ||= (->) for fn in ['log', 'dir', 'error', 'warn']

# Remove function for arrays
Array::remove = (e) -> @[t..t] = [] if (t = @.indexOf(e)) > -1

# Observer pattern
class Observable
  observe: (name, fn) ->
    @observers(name).push fn

  trigger: (name, args...) ->
    callback args... for callback in @observers(name)

  observers: (name) ->
    (@_observers ||= {})[name] ||= []
Global.Observable = Observable


# Base client buffered connection class
class Connection extends Observable

  constructor: (@socket)->
    @outbox = []
    @inbox = []

  send: (json) ->
      alert "Abstract method: Connection.send"

  write: (args...) ->
    @outbox.push args

  flush: ->
    return unless @outbox.length
    @send JSON.stringify(@outbox)
    @outbox = []

  read: ->
    ret = @inbox
    @inbox = []
    ret
Global.Connection = Connection

ENTITY_LAST_ID=0

# World object
class Entity
    constructor: (@world, id) ->
        if not id then ENTITY_LAST_ID += 1
        @id = id or ENTITY_LAST_ID
        @view = world.view?.set()

    create: (@x,@y) ->
        @width = @height = 100
        @view?.push(
            @world.view.circle( x+50, y+50, 50 ).attr({fill: "red"})
        )

    remove: ->
        @view?.remove()
        delete @world.entities[ @id ]
        @world.entitiesCount -= 1

    className: ->
        results = (/function (.{1,})\(/).exec((this).constructor.toString())
        if results?.length then results[1] else "unknown"

    has: (x,y) ->
        (@x < x < (@x + @width)) and (@y < y < (@y + @height))

    select: ->
        return if @selection
        @selection = @world.view?.rect(@x,@y,@width,@height)

    deselect: ->
        return unless @selection
        @selection.remove()
        @selection = undefined

    move: (dx,dy) ->
        @view?.translate(dx,dy)
        @selection?.translate(dx,dy)
        @x += dx
        @y += dy

    main: ->
Global.Entity = Entity

# Class to execute commands received from Controller or network
class Executor
    constructor: (@world)->

    create: (data)->
        e = new Global[data.entity](@world)
        e.create data.x, data.y, data.id
        @world.entities[ e.id ] = e
        @world.entitiesCount += 1

    move: (data)->
        @world.entities[ data.id ].move( data.dx, data.dy )

    connect: (data) ->
        console.log "User #{data.id} connected"

    disconnect: (data)->
        console.log "User #{data.id} disconnected"
Global.Executor = Executor

# Main class that incapsulate all other objects
class World extends Observable
    constructor: (@view,@io) ->
        @tick = 0
        @entities = {}
        @entitiesCount = 0
        @executor   = new Executor(this)

    # Find object by location
    find: (x,y) ->
        hits = []
        for k,e of @entities
            hits.push(e) if e.has(x,y)
        return hits

    # Place command to outbox
    send: (action, data) ->
        console.log " -> " + action + ":" + JSON.stringify( data )
        @io.write action, data

    # Connect and start main cycle
    start: ->
        setInterval ( => @loop() ), 100

    execute: (action,data)->
        console.log " <- " + action + ":" + JSON.stringify( data )
        try
            @executor[ action ]( data )
            return true
        catch error
            console.log "ERROR: action=#{action} Error:#{error}"
            return false

    # Main cycle 
    loop: ->
        @tick += 1
        @execute action, data for [action, data] in @io.read()
        e.main() for k,e of @entities
        @io.flush()
Global.World = World
