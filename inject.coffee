BASE_URL = "http://192.168.122.1:8000/"

class Popup
    constructor: (@base, @url, width, height) ->
        @close = document.createElement 'img'
        @close.setAttribute( "src", @base + "close.png" )
        @close.onclick = =>
            document.body.removeChild( @frame )
            document.body.removeChild( @close )
            document.body.removeChild( @hbar )
            window.__popup__ = undefined

        @hbar = document.createElement('div')

        @hbar.onmousedown = (e) =>
            @iframe.style.display = "none"
            if e
                e.preventDefault()
            else
                event.returnValue = false

        @addEvent document, "mouseup", (e) =>
            @moveY = undefined
            @iframe.style.display = "block"

        @addEvent document, "mousemove", (e) =>
            if @iframe.style.display == "none"
                clh = @getClientHeight()
                @height = clh - e.clientY
                if @height < 0 then @height = 0
                if @height > (clh - 6) then @height = clh - 6
                @layout()

        @frame = document.createElement 'div'
        document.body.appendChild( @hbar )
        document.body.appendChild( @close )
        document.body.appendChild( @frame )

        @iframe = document.createElement 'iframe'
        @iframe.setAttribute 'width', '100%'
        @iframe.setAttribute 'height', '100%'
        @iframe.setAttribute 'src', @base + "main?url=" + encodeURI( @url )
        @iframe.setAttribute 'frameborder', 'no'
        @frame.appendChild @iframe

        @addEvent(window, "resize", => @layout() )
        @initStyle()

        @height = @getClientHeight() / 2
        @width = @getClientWidth()
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
        @resize( (@getClientHeight() - @height),  (@getClientWidth() - @width) / 2, @width, @height)

    initStyle: ->
        @frame.style.position = @hbar.style.position = @close.style.position = "fixed"
        @frame.style.border = "none"
        @frame.style.zIndex = 9999
        @frame.style.background = "#DDD"
        @close.style.zIndex = @frame.style.zIndex + 1
        @hbar.style.background = "#DDD"
        @hbar.style.border = "1px solid #BBB"
        @hbar.style.left = 0
        @hbar.style.height = "6px"
        @hbar.style.cursor = "s-resize"
        @hbar.style.padding = 0
        @hbar.style.margin = 0
        @hbar.style.zIndex = @close.style.zIndex

  
    resize: (@top,@left,@width,@height)->

        @hbar.style.top = @top - 6 + "px"
        @hbar.style.width = @width + "px"
 
        @frame.style.top = @top + "px"
        @frame.style.left = @left + "px"
        @frame.style.width = @width + "px"
        @frame.style.height = @height + "px"
        @close.style.top = @top + 2 + "px"
        @close.style.left = @left + @width - 32 + "px"

if not window.__popup__ then window.__popup__=new Popup( BASE_URL, document.URL, 320, 240 )
