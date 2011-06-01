if window?
    # Export namespace for browser
    exports = window
    # Stubs for old browsers
    window.console ||= {}
    window.console[fn] ||= (->) for fn in ['log', 'dir', 'error', 'warn']
else
    exports = module.exports

# Remove function for arrays
Array::remove = (e) -> @[t..t] = [] if (t = @.indexOf(e)) > -1

exports.BASE_URL = "http://192.168.122.1:8000"

# Observer pattern
exports.Observable = class Observable
  observe: (name, fn) ->
    @observers(name).push fn

  trigger: (name, args...) ->
    callback args... for callback in @observers(name)

  observers: (name) ->
    (@_observers ||= {})[name] ||= []

ENTITY_LAST_ID=0

# Base object contained in model
exports.Entity = class Entity
    constructor: (@model, id) ->
        if not id then ENTITY_LAST_ID += 1
        @id = id or ENTITY_LAST_ID

    create: (data) ->
        console.log "Create entity: #{@className()}::#{@id}=#{JSON.stringify( data )}"
        if @model.view then @show()

    kill: ->
        console.log "Delete entity: #{@className()}::#{@id}"
        if @model.view then @hide()

    show: ->

    hide: ->

    remove: ->
        @kill()
        @model.remove( this )

    className: ->
        results = (/function (.{1,})\(/).exec((this).constructor.toString())
        if results?.length then results[1] else "unknown"

    serialize: ->
        return { 'entity':@className(), 'id':@id }

exports.Avatar = class Avatar extends Entity

    getName: ->
        @name ||= "Anonymous"
        if @id == @model.userId then return @name + " (You)"
        return @name

    show: ->
        $('#users-list').append("<li id=#{@id} class='user'>#{@getName()}</li>")

    hide: ->
        $('#' + @id).remove()


exports.Message = class Message extends Entity

    create: (data) ->
        @message = data.message
        @from = data.from
        @to = data.to
        super(data)

    show: ->
        @model.tab_make( @to, @to )
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
exports.Executor = class Executor
    constructor: (@model)->

    create: (data)->
        e = new exports[data.entity](@model, data.id )
        e.create data
        @model.add e

    connect: (data) ->
        console.log "User #{data.id} connected"
        e = new Avatar(@model,data.id)
        e.create( data )
        @model.add e

    disconnect: (data)->
        console.log "User #{data.id} disconnected"
        @model.entities[ data.id ].remove()

# Main class that incapsulate all other objects
exports.Model = class Model extends Observable

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

