# Client socket.io connection

class Client extends window.Global.World

    constructor: ( @view )->
        super( view )
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

    message: (msg) ->
        @send 'create', {'entity':'Message','message':msg}


update_layout = ->
    $('#accordion').accordion( "resize" )

# Entry point
$(document).ready ->
    $('body').layout({
        west__size: 300,
        west__onresize: update_layout
    })
    $('#content').tabs()
    $('#accordion').accordion( { fillSpace:true } )
    setTimeout update_layout, 200

    client = new Client( $('#users-list') )

    $('#message').bind "keypress", (e) ->
        code = if e.keyCode then e.keyCode else e.which
        if(code == 13)
            client.message( $(this).attr('value') )
            $(this).attr('value','')
