#!/usr/bin/env python
# -*- encoding: utf-8 -*-
#

import sys; reload(sys)
sys.setdefaultencoding('utf-8') # we always need failsafe utf-8, in some way

import os
import re
import hashlib


# tag used in output
TAG = "web change checker2"

# config file path
CONF = "my.conf"

# persistent directory prefix
PER_DIR = "/var/tmp"

# make verbose output - cron will spam you :p
DEBUG = "true"


def main():
    
    for line in open(CONF, 'r'):
        line = line.strip()
        if line.find('#') > -1 or line.find(' ') > -1:
            continue
        
        args = [arg for arg in line.split(';')]
        site, striphtml = args[0:2]
        print "site: %s" % site
        print "  striphtml: %s" % striphtml
        
        emails = args[2:]
        
        tname = hashlib.sha1(site).hexdigest()[0:8]
        print "  tname: %s" % tname
        
        tsite = re.sub(r'[^/]*\/\/([^@]*@)?([^:/]*).*', r'\2', site) #WTF?
        print "  tsite: %s" % tsite
        
        # persistent files
        MD5_FILE = os.path.join(PER_DIR, tname+'.md5')
        SITE_FILE = os.path.join(PER_DIR, tname+'.site')
        
        # temp files
        #TMP = ""
        
        
        #for addr in emails:
        #    print "  addr: %s" % (addr)
        
        

if __name__ == '__main__':
    main()
