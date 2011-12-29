from util import *
from pkg_resources import resource_filename
import shutil

def deposit_skeleton(dst_path):
    if not os.path.exists(dst_path):
        os.mkdir(dst_path)
    
    jade_skel_path = resource_filename(__name__, 'payload/slides.jade')
    
    shutil.copy(jade_skel_path, dst_path)
    
    os.mkdir(os.path.join(dst_path, 'scripts'))
    os.mkdir(os.path.join(dst_path, 'styles'))

def compile(src_path, out_path, copy_assets=False, overwrite_output=True,
            build_thumbnails=True, config=default_config()):
    
    out_path = os.path.join(out_path, 'output')
    
    if overwrite_output:
        # remove the existing output dir
        try:
            shutil.rmtree(out_path)
        except:
            pass
    
    os.mkdir(out_path)
    
    
    styles_path = resource_filename(__name__, 'payload/styles')
    scripts_path = resource_filename(__name__, 'payload/scripts')
    
    # rsync in the supporting file directories
    rsync(styles_path, out_path)
    rsync(scripts_path, out_path)
    
    # compile the coffeescript
    coffeescript_compile(out_path)
    
    assets_path = os.path.abspath(config['assets_path'])
    
    # symlink or copy in the assets
    for item in os.listdir(assets_path):
        if item == '.DS_Store':
            continue
        
        asset_src = os.path.join(assets_path, item)
        asset_dst = os.path.join(out_path, item)
        
        if copy_assets:
            shutil.copytree(asset_src, asset_dst)
        else:
            os.symlink(asset_src, asset_dst)
    
    # compile the jade
    jade_compile(src_path, out_path)
    
    if build_thumbnails:
        # build thumbnail pngs for all of the slides
        # count the number of slides
        n_slides = count_n_slides(out_path)
        build_slide_thumbnails(out_path, n_slides)
    
def build_slide_thumbnails(dst_path, n_slides):
    
    import subprocess
    import shlex
    
    # more syscall hackery
    http_cmd = 'mongoose -r %s' % dst_path
    http_server = subprocess.Popen(shlex.split(http_cmd))
    
    tn_path = os.path.join(dst_path, 'thumbnails')
    os.mkdir(tn_path)
    
    for n in range(0, n_slides):
        slide_url = " http://127.0.0.1:8080/index.html#%d" % (n+1)
        cmd = '/usr/bin/env webkit2png --width=%d --height=%d --dir=%s -T -o slide_%d %s' % \
                (200, 150, tn_path, n+1, slide_url)
        syscall(cmd)
    
    http_server.kill()
