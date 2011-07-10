#!/usr/bin/env python
# -*- encoding: utf-8 -*-
#

import sys; reload(sys)
sys.setdefaultencoding('utf-8') # we always need failsafe utf-8, in some way

import os
import re
import hashlib
import subprocess


# tag used in output
TAG = "web change checker2"

# config file path
CONF = "my.conf"

# persistent directory prefix
PER_DIR = "/var/tmp"

# make verbose output - cron will spam you :p
DEBUG = "true"



def main():
    # read all lines
    f = open(CONF, 'r')
    lines = [line.rstrip() for line in f.readlines()]
    f.close()
    
    for line in lines:
        if not re.match('^[^#:space:]', line):
            continue
        
        #print line
        
        args = [arg for arg in line.split(';')]
        
        site = args.pop(0)
        print "site: %s" % site
        
        striphtml = args.pop(0)
        print "  striphtml: %s" % striphtml
        
        emails = args
        
        tname = hashlib.md5(site).hexdigest()[0:8]
        print "  tname: %s" % tname
        
        tsite = re.sub(r'[^/]*\/\/([^@]*@)?([^:/]*).*', r'\2', site)
        print "  tsite: %s" % tsite
        
         # persistent files
        MD5_FILE = "%s/%s.md5" % (PER_DIR, tname)
        SITE_FILE = "%s/%s.site" % (PER_DIR, tname)
        
        # temp files
        #TMP = ""
        
        
        #for addr in emails:
        #    print "  addr: %s" % (addr)
        
        

if __name__ == '__main__':
    main()
