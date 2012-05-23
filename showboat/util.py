#!/usr/bin/python
# -*- coding: utf-8 -*-
import os
import re
import sys
from pkg_resources import resource_filename
import shlex
import subprocess
from mako.template import Template
import urllib
import time
from contextlib import contextmanager
from ConfigParser import SafeConfigParser

showboat_keywords = ('slide', 'build', 'notes', 'set', 'svg_include')
top_level_module_name = __name__.split('.')[0]


# Configuration details

def read_config(cfg_path):
    cp = SafeConfigParser()
    cp.read(cfg_path)

    d = {}
    for section in cp.sections():
        d.update(dict(cp.items(section)))
    return d


def default_config():
    return read_config(resource_filename(top_level_module_name,
                       'config/default.config'))


def load_config():
    # check for .plotsk in ~/
    user_config_filename = os.path.expanduser('~/.showboat')
    if os.path.exists(user_config_filename):
        return read_config(user_config_filename)
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


def preprocess_jade(jade_str):
    # this function adds a '.' before the showboat keywords.
    # e.g. slide() -> .slide()
    # This makes jade produce e.g. slide-class div elements
    pattern = r'^(\s*)(%s)(\s|\(|\.|\#|$)'
    repl = r'\1.\2\3'
    if re.sub.__code__.co_argcount < 5:
        # flags param only introduced in Python 2.7, so no multiline sub()
        lines = jade_str.split('\n')
        for kw in showboat_keywords:
            lines = map(lambda l: re.sub(pattern % kw, repl, l), lines)
        jade_str = '\n'.join(lines)
    else:
        for kw in showboat_keywords:
            jade_str = re.sub(pattern % kw, repl, jade_str, flags=re.M)
    return jade_str


def jade_compile(src_path, dst_path):

    resource_path = resource_filename(top_level_module_name, 'payload/')
    print 'resource path: %s' % os.listdir(resource_path)

    src_files = [os.path.join(src_path, f) for f in os.listdir(src_path)]
    resource_files = [os.path.join(resource_path, f) for f in
                      os.listdir(resource_path)]

    for fp in resource_files + src_files:
        try:
            if fp.split('.')[-1] == 'jade':
                full_path = os.path.abspath(os.path.expanduser(fp))
                fn = os.path.split(full_path)[-1]
                with open(full_path, 'r') as f:
                    f_str = ''.join(f.readlines())
                    preproc = preprocess_jade(f_str)
                    with open(os.path.join(dst_path, fn), 'w') as out_f:
                        out_f.write(preproc)
        except Exception, e:
                # shutil.copy(, dst_path)
            print e
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


@contextmanager
def serve_http(root_path='.', host='localhost', port=8080, timeout=5.0,
               src_path='<undefined>'):

    cmd = Template(config['http_server_cmd']).render(root_path=root_path,
            src_path=src_path, host=host, port=port)
    proc = subprocess.Popen(shlex.split(str(cmd)))

    # check to see if the server is up yet
    connected = False
    tic = time.time()

    while not connected and time.time() - tic < timeout:
        try:
            urllib.urlopen('http://%s:%s/index.html' % (host, port))
            connected = True
        except IOError:
            pass

    if not connected:
        raise IOError('Unable to connect to internally-launched HTTP server')

    yield proc

    proc.kill()


def build_slide_thumbnails(dst_path, n_slides, async=True):

    print 'Building thumbnails... '
    tic = time.time()

    with serve_http(dst_path):

        tn_path = os.path.join(dst_path, 'thumbnails')
        os.mkdir(tn_path)

        def generate_one_thumbnail(n):
            slide_url = 'http://localhost:8080/index.html#%d' % (n + 1)
            cmd = Template(config['thumbnail_cmd']).render(width=200,
                    height=150, dst_path=tn_path, slide_number=n + 1,
                    slide_url=slide_url)
            syscall(cmd)

        if async:
            from threading import Thread
            from functools import partial

            batch_size = 4

            for b in range(0, n_slides / batch_size + 1):
                low = b * batch_size
                high = (b + 1) * batch_size - 1

                if low > n_slides:
                    break
                if high > n_slides:
                    high = n_slides

                threads = [Thread(target=partial(generate_one_thumbnail, n))
                           for n in range(low, high)]
                for t in threads:
                    t.start()
                for t in threads:
                    t.join()
        else:
            map(generate_one_thumbnail, range(0, n_slides))

    print 'Done building thumbnails (took %f seconds).' % (time.time() - tic)


def view_url(url, use_alt=False):

    if use_alt:
        app_key = 'alt_view_url_cmd'
    else:
        app_key = 'view_url_cmd'

    # check if it is a file
    if os.path.exists(url):
        url = 'file://' + url
    cmd = Template(config[app_key]).render(url=url)
    print cmd
    try:
        syscall(cmd)
    except Exception, e:
        print >> sys.stderr, "Failed to launch browser", e


def present_url(url):
    # check if it is a file
    if os.path.exists(url):
        url = 'file://' + url
    cmd = Template(config['present_url_cmd']).render(url=url)
    syscall(cmd)


def launch_external_svg_editor(path):
    file_path = os.path.join(config['assets_path'], path)
    file_path = os.path.abspath(os.path.expanduser(file_path))

    split_path = os.path.split(file_path)
    file_name = split_path[-1]
    file_name_noext = '.'.join(file_name.split('.')[0:-1])
    file_ext = file_name.split('.')[-1]
    containing_path = os.path.join(*split_path[0:-1])

    cmd_template = config['edit_svg_cmd']
    cmd = Template(cmd_template).render(file_path=file_path,
                                        file_name=file_name,
                                        file_name_noext=file_name_noext,
                                        containing_path=containing_path,
                                        file_ext=file_ext)
    syscall(cmd)
    return cmd


def save_svg_file(path, contents, viewbox_hack=True):

    file_path = os.path.join(config['assets_path'], path)
    file_path = os.path.abspath(os.path.expanduser(file_path))

    if viewbox_hack:
        import re
        # a quick hack to restore the viewbox, which svg-edit destroys
        with open(file_path, 'r') as f:
            old_content = '\n'.join(f.readlines())
            vbs = re.findall(r'viewBox\s*=\s*\"(.+?)\"', old_content)
            if len(vbs) == 1:
                vb = vbs[0]

                # hacky hack hack hack
                contents = re.sub('<svg', '<svg viewBox="%s"' % vb, contents)

    with open(file_path, 'w') as f:
        f.write(contents)
