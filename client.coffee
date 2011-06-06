# Client model
class Client extends window.Model

    constructor: ()->
        super( new GUI( this ) )
        @observingSocket = {}
        @socket = new io.Socket()
        @observe "connect", =>
            @userId = @socket.transport.sessionid
            console.log( "Connected: " + @userId )
        @observe 'disconnect', =>
            console.log( "Disconnected: " + @userId )
        @observe 'message', (data) =>
            @execute data
        @socket.connect()

    observe: (msg, fn) ->
        super msg, fn
        return if @observingSocket[msg]
        @observingSocket[msg] = true
        @socket.on msg, (json) =>
            data = JSON.parse(json) if json
            @trigger msg, data

    send: (data) ->
        @socket.send JSON.stringify(data)

    privateChat: (uid) ->
        @send {'action':'create','entity':'Channel','name':@get(uid).name,'refs':[@userId,uid] }

    message: (msg) ->
        @send {'action':'create','entity':'Message','message':msg,'from':@get(@userId).name,'channel':@view.tabId() }

class View
    constructor:(@entity)->
        entity.observe 'remove', => @remove()

    remove: ->
        $('#' + @entity.id ).remove()

window.AvatarView = class AvatarView extends View
    constructor:(@entity)->
        super(entity)
        html = $("<li id=#{entity.id} class='avatar #{entity.status} #{if @entity.model.userId == entity.id then "me" else "not-me"}'>#{entity.name}</li>")
        if $('#' + entity.id ).length > 0
            $('#' + entity.id ).replaceWith( html )
        else
            $('#users-list').append( html )

window.MessageView = class MessageView extends View
    constructor:(@entity)->
        super(entity)
        html = $("<li class='message' id=#{entity.id}><span class='message-from'>#{entity.from}</span>:&nbsp;<span class='message-message'>#{entity.message}</span></li>")
        if $('#' + entity.id).length
            $('#' + entity.id ).replaceWith( html )
        else
            $('#content-' + entity.channel.id).append( html )

window.ChannelView = class ChannelView extends View
    constructor:(@entity)->
        super(entity)
        tid = '#tab-' + entity.id
        if $(tid).length == 0
            $('#content').tabs('add', tid, entity.name )
            $(tid).html("<ul id='content-#{entity.id}'/>")

    renove: ->
        tid = '#tab-' + @entity.id
        $(tid).remove()

# Client GUI
class GUI
    constructor: (@model)->
        @layoutInit()

        tabs = $('#content').tabs({
            add: (event, ui) =>
                tabs.tabs('select', '#' + ui.panel.id)
            , closable: true
        })

        $('.avatar').live "click", ->
            model.privateChat( $(this).attr('id') )

        $('#message').bind "keypress", (e) ->
            code = if e.keyCode then e.keyCode else e.which
            if(code == 13)
                model.message( $(this).attr('value') )
                $(this).attr('value','')


    create: (entity) ->
        return new window[ entity.className() + "View" ](entity)

    tabId: ->
        $('.ui-tabs-selected a').attr('href')[5..]

    # Layout
    layoutInit: ->
        $('body').layout({
            west__size: 300,
            west__onresize: @layoutUpdate
        })
        $('#accordion').accordion( { fillSpace:true } )
        setTimeout @layoutUpdate, 200

    layoutUpdate: ->
        $('#accordion').accordion( "resize" )

# Entry point
$(document).ready ->
    client = new Client()

