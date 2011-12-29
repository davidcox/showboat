import os
import re
from pkg_resources import resource_filename, resource_string
import simplejson as json
import shlex
import shutil
import subprocess
from mako.template import Template

top_level_module_name = __name__.split('.')[0]

# Configuration details
def default_config():
    return json.loads(resource_string(top_level_module_name, 
                                      'config/default.json'))

def load_config():
    # check for .showboat.json in ~/
    
    # shortcut
    return default_config()

config = load_config()

# work around bizarro pkg_resources / MACOSX_DEPLOYMENT_TARGET insanity
def syscall(cmd):
    os.unsetenv('MACOSX_DEPLOYMENT_TARGET')
    return subprocess.call(shlex.split(str(cmd)))


def rsync(src, dst):
    cmd = Template(config['sync_cmd']).render(src_path=src, dst_path=dst)
    syscall(cmd)

def jade_compile(src_path, dst_path):
    #os.system('jade %s --out %s' % (src_path, dst_path))
    index_path = resource_filename(top_level_module_name, 'payload/index.jade')
    
    shutil.copy(index_path, dst_path)

    for f in os.listdir(src_path):
        try:
            if f.split('.')[-1] == 'jade':
                shutil.copy(os.path.abspath(f), dst_path)
        except:
            pass
    jade_cmd = Template(config['html_compile_cmd']).render(dst_path=dst_path)
    syscall(jade_cmd)


def coffeescript_compile(src_path):
    script_path = os.path.join(src_path, 'scripts')
    cmd = Template(config['script_compile_cmd']).render(script_path=script_path)
    syscall(cmd)
    
def count_n_slides(out_path):
    with open(os.path.join(out_path, 'index.html'), 'r') as f:
        html = '\n'.join(f.readlines())
        n = len(re.findall(r'class\s*\=\s*\"slide\"', html))
        return n


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
        cmd = Template(config['thumbnail_cmd']).render(width=200,
                                                       height=150,
                                                       dst_path=tn_path,
                                                       slide_number = n+1,
                                                       slide_url = slide_url)
        syscall(cmd)

    http_server.kill()



