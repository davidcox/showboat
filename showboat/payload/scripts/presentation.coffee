n_slides_global = 0

# -----------------------------------------------------------------------
# Slides and Builds
# -----------------------------------------------------------------------

recursiveDoBuilds = (builds, cb) ->
    builds = builds.slice(0)
    if builds.length is 0
        cb() if cb
        return
    b = builds.shift()
    b.do(-> recursiveDoBuilds(builds, cb))

recursiveUndoBuilds = (builds, cb, n=undefined) ->
    if n is undefined
        n = builds.length
    
    alert(n)
        
    if n == 0
        cb() if cb
        return
    b = builds[n-1]
    n_prime = n-1
    b.undo(-> arguments.callee(builds, cb, n_prime))


# a dictionary of object for executing builds
# should be able to add new ones at any point
build_types =
    appear: (target) ->
        do: (cb) -> $(target).show(0, cb)
        undo: (cb) -> $(target).hide(0, cb)
    
    disappear: (target) ->
        do: (cb) -> $(target).hide(0, cb)
        undo: (cb) -> $(target).show(0, cb)
    
    fade_in: (target, duration='slow') ->
        do: (cb) -> $(target).animate({'opacity': 1.0}, duration, cb)
        undo: (cb) -> $(target).animate({'opacity': 0.0}, 0, cb)
    # fade_in: (target, duration=500) ->
    #     do: -> d3.select(target).style('display', 'yes')
    #                             .transition()
    #                             .duration(duration)
    #                             .style('opacity', 1.0)
    #     undo: -> d3.select(target).style('display', 'yes')
    #                               .style('opacity', 0.0)
                                  

    
    fade_out: (target, duration='slow') ->
        do: (cb) -> $(target).animate({'opacity': 0.0}, duration, cb)
        undo: (cb) -> $(target).animate({'opacity': 1.0}, 0, cb)
        
    # fade_out: (target, duration=500) ->
    #     do: -> d3.select(target).style('display', 'yes')
    #                             .transition()
    #                             .duration(duration)
    #                             .style('opacity', 0.0)
    #                             
    #     undo: -> d3.select(target).style('display', 'yes')
    #                               .style('opacity', 1.0)
        
    opacity: (target, op, duration='slow') ->
        @last_opacity
        do: (cb) ->
            @last_opacity = $(target).css('opacity')
            lo = @last_opacity
            $(target).animate({'opacity': op}, duration, cb)
        undo: (cb) ->
            # restore a previously stored opacity, if one is available 
            if @last_opacity != undefined
                lo = @last_opacity
                $(target).animate({'opacity': lo}, 0, cb)
            else
                # if last_opacity is undefined, check if one is specified
                if $(target).css('opacity')
                    @last_opacity = $(target).css('opacity')
                cb() if cb
    
    play: (target) ->
        do: (cb) -> 
            try $(target).get(0).play()
            cb() if cb
        undo: (cb) -> 
            try $(target).get(0).pause().rewind()
            cb() if cb

    composite: (subbuilds) ->
        do: (cb) -> 
            b.do() for b in subbuilds
            cb() if cb
        undo: (cb) -> 
            b.undo() for b in subbuilds
            cb() if cb
# a slide object
class Slide
    @build_list
    @current_build

    constructor: (@slide_div) ->
        @build_list = []
        @current_build = 0
        @first_show = true
        
        if !slide_div.attr('id')
            unique_id = 'slide_' + n_slides_global++
            slide_div.attr('id', unique_id)
                        
        # Parse and add the builds
        bl = @build_list
        $('.build, .incremental ul li, .incremental > *:not(ul)', @slide_div).each (i) ->
            b = $(this)
            
            # if it's a build directive, parse it appropriately
            if b.hasClass('build')
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

                    subbuilds.push(build_types[type](target, args...))
                
                if subbuilds.length == 0
                    alert('blah!!')
                else if subbuilds.length == 1
                    bl.push(subbuilds[0])
                else
                    bl.push(build_types['composite'](subbuilds.slice(0).reverse()))
                
            # for "ordinary" incremental display
            else
                bl.push(build_types['appear'](b))
            
            b.attr('id', 'build_' + bl.length)

        # set the slide content to an appropriate initial state
        #build.do() for build in @build_list
        @reset()
        
        return this

    reset: ->
        # if @build_list.length > 0
        #   recursiveUndoBuilds(@build_list)
        build.undo() for build in @build_list.slice(0).reverse()
        @current_build = 0
        
    fullReset: ->
        @first_show = true
    
    hasBuilds: -> !@build_list.empty

    doNextBuild: ->
        if @current_build >= @build_list.length
            return false
        else
            @build_list[@current_build].do()
            @current_build += 1
            return true
    
    undoPreviousBuild: ->

        @current_build -= 1
        
        if @current_build < 0
            @current_build = 0
            return false
        else
            @build_list[@current_build].undo()    
            return true
    
    show: (cb) ->
        if @first_show
            @reset()
            @first_show = false
        $(@slide_div).show(0, cb)
        
    hide: ->
        $(@slide_div).hide()

# -----------------------------------------------------------------------
# Presentation Logic
# -----------------------------------------------------------------------
  
# Main presentation object
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
        
        # preprocess the DOM
        @loadIncludes()
        
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
        
        # bind appropriate handlers
        document.onkeydown = (evt) => @keyDown(evt)
        
        # build the table of contents
        @buildTOC()
        
        # setup up a recurring check to sync the browser location field with
        # the slideshow
        @checkURLBarPeriodically(100)
        
        # experimental: attach edit handlers to svgs
        # $('.svg_container').onchange = (evt) -> $.ajax.get(this.attr('src'))
        
        # a queue to ensure that user commands happen in some kind of sane 
        # sequence (actually, it's an empty element)
        @actions = $({})
    
    loadIncludes: ->
        p = this
        
        # change the faux include commands to properly included dom
        $('.include').each (i) ->
            div = $(this)
            div.empty()
            path = div.attr('src')
            console.log("Here: #{path}, #{div}")
            if div
                d3.xml(path, (xml) -> 
                    console.log("div: #{div}, xml: #{xml.documentElement}")
                    div.get(0).appendChild(xml.documentElement)
                    p.showCurrent(-> p.resetCurrent())
                    )
        
        
        $('g').each (i) ->
            op = $(this).css('opacity')
            console.log("opacity = #{op}")
            if $(this).css('opacity') == undefined
                $(this).css('opacity', 1.0)
                
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

    # build out the next increment of the current slide
    advanceBuild: ->
        @slides[@current_slide_idx].doNextBuild()

    # un-build the previous increment of the current slide
    revertBuild: ->
        @slides[@current_slide_idx].undoPreviousBuild()

    keyDown: (evt) ->
        key = evt.keyCode
        if key >= 48 and key <= 57 # 0-9
            alert('number key!')
            
        switch key
            # shift
            when 16 then @shiftKeyActive = true
            # space
            when 32 
                if @shiftKeyActive 
                    @advance() 
                else 
                    @revert()
            # left arrow, page up, up arrow
            when 37, 33, 38 then @revertQueued()
            # right arrow, page down, down arrow
            when 39, 34, 30 then @advanceQueued()
            when 84, 67 then @toggleTOC()  # c
            when 82 then @resetCurrent()   # r
            when 80 then @toggleControls() # p
    
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
        #edit_btn.button()
        edit_btn.button({icons: {primary: 'ui-icon-pencil'}, text: false})
        edit_btn.click -> p.editMode(edit_btn.attr('checked') == 'checked')
        
        hover_on = -> $(this).addClass('ui-state-hover')
        hover_off = -> $(this).removeClass('ui-state-hover')
        $('#presentation_controls button').hover(hover_on, hover_off)
        $('#presentation_controls input').hover(hover_on, hover_off)
        
        $('#presentation_controls').draggable()
        
        $('#presentation_controls').hide()
       
    toggleControls: ->
        $('#presentation_controls').toggle()
        
    
    editMode: (@edit_enabled) ->
        p = this
        
        if @edit_enabled
            $('.include').on('click.edit_include', ->
                $.get('edit/' + $(this).attr('src')))
        else
            $('.include').unbind('click.edit_include')
            @loadIncludes()
            @showCurrent( p.resetCurrent() )
            
            
    
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
            #p.generateThumbnailForSlide(i, li)
            a.append("<img src=\"thumbnails/slide_#{i+1}-thumb.png\" width=\"200\" height=\"150\" alt=\"\"/>")
            
            li.append(a)
            
            ol.append(li))
        $('#toc').append(ol)
    
    
    toggleTOC: ->
        $('#toc').fadeToggle()
        
    # TODO: handle URL bar stuff
    # see: set_location / check_location in slidy
    
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
