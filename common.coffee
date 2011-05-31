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
Global.Entity = class Entity
    constructor: (@world, id) ->
        if not id then ENTITY_LAST_ID += 1
        @id = id or ENTITY_LAST_ID

    create: (data) ->
        console.log "Create entity: #{@className()}::#{@id}=#{JSON.stringify( data )}"
        if @world.view then @show()

    kill: ->
        console.log "Delete entity: #{@className()}::#{@id}"
        if @world.view then @hide()

    show: ->

    hide: ->

    remove: ->
        @kill()
        @world.remove( this )

    className: ->
        results = (/function (.{1,})\(/).exec((this).constructor.toString())
        if results?.length then results[1] else "unknown"

    serialize: ->
        return { 'entity':@className(), 'id':@id }

Global.Avatar = class Avatar extends Entity

    getName: ->
        @name ||= "Anonymous"
        if @id == @world.userId then return @name + " (You)"
        return @name

    show: ->
        $('#users-list').append("<li id=#{@id} class='user'>#{@getName()}</li>")

    hide: ->
        $('#' + @id).remove()


Global.Message = class Message extends Entity

    create: (data) ->
        @message = data.message
        @from = data.from
        @to = data.to
        super(data)

    show: ->
        @world.tab_make( @to, @to )
        $('#content-' + @to).append("<li id=#{@id}><span>#{@from}</span>:<span>#{@message}</span></li>")

    hide: ->
        $('#' + @id).remove()

    serialize: ->
        data = super()
        data.message = @message
        data.from = @from
        data.to = @to
        return data


# Class to execute commands received from Controller or network
Global.Executor = class Executor
    constructor: (@world)->

    create: (data)->
        e = new Global[data.entity](@world, data.id )
        e.create data
        @world.add e

    connect: (data) ->
        console.log "User #{data.id} connected"
        e = new Avatar(@world,data.id)
        e.create( data )
        @world.add e

    disconnect: (data)->
        console.log "User #{data.id} disconnected"
        @world.entities[ data.id ].remove()

# Main class that incapsulate all other objects
Global.World = class World extends Observable

    constructor: (@view)->
        @entities = {}
        @entitiesCount = 0
        @executor  = new Executor(this)

    add: (e)->
        @entities[ e.id ] = e
        @entitiesCount += 1

    remove: (e)->
        delete @entities[ e.id ]
        @entitiesCount -= 1

    get: (id) ->
        return @entities[ id ]

    send: (action, data) ->
        console.log " -> " + action + ":" + JSON.stringify( data )
        @socket_send JSON.stringify([action,data])

    execute: (action,data)->
        console.log " <- " + action + ":" + JSON.stringify( data )
        try
            @executor[ action ]( data )
            return true
        catch error
            console.log "ERROR: action=#{action} Error:#{error}"
            return false

