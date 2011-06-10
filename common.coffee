if window?
    # Export namespace for browser
    exports = window
    # Stubs for old browsers
    window.console ||= {}
    window.console[fn] ||= (->) for fn in ['log', 'dir', 'error', 'warn']
else
    exports = module.exports

exports.BASE_URL = "http://localhost:8000"

# Remove function for arrays
Array::remove = (e) -> @[t..t] = [] if (t = @.indexOf(e)) > -1

# GUID generator
GUID = ->
   S4 = -> (((1+Math.random())*0x10000)|0).toString(16).substring(1)
   (S4()+S4()+"-"+S4()+"-"+S4()+"-"+S4()+"-"+S4()+S4()+S4())

# Observer pattern
exports.Observable = class Observable
  observe: (name, fn) ->
    @observers(name).push fn

  trigger: (name, args...) ->
    callback args... for callback in @observers(name)

  observers: (name) ->
    (@_observers ||= {})[name] ||= []

# Base object contained in model
exports.Entity = class Entity extends Observable
    constructor: (@model, data) ->
        @id = data.id or GUID()
        console.log "Create entity: #{@className()}::#{@id}=#{JSON.stringify( data )}"
        @refs = data.refs or []
        @model.add this

    remove: ->
        console.log "Delete entity: #{@className()}::#{@id}"
        @trigger 'remove', this
        @model.remove this

    className: ->
        results = (/function (.{1,})\(/).exec((this).constructor.toString())
        if results?.length then results[1] else "unknown"

    serialize: (data) ->
        data ||= {}
        data.entity=@className()
        data.id=@id
        data.refs=@refs
        data

    link: (entity) ->
        if @refs.indexOf( entity.id ) < 0 then @refs.push( entity.id )
        if entity.refs.indexOf( @id ) then entity.refs.push( @id )
            

    unlink: (entity) ->
        entity.refs.remove( @id )
        @refs.remove( entity.id )

    links: ->
        @model.get( id ) for id in @refs

    linkCount: ->
        @refs.length

    hasLink: (entity)->
        @refs.indexOf( entity.id ) >= 0

exports.Avatar = class Avatar extends Entity

    constructor: (model,data) ->
        super(model,data)
        @name = data.name || "anon-" + @id
        @status = data.status || "online"

    serialize: (data)->
        data = super(data)
        data.name = @name
        data.status = @status
        return data

exports.Channel = class Channel extends Entity
    constructor: (model,data) ->
        super(model,data)
        @name = data.name or "Public"

    serialize: (data)->
        data = super(data)
        data.name = @name
        return data

exports.Message = class Message extends Entity

    constructor: (model,data) ->
        super(model,data)
        @message = data.message
        @from = data.from
        @channel = @model.get( data.channel )

    remove: ->
        super()

    serialize: (data)->
        data = super(data)
        data.message = @message
        data.from = @from
        data.channel = @channel.id
        return data

# Class to execute commands received from Controller or network
exports.Controller = class Controller
    constructor: (@model)->

    create: (data)->
        entity = new exports[data.entity](@model, data)
        data.id = entity.id
        if @model.view? then @model.view.create entity
        entity

    createChannel: (data)->
        channel = @create data
        data.channel = channel.id
        channel

    connect: (data) ->
        console.log "User #{data.id} connected"
        avatar = @model.get(data.id) or new Avatar(@model,data)
        @model.public.link(avatar)
        if @model.view? then @model.view.create avatar
        avatar

    disconnect: (data)->
        console.log "User #{data.id} disconnected"
        avatar = @model.get( data.id )
        @model.public.unlink(avatar)
        avatar.remove()

# Main class that incapsulate all other objects
exports.Model = class Model extends Observable

    constructor: (@view)->
        @entities = {}
        @indexes = {}
        @entitiesCount = 0
        @controller  = new Controller(this)

        # Create default public channel
        @public = @controller.create {'entity':'Channel','id':'public','name':'Public'}

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

    send: (data) ->
        throw "Model.send: Virtual method called"

    execute: (data)->
        console.log " <- " + JSON.stringify( data )
#        try
        @controller[ data.action ]( data )
        return true
#       catch error
#           console.log "ERROR: action=#{data.action} Error:#{error}"
#            return false

