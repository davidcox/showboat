from multiprocessing import Process
import bottle
from showboat.util import *
from mako.template import Template
import os
from functools import partial


app = bottle.Bottle()

# TODO: routes for launching editing applications on the "server"-side
# wouldn't it be neat if there were an "edit" option that could locally launch 
# whatever external editor I like?
@app.route('/edit/<path:path>')
def edit(path):
    cmd = Template(config['editor_cmd']).render(path=path)
    syscall(cmd)


@app.route('/<path:path>')
def static_route(path):
    return bottle.static_file(path, app.showboat_content_path)


class Server (object):

    def __init__(self, path='.', ip='localhost', port=8080):
        self.root_path = path
        self.ip = ip
        self.port = port
        
        # this feels dirty, but decorating methods is a mess
        app.showboat_content_path = self.root_path
        
        self.server_process = Process(target=partial(Server.run_app, self))
        
    def start(self):
        if not self.server_process.is_alive():
            self.server_process.start()
    
    def run_app(self):
        bottle.run(app, host=self.ip, port=self.port)
        
    def stop(self):
        app.close()
        try:
            self.server_process.join(0.2)
        except:
            print("killing bottle server...")
            self.server_process.kill()
