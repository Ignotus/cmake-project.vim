import sys
import glob
import os
import fileinput
import re

def cmake_project_files(project_dir):
    dependencies = []
    internals = []
    currentdir = os.path.abspath(os.getcwd())

    for root, dirs, files in os.walk(os.path.join(currentdir, project_dir)):
        for name in dirs:
            path = os.path.join(root, name)
            dependencies.append(glob.glob(os.path.join(path, "DependInfo.cmake")))
            internals.append(glob.glob(os.path.join(path, "depend.internal")))
    
    dependencies = filter(None, dependencies)
    internals = filter(None, internals)

    accum = []
    for filename in dependencies:
        accum = accum + src_files(filename[0])

    for filename in internals:
        accum = accum + header_files(filename[0], currentdir)
    
    return list(set(filter(None,accum)))


def src_files(filename):
    result = []
    pattern = re.compile('(\s+")(([a-zA-Z0-9\/])+[a-zA-Z0-9\S]+\.(cpp|cc|c))"')
    if os.path.isfile(filename):
        for line in fileinput.input(filename):
            if pattern.match(line):
                result.append(pattern.match(line).group(2))

    return result

def header_files(filename, currentdir):
    result = []
    pattern = re.compile('(\s+)(([a-zA-Z0-9\/])+[a-zA-Z0-9\S]+\.(hpp|h))')
    if os.path.isfile(filename):
        for line in fileinput.input(filename):
            if pattern.match(line):
                abspath = os.path.abspath(pattern.match(line).group(2))
                if(abspath.find(currentdir) != -1):
                    result.append(pattern.match(line).group(2))

    return result

