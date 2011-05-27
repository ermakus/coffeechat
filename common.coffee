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

ENTITY_LAST_ID=0

# World object
class Entity
    constructor: (@world, id) ->
        if not id then ENTITY_LAST_ID += 1
        @id = id or ENTITY_LAST_ID

    create: (@x,@y,@width,@height) ->
        @elem = @world.render.image( @x, @y, @width, @height, 'entity.png' )

    remove: ->
        @world.render.remove( @elem )
        delete @world.entities[ @id ]
        @world.entitiesCount -= 1

    className: ->
        results = (/function (.{1,})\(/).exec((this).constructor.toString())
        if results?.length then results[1] else "unknown"

    has: (x,y) ->
        (@x < x < (@x + @width)) and (@y < y < (@y + @height))

    select: ->
        return if @selected
        @selected = @world.render.rect(@x,@y,@width,@height)

    deselect: ->
        return unless @selected
        @world.render.remove( @selected )
        @selected = undefined

    move: (dx,dy) ->
        @x += dx
        @y += dy
        @world.render.move( @elem, @x, @y )
        if @selected then @world.render.move( @selected, @x, @y )

    main: ->

Global.Entity = Entity

class Avatar extends Entity
    create: (@x,@y,@width,@height) ->
        @elem = @world.render.image( @x, @y, @width, @height, 'anon.png' )

    login: (@name) ->
        @world.render.remove( @elem )
        @elem = @world.render.image( @x, @y, @width, @height, 'avatar.png' )

Global.Avatar = Avatar

class Render
    image: (x,y,src) ->
    rect: (x,y,width,height) ->
    remove: (elem) ->
    move: (elem, x, y ) ->

Global.Render = Render

# Class to execute commands received from Controller or network
class Executor
    constructor: (@world)->

    create: (data)->
        e = new Global[data.entity](@world, data.id )
        e.create data.x, data.y, data.width, data.height
        @world.push( e )

    move: (data)->
        @world.entities[ data.id ].move( data.dx, data.dy )

    connect: (data) ->
        console.log "User #{data.id} connected"
        e = new Avatar(@world,data.id)
        e.create( 100,100,32,32 )
        @world.push e

    disconnect: (data)->
        console.log "User #{data.id} disconnected"
        @world.entities[ data.id ].remove()

    # Called when user submit login form
    login: (data)->
        @world.entities[ data.id ].login( data.login )

Global.Executor = Executor

# Main class that incapsulate all other objects
class World extends Observable

    constructor: ()->
        @render = new Render()
        @tick = 0
        @entities = {}
        @entitiesCount = 0
        @executor   = new Executor(this)
        @outbox = []
        @inbox = []

    flush: ->
        return unless @outbox.length
        @socket_send JSON.stringify(@outbox)
        @outbox = []

    read: ->
        ret = @inbox
        @inbox = []
        ret

    push: (e)->
        @entities[ e.id ] = e
        @entitiesCount += 1

    # Find object by location
    find: (x,y) ->
        hits = []
        for k,e of @entities
            hits.push(e) if e.has(x,y)
        return hits

    # Place command to outbox
    send: (action, data) ->
        console.log " -> " + action + ":" + JSON.stringify( data )
        @outbox.push [action,data]

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
        @execute action, data for [action, data] in @read()
        e.main() for k,e of @entities
        @flush()
Global.World = World

