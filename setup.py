#!/usr/bin/env python
# -*- coding: utf-8 -*-

""" distribute- and pip-enabled setup.py for showboat """

from distribute_setup import use_setuptools
use_setuptools()
from setuptools import setup, findall

import re

def subdir_findall(dir, subdir):
    strip_n = len(dir.split('/'))
    path = '/'.join((dir, subdir))
    return ['/'.join(s.split('/')[strip_n:]) for s in findall(path)]


setup(
    name='showboat',

    version='dev',
    include_package_data=True,

    packages=['showboat'],
    package_data = { 'showboat' : subdir_findall('showboat', 'payload')},
    scripts=['scripts/showboat', 'scripts/showboat_server'],
)
