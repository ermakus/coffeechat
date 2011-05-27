# Client socket.io connection

class DOMRender extends window.Global.Render

    constructor: ( id )->
        @container = $('#' + id )

    image: (x,y,width,height,src) ->
        elem = $('<img/>').css({'position':'absolute','display':'block','top':y,'left':x, width, height})
        elem.attr('src',src)
        elem.appendTo( @container )

    rect: (x,y,width,height) ->
        elem = $('<div/>').css({'position':'absolute','top':y,'left':x,'width':width,'height':height,'border':'solid black 1px'})
        elem.appendTo( @container )

    remove: (elem) ->
        elem.remove()

    move: (elem,x,y) ->
        elem.css('top':y, 'left':x)

    resize: (elem,width,height) ->
        elem.css( {width, height} )

class Tool
    constructor: (@toolbar, icon)->
        @elem = $("<img src='/cmd/#{icon}.png'/>").appendTo( @toolbar.elem )
        @elem.click =>
            for tool in @toolbar.tools
                tool.deselect()
            @select()

    select: ->
        @elem.css('background-color':'#8888FF')
        @toolbar.tool = this

    deselect: ->
        @elem.css('background-color':'transparent')
        @toolbar.tool = undefined

    click: (x,y) ->
    release: (x,y) ->
    move: (x,y) ->

class SelectTool extends Tool
    constructor: (toolbar)->
        super( toolbar, 'select')

    # Mouse click handler
    click: (@x,@y) ->
       @down = true
       @toolbar.deselect()
       @toolbar.select(x,y)

    # Mouse release handler
    release: (@x,@y) ->
        @down = false

    # Mouse move handler
    move: (x,y) ->
        if @down then @toolbar.world.send( "move", { "id":e.id, "dx": x - @x,  "dy": y - @y } ) for e in @toolbar.selection
        @x = x
        @y = y
   
class ImageTool extends Tool
    constructor: (toolbar)->
        super( toolbar, 'create')

    click: (@x,@y) ->
        @area = @toolbar.world.render.rect(@x,@y,1,1)

    move: (x,y) ->
        if @area
            @toolbar.world.render.resize( @area, x-@x, y-@y )

    # Mouse release handler
    release: (x,y) ->
        @toolbar.world.send "create", {'entity':'Entity','x':@x,'y':@y, 'width':x-@x, 'height':y-@y }
        @toolbar.world.render.remove( @area )
        @deselect()

class UploadTool extends Tool
    constructor: (toolbar)->
        super( toolbar, 'upload')

    select: ->
        $('#upload-dialog').dialog('open')
        $('#upload-ok').click ->
            $('#upload-form').submit()

class LoginTool extends Tool
    constructor: (toolbar)->
        super( toolbar, 'login')

    select: ->
        $('#login-dialog').dialog('open')
        $('#login-ok').click =>
            nick = $('#login-name').attr('value').trim()
            if nick  != ""
                @toolbar.world.send "login", {nick,"id":@toolbar.world.userId}
                $(".dialog").dialog('close')

class Toolbar
    constructor: ( id, @world ) ->
        @elem = $('#'+id)
        @tools = []
        @tools.push( new LoginTool( this ) )
        @tools.push( new SelectTool( this ) )
        @tools.push( new ImageTool( this ) )
        @tools.push( new UploadTool( this ) )

        content = $('#' + @world.container )
        content.bind "mousedown", (e) =>
            @tool?.click e.pageX, e.pageY
        content.bind "mouseup", (e) =>
            @tool?.release e.pageX, e.pageY
        content.bind "mousemove", (e) =>
            @tool?.move e.pageX, e.pageY

        @selection = []

    # Select object by coordinate
    select: (x,y) ->
        @selection = @world.find(x,y)
        for e in @selection
            e.select()
        @selection.length

    # Deselect all objects
    deselect: ->
        for e in @selection
            e.deselect()
        @selection = []

class ClientWorld extends window.Global.World

    constructor: ( @container )->
        super()
        @render = new DOMRender(@container)
        @socket = new io.Socket()
        @observe "connect", =>
            @userId = @socket.transport.sessionid
            console.log( "Connected: " + @id )
        @observe 'disconnect', =>
            console.log( "Disconnected: " + @id )
        @observe 'message', (data) =>
            @inbox = @inbox.concat data
        @socket.connect()

    observe: (msg, fn) ->
        super msg, fn
        @observingSocket ||= {}
        return if @observingSocket[msg]
        @observingSocket[msg] = true
        @socket.on msg, (json) =>
            data = JSON.parse(json) if json
            @trigger msg, data

    socket_send: (json) ->
        @socket.send json

# Entry point
$(document).ready ->
    $('.cancel').click -> $(".dialog").dialog('close')
    $('.dialog').dialog({ autoOpen: false })
    world = new ClientWorld( 'content' )
    toolbar = new Toolbar( 'toolbar', world )
    world.start()
