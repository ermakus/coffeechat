# Client socket.io connection

class Client extends window.Global.World

    constructor: ( @view )->
        super( view )
        @observingSocket = {}
        @socket = new io.Socket()
        @observe "connect", =>
            @userId = @socket.transport.sessionid
            console.log( "Connected: " + @id )
        @observe 'disconnect', =>
            console.log( "Disconnected: " + @id )
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

# Entry point
$(document).ready ->
    client = new Client( $('#users-list') )
    $('#message').bind "keypress", (e) ->
        code = if e.keyCode then e.keyCode else e.which
        if(code == 13)
            client.message( $(this).attr('value') )
            $(this).attr('value','')

