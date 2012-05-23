# Showboat: a tool for hackers who want complete control over their slide presentations

## Why?

Showboat is an experimental project I've started out of frustration with existing tools for making slide presentations.  Many tools already exist in this space, but over the years none has really felt right, or fully let me do what I want to do.  In particular, the presentations I give (I'm an academic scientist) tend to include lots of video, animation, and progressively revealed figures... and not a lot of text or bullet points.

Over the years, I've gone from Powerpoint, to creating entire presentations in Flash, to Apple's Keynote.  While Keynote was once great and used to serve me reasonably well, the software has been getting worse and worse over the years.  First, they quietly disabled Flash support (via an unrelated 10.6 OS update... right before I was scheduled to give a talk which included tons of embedded Flash... ugh).  Then, they made the keynote bundle an opaque binary monstrosity.  Then they screwed up the handling of imported images such that every cut-and-pasted image was stored internally as uncompressed TIFF content, making my presentations weigh in at over a GB (and with a "reduce file size option" that doesn't actually work).  It's really astounding to me how out of control Keynote has gotten.

At some point, my frustration boiled over, and tools like [Showoff](http://github.com/schacon/showoff), [slidy](http://www.w3.org/Talks/Tools/Slidy2/), and [S5](http://meyerweb.com/eric/tools/s5/) came to my attention.  Doing presentation in a web browser seems like a terribly sensible thing to do.  slidy and S5 basically provide some js and css, and have you write HTML, while Showoff uses markdown + a little bit of extra syntax.  While these tools are really cool and inspiring, they seem mostly aimed at the "headers-and-bullets" crowd (or at least, in the case of Showoff, the crowd whose presentations are dominated by code examples), and didn't really do what I needed to: lots of dynamic diagrams and figures and data.  So I started building my own tool.  I'm calling it "Showboat", in homage to Showoff.  I should note that I am stealing/borrowing ideas/code/etc. liberally from both slidy and Showoff, so props all around.

## What is it?

Basically, Showboat consists of three parts:

1. Python scripts for starting, compiling, launching and serving presentations from the command line
2. a client-side script (written in Coffeescript) for handling runtime presentation logic.  Basic support for inline editing of SVGs is also supported (see below)
3. A set of presentation markup conventions, using the [Jade](http://jade-lang.com/) template language

As part of #3, there is something that has the flavor of a modest a little domain specific language, whereby "builds" of slide components (e.g. fade-in, fade-out, appear, etc., analogous to the builds and actions in Keynote) can be specified in a relatively minimalist way

The basic idea is that one can write a simple, clean skeleton in Jade and achieve relatively complex behavior:

    slide
        img#d1(src="diagram1.png")
        img#d2(src="diagram2.png")

        build fade_in(#d1)
        build
            | fade_out(#d1)
            | fade_in(#d2)

The above example starts as a blank screen, and then on user key presses shows the first diagram, then the second, while fading out the first.  It is also easy to import SVG content, with labeled elements and build-in or -out those elements.  The hope is to construct all of the infrastructure to do all of the builds in Keynote (or at least, the non-tacky ones).

Also, simple slidy-style bullety things like:
    
    slide
        h1 My presentation
        h2 it has lots of text
        
        ul.incremental
            li and some bullets
            li ... and some more bullets
            li ... and some more

also are possible.  Where [Showoff](http://github.com/schacon/showoff) makes markup even leaner using markdown, in **Showboat**, I think that the additional level of control offered by CSS classes and ids was worth the extra few characters.  Adding animations / builds etc. to Showoff, for instance, probably would require additional ad hoc syntax on top of what has already been added to support slides (e.g. `!SLIDE` etc.).  By using Jade, Showboat gives you full control to specify anything that can be done in HTML5, which is basically just about anything you'd ever want to do.

## Example

A quicky, not-intended-to-be-particularly-coherent example slide presentation can be found at http://github.com/davidcox/showboat-example.  A live version can be found at http://davidcox.github.com/showboat-example.  It's just a static page, so none of the stuff that depends on a server will work (e.g. saving SVG inline editing).  It should give you a flavor of how I'm imagining using this things, though. 

## SVG Support, In-line editing

After wrestling around with HTML/CSS for a while, I discovered that I sometimes really have to have complete control over *exactly* where elements appear on the screen.  Slide presentations are fundamentally visual things, so getting things *just right* is sometimes more involved than letting stuff flow on a page.

HTML was designed for displaying long flowing page layouts, and while it is possible to exert exact x/y control, this is a job better suited to the SVG format.  Showboat supports inclusion and "building" of SVG content, and it also allows for in-line, in browser SVG editing, via the excellent [svg-edit project](http://code.google.com/p/svg-edit/).  Document saving is supported by the `showboat serve` command, which provides the client-side scripts with a lifeline to your local filesystem via a locally running server.

## Dependencies

Showboat needs the following external parts to work:

* [Jade](http://jade-lang.com): for minimal markup. `npm install -g jade`
* [Coffeescript](http://coffeescript.org): for the main script (I found this much preferable to raw javascript) `npm install -g coffee-script`
* OS-X: [webkit2png](http://www.paulhammond.org/webkit2png/): for making thumbnails (optional; probably other ways to get this done on other platforms)
* Linux: (https://github.com/AdamN/python-webkit2png/): for making thumbnails, see calling convention in linux.config instead of default.config.
* [cherrypy](http://cherrypy.org/): as if this project needed another internal web framework `pip install --user cherrypy`
* [bottle](http://bottlepy.org/docs/dev/): another web framework for good measure `pip install --user bottle`


All of the above are `brew install`-able on Mac, though using a different tool (e.g. for making the thumbnails) is just a matter of changing the helper command (see *Helpers*, below).

I also like launching presentations in [Plainview](http://barbariangroup.com/software/plainview), though Google Chrome also has a nice "presentation mode" that does a similar job.

## Installation


    git clone https://github.com/davidcox/showboat
    cd showboat
    pip install .  # if you have pip installed (recommended)
    python setup.py install # if you don't

## Usage

    showboat start --src_path=my_slideshow  # start a new presentation in my_slideshow
    cd my_slideshow
    showboat compile # compile the files and put them into output/
    showboat view  # open a browser and view
    showboat present # open the presentation in an alternate, fullscreen browser
    showboat serve # launch a local server to serve the presentation

## Key shortcuts (within presentation)

* **arrows**: navigate slides
* **t**: display table of contents / slide sorter
* **c**: show slide control palette
* **e**: enter in-line edit mode (to edit SVGs in-line)
* **r**: reset slide builds

## Helpers

Showboat looks for a json-formatted file called `.showboat` in `~/` to define shell commands for all of the external actions that need to be performed outside of the browser.  This includes things like browser launch commands, external editors, webservers, etc.  The hope is that users can customize these helpers however they like to make the workflow as smooth as possible.

Here's an example of the one I'm using currently:

```
{
    "assets_path": "~/Documents/talks/assets",
    
    "thumbnail_cmd": "webkit2png --width=${width} --height=${height} --dir=${dst_path} -T --delay=0.5 -o slide_${slide_number} ${slide_url}",
    "html_compile_cmd": "jade ${dst_path}",
    "script_compile_cmd": "coffee -c ${script_path}",
    "styles_compile_cmd": "",
    "sync_cmd": "rsync -a ${src_path} ${dst_path}",
    "view_url_cmd": "open \"${url}\" ",
    "alt_view_url_cmd": "\"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome\" --allow-file-access-from-files \"${url}\"",
    "present_url_cmd": "open -a Plainview \"${url}\" ",
    "http_server_cmd": "showboat_server --host=${host} --port=${port} ${root_path}",
    "edit_svg_cmd": "open -a iDraw ${containing_path}/${file_name_noext}.idraw"
}
```

## Where is it going?

I'm *really* excited about using this a platform to bring elegant data visualization into my talks, via the amazing [d3.js](http://mbostock.github.com/d3/) project.  I used to have much more data-interactivity in my talks back when I was slaving away making slides in Flash, but I think that d3 represents a quantum leap forward in interactive data visualization possibilities.

There's also a lot of interesting audience-interaction potential; this seems to be what @schacon is most interested in with *[Showoff](http://github.com/schacon/showoff)*, though, being a scientist and not a web person, it is much less common for me to be giving a talk to an audience where everyone has their laptop out.  (I may have to start teaching soon, however, so I am interested in the possibilities for student interaction with a live presentation).  Nonetheless, making a talk be a web-thingy really opens up an almost limitless possibilities.

## Wishlist

Here are some features that I'm interested in adding:

* add in some proper themes so that the non-SVG slides look reasonable
* slide preloading, esp. when working over the internet
* upload to Dropbox / upload to Github support
* add in the cool typewriter code animation stuff from Showoff
* ability to add/rearrange slides from within the browser
* ... any many more...

## Disclaimer

I'm still putting this together, so don't expect any of this to be fully ready yet.  I'm writing this read-me on the off-hand chance that someone stumbles across this on the web and wonders what it is.

Also, please note, I'm not someone who lives and breathes web technologies (at least, not for many years), and this is my first foray back into some of these technologies.  I'm muddling along a bit in Coffeescript and CSS, so if you're interested in this project and have any suggestions or want to help, please drop me a line at davidcox@me.com.


