from util import *
from server import *
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
            build_thumbnails=True):
        
    if overwrite_output:
        # remove the existing output dir
        try:
            shutil.rmtree(out_path)
        except:
            pass
    
    os.mkdir(out_path)
    
    
    global_styles_path = resource_filename(__name__, 'payload/styles')
    global_scripts_path = resource_filename(__name__, 'payload/scripts')
    local_styles_path = os.path.join(src_path, 'styles')
    local_scripts_path = os.path.join(src_path, 'scripts')
    
    # rsync in the supporting file directories
    rsync(global_styles_path, out_path)
    rsync(global_scripts_path, out_path)
    rsync(local_styles_path, out_path)
    rsync(local_scripts_path, out_path)
    
    # compile the coffeescript
    coffeescript_compile(out_path)
    
    assets_path = os.path.abspath(config['assets_path'])
    
    # symlink or copy in the global assets, if they exist
    if os.path.exists(assets_path):
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
