n_slides_global = 0
use_html2canvas = false

# -----------------------------------------------------------------------
# Slides and Builds
# -----------------------------------------------------------------------

# a dictionary of object for executing builds
# should be able to add new ones at any point
build_types =
    appear: (slide, target) ->
        do: (cb) -> $(target, slide).css('opacity', 1.0); cb() if cb
        undo: (cb) -> $(target, slide).css('opacity', 0.0); cb() if cb

    disappear: (slide, target) ->
        do: (cb) -> $(target, slide).css('opacity', 0.0); cb() if cb
        undo: (cb) -> $(target, slide).css('opacity', 1.0); cb() if cb

    fade_in: (slide, target, duration='slow') ->
        do: (cb) -> $(target, slide).animate({'opacity': 1.0}, duration, cb)
        undo: (cb) -> $(target, slide).animate({'opacity': 0.0}, 0, cb)

    fade_out: (slide, target, duration='slow') ->
        do: (cb) -> $(target).animate({'opacity': 0.0}, duration, cb)
        undo: (cb) -> $(target).animate({'opacity': 1.0}, 0, cb)

    opacity: (slide, target, op, duration='slow') ->
        @last_opacity
        do: (cb) ->
            console.log('doing opacity')
            @last_opacity = $(target, slide).css('opacity')
            lo = @last_opacity
            $(target, slide).animate({'opacity': op}, duration, cb)

        undo: (cb) ->
            # restore a previously stored opacity, if one is available
            if @last_opacity != undefined
                lo = @last_opacity
                $(target, slide).animate({'opacity': lo}, 0, cb)
            else
                # if last_opacity is undefined, check if one is specified
                if $(target, slide).css('opacity')
                    @last_opacity = $(target, slide).css('opacity')
                cb() if cb

    play: (slide, target) ->
        do: (cb) ->
            try $(target, slide).get(0).play()
            cb() if cb
        undo: (cb) ->
            try
                $(target, slide).get(0).pause()
                $(target, slide).get(0).currentTime = 0
            cb() if cb

    composite: (subbuilds) ->
        do: (cb) ->
            res = (b.do() for b in subbuilds)
            console.log(res)
            cb() if cb
        undo: (cb) ->
            res = (b.undo() for b in subbuilds)
            cb() if cb

    # ... many more to come ...


# JQuery is buggy as hell when it comes to anything not-exactly-HTML.
# In particular, selectors into SVG behave in unpredictable ways.
# This recursive function searches each and every element, depth first,
# until it finds the matching ID
exhaustiveSearchByID = (parent, id) ->

    if parent == null or parent == undefined or parent.getAttribute == undefined
        return null

    if parent.getAttribute('id') == id
        return $(parent)

    children = []
    if parent.getChildren != undefined
        children = parent.getChildren()

    if parent.childNodes != undefined
        children = parent.childNodes

    if children.length == 0
        return null

    for child in children
        ret = exhaustiveSearchByID(child, id)
        if ret != null
            return ret

    return null

# An object to encapsulate the bookkeeping of each slide
class Slide
    @build_list
    @current_build_idx

    constructor: (@slide_div) ->
        @build_list = []
        @current_build_idx = 0
        @first_show = true

        if !slide_div.attr('id')
            unique_id = 'slide_' + n_slides_global++
            slide_div.attr('id', unique_id)

        # Parse and add the builds
        bl = @build_list
        slide = this
        $('.build, .set, .incremental ul li, .incremental li, .incremental > *:not(ul)',
          @slide_div).each (i) ->
            b = $(this)

            # flag is this is a "set" directive
            set_directive = false
            if b.hasClass('set')
                set_directive = true

            build_id = 'build_' + (bl.length + 1) + '_' + slide_div.attr('id')
            b.attr('id', build_id)

            # if it's a build directive, parse it appropriately
            if b.hasClass('build') or set_directive

                # get the "content" of the build directive
                bstr = b.text()
                subbstrs = bstr.split(/\n+|;\n*/)

                subbuilds = []

                for subbstr in subbstrs
                    matchstr = ///
                        ((\w|\d)+)       # name of the build
                        \s*\(\s*        # open paren
                        (.*?)           # arg list
                        \s*\)           # close paren
                    ///

                    matches = subbstr.match(matchstr)

                    if matches == null
                        continue

                    type = matches[1]
                    argstr = matches[3]
                    args = argstr.split(/\s*,\s*/)
                    target = args.shift()
                    target = target.replace(/['"]/g, '')

                    if $(target) is null
                        alert("Invalid target #{target} in build #{subbstr}")

                    target = slide.modifyTargetIdForUniqueness(target)

                    build_obj = build_types[type](@slide_div, target, args...)

                    # if it is a "set", modify the build a bit
                    if set_directive
                        build_obj.undo = build_obj.do
                        build_obj.do = () ->
                        build_obj.auto_advance = true
                    else
                        build_obj.auto_advance = false

                    subbuilds.push(build_obj)

                if subbuilds.length == 0
                    alert('Unable to build composite build: no sub builds...')
                else if subbuilds.length == 1
                    bl.push(subbuilds[0])
                else
                    composite_build = build_types['composite'](subbuilds.slice(0).reverse())
                    composite_build.auto_advance = subbuilds[0].auto_advance
                    bl.push(composite_build)

            # for "ordinary" incremental display
            else
                bl.push(build_types['appear'](@slide_div, '#' + build_id))



        # $('.bullets').textfill({'innerTag':'li'})

        # set the slide content to an appropriate initial state
        #build.do() for build in @build_list
        @reset()

        return this

    modifyTargetIdForUniqueness: (target) ->
        slide_id = @slide_div.attr('id')
        this_slide = @slide_div

        target_id = target.replace(/#/g,'')

        # t = $(target, this_slide)
        t = this_slide.find(target)
        console.log(t)

        new_target = target_id + '_' + slide_id
        new_target_sel = '#' + new_target

        if t == undefined or t == null or t.length == 0
            # try to route around bugs in JQuery selection into SVGs
            t = exhaustiveSearchByID($('svg', this_slide).get(0), target_id)

        if t == undefined or t == null or t.length == 0
            # if we still couldn't find an appropriate match, just pass back the original
            # target selector, unmodified
            console.log('Could not find element matching target: ' + target)
            return target

        console.log(t)
        console.log('modifying ' + target + ' to ' + new_target)

        t.attr('id', new_target)
        console.log('now: ' + t.attr('id') + ', ' + t)

        return new_target_sel

    getDiv: ->
        return @slide_div

    reset: ->
        # undo the builds in reverse order
        console.log('reseting: ' + @slide_div.eq(0).attr('id'))
        build.undo() for build in @build_list.slice(0).reverse()
        @current_build_idx = 0

    fullReset: ->
        @first_show = true

    hasBuilds: -> !@build_list.empty

    doNextBuild: ->
        if @current_build_idx >= @build_list.length
            return false
        else
            current_build = @build_list[@current_build_idx]

            current_build.do()
            @current_build_idx += 1

            if current_build.auto_advance
                return @doNextBuild()

            return true

    undoPreviousBuild: ->

        @current_build_idx -= 1

        if @current_build_idx < 0
            @current_build_idx = 0
            return false
        else
            current_build = @build_list[@current_build_idx]
            current_build.undo()

            if current_build.auto_advance
                return @undoPreviousBuild()
            return true

    show: (cb) ->
        if @first_show
            @reset()
            @first_show = false
        $(@slide_div).show(0, cb)

        # I'm not sure why this is needed...
        @refreshVisibility(@slide_div)

    # Hack to convince Webkit to actually, you know, display stuff...
    refreshVisibility: (parent) ->
        includes = $('.svg_include', parent)
        includes.each ->
            local_parent = $(this)
            $('svg', local_parent).each ->
                svg = $(this).remove()
                local_parent.append(svg)


    hide: ->
        $(@slide_div).hide()

# -----------------------------------------------------------------------
# Presentation Logic
# -----------------------------------------------------------------------

class Presentation

    # a list of slide objects
    @slides: []
    @current_slide_idx: 0

    # -----------------------------------------------------------------------
    # Setup
    # -----------------------------------------------------------------------

    constructor: () ->
        @slides = []
        @current_slide_idx = 0

        base_font_size = parseFloat($('body').css('font-size'))
        @adjustBaseFontSize(base_font_size)
        window.onresize = (evt) => @adjustBaseFontSize(base_font_size)

        # A unique. incrementing number to help minimize irritating browser
        # caching of includes
        @unique_number = 0

        # load DOM pseudo-includes, synchronously, before slide objs are created
        @loadIncludes(false)

        # load the slides
        sl = @slides
        $('.slide').each (i) ->
            s = new Slide($(this))
            sl.push(s)

        # display the first slide
        @checkURLBarLocation()
        @showCurrent()

        # add a slide controls overlay
        @initControls()

        # build the table of contents
        @buildTOC()

        # bind appropriate handlers
        document.onkeydown = (evt) => @keyDown(evt)
        document.onkeyup = (evt) => @keyUp(evt)

        # handlers for jquery mobile events
        $('#presentation').bind('tap', (evt) => @advanceQueued())
        $('#presentation').bind('swipeleft', (evt) => @advanceSlideQueued())
        $('#presentation').bind('swiperight',
                                (evt) =>
                                    @revertSlideQueued()
                                    @resetCurrentQueued())

        # setup up a recurring check to sync the browser location field with
        # the slideshow
        @checkURLBarPeriodically(100)

        # a queue to ensure that user commands happen in some kind of sane
        # sequence (actually, it's an empty element)
        @actions = $({})


    adjustBaseFontSize: (base_font_size, ref_width=1024, ref_height=768) ->
        # adjust the base font size according to the window size
        width = window.innerWidth
        height = window.innerHeight

        current_aspect = height / width
        ref_aspect = ref_height / ref_width
        console.log(current_aspect)
        console.log(ref_aspect)
        console.log(base_font_size)

        if current_aspect >= ref_aspect
            # height constrains
            factor = height / ref_height
        else
            factor = width / ref_width

        new_font_size = factor * base_font_size
        console.log('Setting new font size: ' + new_font_size)
        $('body').css('font-size', new_font_size)


    loadIncludes: (async=false)->
        p = this

        # change the faux include commands to properly included dom
        $('.svg_include').each (i) ->
            div = $(this)
            div.empty()
            p.unique_number += 1
            path = div.attr('src') + '?' + p.unique_number
            console.log('path: ' + path)
            if div
                $.ajax(
                    url: path
                    async: async
                    success: (xml) ->
                        div.get(0).appendChild(xml.documentElement)
                        #p.showCurrent(-> p.resetCurrent())
                    error: (err) ->
                        div.append($("<p>An error occurred loading #{path}</p>"))
                )
                #$.get(path, success, error)


        # $('g').each (i) ->
        #             op = $(this).css('opacity')
        #             console.log("opacity = #{op}")
        #             if $(this).css('opacity') == undefined
        #                 $(this).css('opacity', 1.0)


    # -----------------------------------------------------------------------
    # Movement
    # -----------------------------------------------------------------------

    # move forward
    advance: ->
        # try to advance a build, otherwise, move to next slide
        if !@advanceBuild()
            @advanceSlide()


    # go back
    revert: ->
        # try to revert the last build, otherwise, move back one slide
        if !@revertBuild()
            @revertSlide()


    advanceQueued: ->
        p = this
        a = @actions
        a.queue('user_interaction', -> p.advance() )
        a.dequeue('user_interaction')

    revertQueued: ->
        p = this
        a = @actions
        a.queue('user_interaction', -> p.revert() )
        a.dequeue('user_interaction')

    advanceSlideQueued: ->
        p = this
        a = @actions
        a.queue('user_interaction', -> p.advanceSlide() )
        a.dequeue('user_interaction')

    revertSlideQueued: ->
        p = this
        a = @actions
        a.queue('user_interaction', -> p.revertSlide() )
        a.dequeue('user_interaction')

    resetSlideQueued: ->
        p = this
        a = @actions
        a.queue('user_interaction', -> p.resetCurrent() )
        a.dequeue('user_interaction')

    # move to next slide
    advanceSlide: ->
        @current_slide_idx += 1
        if @current_slide_idx >= @slides.length
            @current_slide_idx = @slides.length - 1
        @showCurrent()

    # go back one slide
    revertSlide: ->
        @current_slide_idx -= 1
        if @current_slide_idx < 0
            @current_slide_idx = 0
        @showCurrent()

    setCurrent: (i) ->
        @current_slide_idx = i

    showCurrent: (cb)->
        @slides[i].hide() for i in [0 .. @slides.length-1] when i isnt @current_slide_idx
        @slides[@current_slide_idx].show(cb)
        location.hash = @current_slide_idx + 1

    resetCurrent: ->
        @slides[@current_slide_idx].reset()

    currentSlideDiv: ->
        return @slides[@current_slide_idx].getDiv()

    # build out the next increment of the current slide
    advanceBuild: ->
        @slides[@current_slide_idx].doNextBuild()

    # un-build the previous increment of the current slide
    revertBuild: ->
        @slides[@current_slide_idx].undoPreviousBuild()


    keyUp: (evt) ->
        key = evt.keyCode
        if key is 16 then @shiftKeyActive = false

    keyDown: (evt) ->
        key = evt.keyCode
        if key >= 48 and key <= 57 # 0-9
            alert('number key!')

        switch key
            # shift
            when 16 then @shiftKeyActive = true
            # space
            when 32
                @advance()

            # left arrow, page up, up arrow
            when 37, 33, 38
                if @shiftKeyActive then @revertSlideQueued() else @revertQueued()
            # right arrow, page down, down arrow
            when 39, 34, 30
                if @shiftKeyActive then @advanceSlideQueued() else @advanceQueued()
            when 67 then @toggleControls() # c
            when 82 then @resetCurrent()   # r
            when 84 then @toggleTOC() # t
            when 69 then @toggleEditPickerMode()# e

    initControls: ->
        # copy "this" into a variable for the sake of the closure
        p = this

        back_btn = $('#back_button')
        back_btn.button({icons: {primary: 'ui-icon-triangle-1-w'}, text: false})
        back_btn.click -> p.revert()


        fwd_btn = $('#forward_button')
        fwd_btn.button({icons: {primary: 'ui-icon-triangle-1-e'}, text: false})
        fwd_btn.click -> p.advance()

        edit_btn = $('#edit_button')
        edit_btn.button({icons: {primary: 'ui-icon-extlink'}, text: false})
        edit_btn.click ->
            p.externalEditPickerMode(edit_btn.attr('checked') == 'checked')

        edit_inplace_btn = $('#edit_inplace_button')
        edit_inplace_btn.button({icons: {primary: 'ui-icon-pencil'}, text: false})
        edit_inplace_btn.click ->
            p.inplaceEditPickerMode(edit_inplace_btn.attr('checked') == 'checked')

        hover_on = -> $(this).addClass('ui-state-hover')
        hover_off = -> $(this).removeClass('ui-state-hover')
        $('#presentation_controls button').hover(hover_on, hover_off)
        $('#presentation_controls input').hover(hover_on, hover_off)

        # Make the controls draggable
        $('#presentation_controls').draggable()
        $('#presentation_controls').addClass('ui-widget-shadow')

        # hide by default
        $('#presentation_controls').hide()

        # attach the "veil" to gray out the screen when needed
        $('body').append('<div id="veil"></div>')
        $('veil').hide()

        # prepare the notifications popups
        $('#notification_popup').notify()

        save_btn = $('#save_button').button()
        save_btn.click ->
            p.saveInplaceEdit(-> p.reloadAfterEdit())

        cancel_btn = $('#cancel_button').button()
        cancel_btn.click ->
            p.editPickerMode(false, false, false)

    toggleControls: ->
        $('#presentation_controls').toggle()

    transientMessage: (title, msg="", duration=1000) ->
        $('#notification_popup').notify('create',
            {title: title, text: msg, expires: duration, speed: 500})


    externalEditPickerMode: (enabled) ->
        @editPickerMode(enabled, true)

    inplaceEditPickerMode: (enabled) ->
        @editPickerMode(enabled, false)

    toggleEditPickerMode: ->
        @editPickerMode((not @edit_picker_enabled))

    # DDC: TODO: refactor all of this picker business to be cleaner
    editPickerMode: (@edit_picker_enable, external, save=true) ->
        p = this
        current = p.currentSlideDiv()

        if p.edit_picker_enable

            # if there's only one SVG, just go ahead and start editing

            if $('.svg_include', current).length == 1
                p.inplaceEdit($('.svg_include', current).eq(0))
                return

            # otherwise, start up the SVG picker mode

            @transientMessage('Click on an SVG to edit')
            # use an external editing application, via the showboat_server
            if external
                $('.svg_include').on('click.edit_include', ->
                    # launch an external editor via GET call to showboat_server
                    $.get('edit/' + $(this).attr('src'))
                    # gray out the screen to indicate the mode change
                    $('#veil').fadeIn('slow'))

            # use svg-edit in-place to edit
            else
                $('.svg_include',current).css('background', 'rgb(0.5,0.5,0.5)')
                $('.svg_include',current).on('click.edit_include', ->
                    p.inplaceEdit($(this)))
        else

            if external
                # remove the veil
                $('#veil').fadeOut('slow')
            else
                # save the result
                if save
                    p.saveInplaceEdit(-> p.reloadAfterEdit())
                else
                    p.reloadAfterEdit()


    reloadAfterEdit: ->

        @edit_picker_enabled = false

        $('.svg_include').removeClass('svg_editor')

        # remove the clicking behavior on the include
        $('.svg_include').unbind('click.edit_include')
        # reload
        @loadIncludes()
        @showCurrent( @resetCurrent() )

        # undef the svg_canvas, if needed
        @setEditorSVGCanvas(undefined)
        @currently_editted_path = undefined

        $('#svg_editor_controls').hide()


    setEditorSVGCanvas: (@svg_canvas) ->
    getEditorSVGCanvas: -> return @svg_canvas

    inplaceEdit: (include_div) ->

        svg_path = include_div.attr('src')
        @currently_editted_path = svg_path

        frame = $('<iframe src="scripts/svg-edit/svg-editor.html" width="100%" height="100%"></iframe>')

        p = this
        init_editor = ->
            # push the extracted svg to the editor
            svg_canvas = new embedded_svg_edit(frame.get(0))
            p.setEditorSVGCanvas(svg_canvas)
            # load up the svg content
            $.ajax(
                url: svg_path
                type: 'GET'
                dataType: 'text'
                timeout: 1000
                success: (xml) ->
                    svg_canvas.setSvgString(xml)
            )

        frame.load(init_editor)

        # replace the include div contents with the svg-edit editor
        include_div.empty()
        include_div.append(frame)
        include_div.addClass('svg_editor')

        # show the svg editor controls
        $('#svg_editor_controls').fadeIn()

        # turn off the presentation controls
        $('#presentation_controls').hide()


    saveInplaceEdit: (cb) ->
        @transientMessage('Saving...')

        p = this
        svg_canvas = @getEditorSVGCanvas()

        if svg_canvas is undefined
            alert('No SVG Canvas!')
            cb() if cb
            return

        svg_canvas.getSvgString()( (svg_str, err) ->
            if err
                alert(err)

            # post the result to the showboat_server
            $.ajax(
                type: 'POST'
                dataType: 'text'
                timeout: 1000
                url: 'save/' + p.currently_editted_path
                data: { data: svg_str }
                success: -> p.transientMessage('File saved.'); cb()
                error: (XHR,stat,msg)-> alert('Unable to save SVG: ' + msg)
                )
        )

    # Experimental, not implemented fully (didn't work right when I tried...)
    generateThumbnailForSlide: (i, target_parent) ->
        slide_div = $('.slide').get(i)

        preload = html2canvas.Preload(slide_div,
            complete: (images) ->
                queue = html2canvas.Parse(slide_div, images)
                canvas =  $(html2canvas.Renderer(queue))
                canvas.css('width','100%')
                canvas.css('height', '10%')
                target_parent.append(canvas)
            )

    buildTOC: ->

        toc_links = []
        $('.slide').each (i) ->
            id = i # $(this).attr('id')
            title = $('.title', this).text()
            if !title
                title = 'Slide ' + id
            $(this).append("<a name='#{id}'></a>")

            toc_links.push([id, title])

        $('body').append('<div id="toc"></div>')

        anchors = [$("<a href=\"javascript:void(0);\">#{t[1]}</a>") for t in toc_links]
        p = this
        $.each(anchors[0], (i,a) ->
            a.click((evt) ->
                p.setCurrent(i)
                p.showCurrent()
                p.toggleTOC()
                ))

        ol = $('<ol></ol>')
        p = this
        $.each(anchors[0], (i,a) ->
            li = $('<li></li>')

            # generate a faux-thumbnail
            if use_html2canvas
                thumb_div = $('<div width="100%" height="100%"/>')
                li.append(thumb_div)
                p.generateThumbnailForSlide(i, thumb_div)
                a.append(thumb_div)
            else
                a.append("<img src=\"thumbnails/slide_#{i+1}-thumb.png\" width=\"200\" height=\"150\" alt=\"\"/>")

            li.append(a)

            ol.append(li))
        $('#toc').append(ol)


    toggleTOC: ->
        $('#toc').toggle()

    checkURLBarLocation: ->
        if (result = window.location.hash.match(/#([0-9]+)/))
            slide_number = result[result.length - 1] - 1
            if !isNaN(slide_number)  && slide_number != @current_slide_idx
                console.log("setting slide to #{slide_number}")
                @current_slide_idx = slide_number
                @showCurrent()

    checkURLBarPeriodically: (interval) ->
        p = this
        check = ->
            p.checkURLBarLocation()
            setTimeout(check, interval)
        setTimeout(check, interval)

$ ->
    p = new Presentation()
