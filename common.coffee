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

exports.BASE_URL = "http://10.2.45.77:8000"

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

    create: (data) ->
        @name = data.name || "anon-" + @id
        @status = data.status || "online"
        @refs = data.refs || []
        super(data)

    serialize: ->
        data = super()
        data.name = @name
        data.status = @status
        data.refs = @refs
        return data

    show: ->
        html = $("<li id=#{@id} class='user #{@status} #{if @model.userId == @id then "me" else "not-me"}'>#{@name}</li>")
        if $('#' + @id ).length > 0
            $('#' + @id ).replaceWith( html )
        else
            $('#users-list').append( html )

    hide: ->
        $('#' + @id).remove()


exports.Message = class Message extends Entity

    create: (data) ->
        @message = data.message
        @from = @model.get( data.from )
        if data.to == "public"
            @to = {'id':'public','name':'Public', 'refs':[] }
        else
            @to = @model.get( data.to )
        @from.refs.push(@id)
        super(data)

    show: ->
        @model.view.tabMake( @to.id, @to.name )
        $('#content-' + @to.id).append("<li id=#{@id}><span>#{@from.name}</span>:<span>#{@message}</span></li>")

    hide: ->
        $('#' + @id).remove()

    serialize: ->
        data = super()
        data.message = @message
        data.from = @from.id
        data.to = @to.id
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
        avatar = @model.entities[ data.id ]
        if avatar.refs.length > 0
            avatar.status = "offline"
            avatar.show() if @model.view
        else
            avatar.remove()

# Main class that incapsulate all other objects
exports.Model = class Model extends Observable

    constructor: (@view)->
        @entities = {}
        @indexes = {}
        @entitiesCount = 0
        @executor  = new Executor(this)

    add: (e)->
        @entities[ e.id ] = e
        idx = (@indexes[ e.className() ] ||= {})
        idx[ e.id ]  = e
        @entitiesCount += 1

    remove: (e)->
        delete @entities[ e.id ]
        delete @indexes[ e.className() ][ e.id ]
        @entitiesCount -= 1

    get: (id) ->
        return @entities[ id ]

    send: (action, data) ->
        throw "Model.send: Virtual method called"

    execute: (action,data)->
        console.log " <- " + action + ":" + JSON.stringify( data )
        try
            @executor[ action ]( data )
            return true
        catch error
            console.log "ERROR: action=#{action} Error:#{error}"
            return false

