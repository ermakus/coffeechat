# Client socket.io connection

class Client extends window.Model

    constructor: ()->
        super()
        @view = true
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

    socket_send: (json) ->
        @socket.send json


    # Tabs
    tab_init: (eid)->
        @tabs = $(eid).tabs({
            add: (event, ui) =>
                @tabs.tabs('select', '#' + ui.panel.id)
            , closable: true
        })
 
    tab_get_id: ->
        $('.ui-tabs-selected a').attr('href')[1..]

    tab_make: (id, name) ->
        if $('#'+id).length == 0
            @tabs.tabs('add', "#" + id, name )
            $('#'+id).html("<ul id='content-#{id}'/>")

    # Layout
    layout_init: ->
        $('body').layout({
            west__size: 300,
            west__onresize: @layout_update
        })
        $('#accordion').accordion( { fillSpace:true } )
        setTimeout @layout_update, 200

    layout_update: ->
        $('#accordion').accordion( "resize" )

    private_chat: (uid) ->
        @tab_make( 'chat-' + uid, @get( uid ).getName() )

    message: (msg) ->
        @send 'create', {'entity':'Message','message':msg,'from': @get( @userId ).getName(),'to':@tab_get_id() }

# Entry point
$(document).ready ->

    client = new Client()
    client.layout_init()
    client.tab_init('#content')
    client.tab_make('public','Public')

    $('.user').live "click", ->
        client.private_chat( $(this).attr('id') )

    $('#message').bind "keypress", (e) ->
        code = if e.keyCode then e.keyCode else e.which
        if(code == 13)
            client.message( $(this).attr('value') )
            $(this).attr('value','')
