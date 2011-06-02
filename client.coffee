# Client socket.io connection

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
            @execute data[0], data[1]
        @socket.connect()

    observe: (msg, fn) ->
        super msg, fn
        return if @observingSocket[msg]
        @observingSocket[msg] = true
        @socket.on msg, (json) =>
            data = JSON.parse(json) if json
            @trigger msg, data

    send: (action,data) ->
        @execute action,data
        @socket.send JSON.stringify([action,data])

    privateChat: (uid) ->
        @view.tabMake( uid, @get( uid ).name )

    message: (msg) ->
        @send 'create', {'entity':'Message','message':msg,'from':@userId,'to':@view.tabId() }

class GUI
    constructor: (@model)->
        @layoutInit()
        @tabInit('#content')
        @tabMake('public','Public')

        $('.user').live "click", ->
            model.privateChat( $(this).attr('id') )

        $('#message').bind "keypress", (e) ->
            code = if e.keyCode then e.keyCode else e.which
            if(code == 13)
                model.message( $(this).attr('value') )
                $(this).attr('value','')

    # Tabs
    tabInit: (eid)->
        @tabs = $(eid).tabs({
            add: (event, ui) =>
                @tabs.tabs('select', '#' + ui.panel.id)
            , closable: true
        })
 
    tabId: ->
        $('.ui-tabs-selected a').attr('href')[5..]

    tabMake: (id, name) ->
        tid = '#tab-' + id
        if $(tid).length == 0
            @tabs.tabs('add', tid, name )
            $(tid).html("<ul id='content-#{id}'/>")

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

