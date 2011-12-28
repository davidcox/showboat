from util import *

def compile(src_path, out_path, copy_assets=False):
    out_path = os.path.join(out_path, 'output')
    
    # remove the output dir
    try:
        shutil.rmtree(out_path)
    except:
        pass
    
    os.mkdir(out_path)
    
    # compile the coffeescript
    coffeescript_compile(src_path)
    
    # rsync in the supporting file directories
    rsync('styles', out_path)
    rsync('scripts', out_path)
    
    # symlink or copy in the assets
    for item in os.listdir('assets'):
        if item == '.DS_Store':
            continue
        
        asset_src = os.path.join(os.path.abspath(src_path), 'assets', item)
        asset_dst = os.path.join(out_path, item)
        
        if copy_assets:
            shutil.copytree(asset_src, asset_dst)
        else:
            os.symlink(asset_src, asset_dst)
    
    # compile the jade
    jade_compile(src_path, out_path)
    
    # build thumbnail pngs for all of the slides
    # count the number of slides
    n_slides = count_n_slides(out_path)
    build_slide_thumbnails(out_path, n_slides)
    
def build_slide_thumbnails(dst_path, n_slides):
    
    # more syscall hackery
    http_cmd = 'mongoose -r %s' % dst_path
    http_server = subprocess.Popen(shlex.split(http_cmd))
    
    tn_path = os.path.join(dst_path, 'thumbnails')
    os.mkdir(tn_path)
    
    for n in range(0, n_slides):
        slide_url = " http://127.0.0.1:8080/index.html#%d" % (n+1)
        cmd = 'webkit2png --width=%d --height=%d --dir=%s -T -o slide_%d %s' % \
                (200, 150, tn_path, n+1, slide_url)
        os.system(cmd)
    
    http_server.kill()
