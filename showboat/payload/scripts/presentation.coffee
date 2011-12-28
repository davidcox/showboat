n_slides_global = 0

# -----------------------------------------------------------------------
# Slides and Builds
# -----------------------------------------------------------------------


# a dictionary of object for executing builds
# should be able to add new ones at any point
build_types =
    appear: (target) ->
        do: -> $(target).show()
        undo: -> $(target).hide()
    
    disappear: (target) ->
        do: -> $(target).hide()
        undo: -> $(target).show()
    
    fade_in: (target, duration='slow') ->
        do: -> $(target).animate({'opacity': 1.0}, duration)
        undo: -> $(target).animate({'opacity': 0.0}, 'fast')
    
    fade_out: (target, duration='slow') ->
        do: -> $(target).stop().animate({'opacity': 0.0}, duration)
        undo: -> $(target).stop().animate({'opacity': 1.0}, 'fast')
        
    opacity: (target, op, duration='slow') ->
        @last_opacity
        do: ->
            @last_opacity = $(target).css('opacity')
            lo = @last_opacity
            $(target).stop().animate({'opacity': op}, duration)
        undo: ->
            # restore a previously stored opacity, if one is available 
            if @last_opacity != undefined
                lo = @last_opacity
                $(target).stop().animate({'opacity': lo}, 'fast')
            else
                # if last_opacity is undefined, check if one is specified
                if $(target).css('opacity')
                    @last_opacity = $(target).css('opacity')
    
    play: (target) ->
        do: -> try $(target).get(0).play()
        undo: -> try $(target).get(0).pause().rewind()

    composite: (subbuilds) ->
        do: -> b.do() for b in subbuilds
        undo: -> b.undo() for b in subbuilds
        
# a slide object
class Slide
    @build_list
    @current_build

    constructor: (@slide_div) ->
        @build_list = []
        @current_build = 0
        
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
        @reset()
        
        return this

    reset: ->
        build.undo() for build in @build_list.slice(0).reverse()
    
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
    
    show: ->
        $(@slide_div).show()
        
        # give focus to any embeds, in case they need it (worth a try...)
        $('embed, video', @slide_div).focus()
        $('embed, video', @slide_div).trigger('click')
    
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
        
        # load the slides
        sl = @slides
        $('.slide').each (i) -> 
            s = new Slide($(this))
            sl.push(s)
            
        # bind appropriate handlers
        document.onkeydown = (evt) => @keyDown(evt)
        
        # build the table of contents
        @buildTOC()
        
        # setup up a recurring check to sync the browser location field with
        # the slideshow
        @checkURLBarPeriodically(100)
        
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
    
    showCurrent: ->
        s.hide() for s in @slides
        @slides[@current_slide_idx].show()
        location.hash = @current_slide_idx + 1
        

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
            when 37, 33, 38 then @revert()
            # right arrow, page down, down arrow
            when 39, 34, 30 then @advance()
            when 84, 67 then @toggleTOC()
    
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
            a.append("<img src=\"thumbnails/slide_#{i+1}-thumb.png\" width=\"200\" height=\"150\"/>")
            
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
