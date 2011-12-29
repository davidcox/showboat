import os
import re
from pkg_resources import resource_filename, resource_string
import simplejson as json
import shlex
import subprocess

top_level_module_name = __name__.split('.')[0]

# work around bizarro pkg_resources / MACOSX_DEPLOYMENT_TARGET insanity
def syscall(cmd):
    os.unsetenv('MACOSX_DEPLOYMENT_TARGET')
    return subprocess.call(shlex.split(cmd))

# Hacky system calls for now
def rsync(src, dst):
    syscall('rsync -a %s %s' % (src, dst))

def jade_compile(src_path, dst_path):
    #os.system('jade %s --out %s' % (src_path, dst_path))
    index_path = resource_filename(top_level_module_name, 'payload/index.jade')
    syscall('cp %s %s' % (index_path, dst_path))
    for f in os.listdir(src_path):
        try:
            if f.split('.')[-1] == 'jade':
                syscall('cp %s %s' % (os.path.abspath(f), dst_path))
        except:
            pass
    syscall('jade %s' % (dst_path))


def coffeescript_compile(src_path):
    cmd = 'coffee -c %s' % os.path.join(src_path, 'scripts')
    syscall(cmd)
    
def count_n_slides(out_path):
    with open(os.path.join(out_path, 'index.html'), 'r') as f:
        html = '\n'.join(f.readlines())
        n = len(re.findall(r'class\s*\=\s*\"slide\"', html))
        return n


# Configuration details
def default_config():
    return json.loads(resource_string(top_level_module_name, 
                                      'config/default.json'))

def load_config():
    # check for .showboat.json in ~/
    
    # shortcut
    return default_config()

