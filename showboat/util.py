import os

# Hacky system calls for now
def rsync(src, dst):
    os.system('rsync -a %s %s' % (src, dst))

def jade_compile(src_path, dst_path):
    #os.system('jade %s --out %s' % (src_path, dst_path))
    os.system('cp %s/*.jade %s' % (src_path, dst_path))
    os.system('jade %s' % (dst_path))


def coffeescript_compile(src_path):
    cmd = 'coffee -c %s' % os.path.join(src_path, 'scripts')
    os.system(cmd)
    
def count_n_slides(out_path):
    with open(os.path.join(out_path, 'index.html'), 'r') as f:
        html = '\n'.join(f.readlines())
        n = len(re.findall(r'class\s*\=\s*\"slide\"', html))
        return n
