import os
import re
from pkg_resources import resource_filename, resource_string
import simplejson as json
import shlex
import shutil
import subprocess
from mako.template import Template
import urllib
import time

top_level_module_name = __name__.split('.')[0]

# Configuration details
def default_config():
    return json.loads(resource_string(top_level_module_name, 
                                      'config/default.json'))

def load_config():
    # check for .showboat.json in ~/
    user_config_filename = os.path.expanduser('~/.showboat')
    if os.path.exists(user_config_filename):
        with open(user_config_filename, 'r') as f:
            return json.load(f)
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

def serve_http(root_path, host='localhost', port=8080, timeout=2.0):
    cmd = Template(config['http_server_cmd']).render(root_path=root_path,
                                                     host=host,
                                                     port=port)
    proc = subprocess.Popen(shlex.split(str(cmd)))
    
    # check to see if the server is up yet
    connected = False
    tic = time.time()


    while not connected and ((time.time() - tic) < timeout):
        try:
            urllib.urlopen("http://localhost:8080/index.html")
            connected = True
        except IOError:
            pass

    if not connected:
        raise IOError('Unable to connect to internally-launched HTTP server')
        
    return proc

def build_slide_thumbnails(dst_path, n_slides):

    http_server = serve_http(dst_path)
    
    tn_path = os.path.join(dst_path, 'thumbnails')
    os.mkdir(tn_path)


    for n in range(0, n_slides):
        slide_url = "http://localhost:8080/index.html#%d" % (n+1)
        cmd = Template(config['thumbnail_cmd']).render(width=200,
                                                       height=150,
                                                       dst_path=tn_path,
                                                       slide_number = n+1,
                                                       slide_url = slide_url)
        syscall(cmd)

    http_server.kill()

def view_url(url):
    # check if it is a file
    if os.path.exists(url):
        url = "file://" + url
    cmd = Template(config['view_url_cmd']).render(url=url)
    syscall(cmd)

def present_url(url):
    # check if it is a file
    if os.path.exists(url):
        url = "file://" + url
    cmd = Template(config['present_url_cmd']).render(url=url)
    syscall(cmd)

