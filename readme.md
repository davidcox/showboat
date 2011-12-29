# Showboat
## A workflow for making full-featured slide presentations in HTML5/svg/flash/sky's-the-limit

Showboat is an experimental project I've started out of frustration with existing tools for making slide presentations.  Many such tools exist, but over the years none has really felt right, or let me do what I want to do.  In particular, my presentations usually include lots of video, animation, and progressively revealed figures (and not a lot of text or bullets).  Over the years, I've gone from Powerpoint, to creating entire presentations in Flash, to Apple's Keynote.  While Keynote was once great and used to serve me reasonably well, the software has been getting worse and worse over the years.  First, they quietly disabled Flash support (via an unrelated 10.6 OS update... right before I was scheduled to give a talk which included tons of embedded Flash... ugh).  Then, they made the keynote bundle an opaque binary monstrosity.  Then they farked up the handling of imported images such that every cut-and-pasted image was stored internally as uncompressed TIFF content, making my presentations weigh in at over a GB (and with a "reduce file size option" that doesn't actually work).

At some point, my frustration boiled over, and tools like *Showoff*, *slidy*, and *S5* came to my attention.  Doing presentation in a web browser seems like a terribly sensible thing to do.  *slidy* and *S5* basically provide some js and css, and have you write HTML, while *Showoff* uses markdown + a little bit of extra syntax.  While these tools are really cool, they mostly are aimed at the headers-and-bullets crowd (or at least, in the case of *Showoff*, the crowd whose presentations are dominated by code examples), and didn't really do what I needed to: lots of dynamic diagrams and figures and data.  So I started building my own tool.  I'm calling it "Showboat", in homage to *Showoff*.  I should note that I am stealing/borrowing ideas liberally from both *slidy* and *Showoff*, so props all around.

## What is it?

Basically, Showboat consists of three parts:

1. a python script for starting, compiling, and launching presentations
2. a client-side script (written in Coffeescript) for handling runtime presentation logic
3. a presentation markup structure, using the *Jade* templating language, which removes the need to write a lot of needlessly dense HTML.

Between 2 & 3, there is built a modest little DSL-ish thingy, whereby "builds" of slide components (e.g. fade-in, fade-out, appear, etc., analogous to the builds and actions in Keynote) can be specified.

The basic idea is that one can write a simple, clean skeleton in jade:

    .slide
        img#d1(src="diagram1.png")
        img#d2(src="diagram2.png")

        .build fade_in(#d1)
        .build
            | fade_out(#d1)
            | fade_in(#d2)

The above example starts as a blank screen, and then on user key presses shows the first diagram, then the second, while fading out the first.  It is also easy to import SVG content, with labeled elements and build-in or out those elements.  The hope is to construct all of the infrastructure to do all of the non-tacky builds in Keynote (most of which are, IMHO, *very* tacky).

Also, simple slidy-style bullety things like:
    
    .slide
        h1 My presentation
        h2 it has lots of text
        
        ul.incremental
            li and some bullets
            li ... and some more bullets
            li ... and some more

also are possible.

## Where is it going?

I'm *really* excited about using this a platform to bring in fancy data visualization into my talks, via the amazing d3.js project.  

There's a lot of interesting audience-interaction potential as well; this seems to be what @schacon is most interested in with *Showoff*, though, being a scientist and not a "web person", it is much less common to be giving a talk to audience where everyone has their laptops out.  I may have to start teaching soon, however, so I am interested in the possibilities for student interaction with a live presentation.  Making a talk be a web-thingy really opens up an almost limitless canvas of possibility.

## Disclaimer

I'm still putting this together, so don't expect any of this to be ready yet.  I'm writing this readme on the off-hand chance that someone stumbles across this on the web.

Also, please note, I'm not a "web person" (at least, not for many years), so this is my first foray back into some of these web technologies.  I'm muddling along a bit in Coffeescript and CSS, so if you're interested in this project and have any suggestions or want to help, please drop me a line at davidcox@me.com.


