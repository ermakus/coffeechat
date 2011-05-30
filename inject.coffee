class Popup
    constructor: (@base, @url, width, height) ->
        @close = document.createElement 'img'
        @close.setAttribute( "src", @base + "close.png" )
        @close.onclick = =>
            document.body.removeChild( @frame )
            document.body.removeChild( @close )
            window.__popup__ = undefined
        @frame = document.createElement 'iframe'
        @frame.setAttribute( "src", @base + "?url=" + @url )
        @frame.setAttribute( "frameborder", "no" )
        document.body.appendChild( @close )
        document.body.appendChild( @frame )
        @addEvent(window, "resize", => @layout() )
        @layout()

    addEvent: (elem, type, eventHandle) ->
        return if (elem == null || elem == undefined)
        if ( elem.addEventListener )
             elem.addEventListener( type, eventHandle, false )
        else if ( elem.attachEvent )
            elem.attachEvent( "on" + type, eventHandle )

    getClientWidth: ->
        if document.compatMode=='CSS1Compat' && !window.opera then document.documentElement.clientWidth else document.body.clientWidth

    getClientHeight: ->
        if document.compatMode=='CSS1Compat' && !window.opera then document.documentElement.clientHeight else document.body.clientHeight


    layout: ->
        height = @getClientHeight() / 3
        width = @getClientWidth()
        @resize( (@getClientHeight() - height),  (@getClientWidth() - width) / 2, width, height)

    resize: (@top,@left,@width,@height)->
        @frame.style.position = "fixed"
        @frame.style.border = "none"
        @frame.style.top = @top + "px"
        @frame.style.left = @left + "px"
        @frame.style.width = @width + "px"
        @frame.style.height = @height + "px"
        @frame.style.zIndex = 9999
        @close.style.position = "fixed"
        @close.style.top = @top + 10 + "px"
        @close.style.left = @left + @width - 42 + "px"
        @close.style.zIndex = @frame.style.zIndex + 1

if not window.__popup__ then window.__popup__=new Popup( 'http://localhost:8000/', document.URL, 320, 240 )
