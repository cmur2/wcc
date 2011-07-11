#!/usr/bin/env python
# -*- encoding: utf-8 -*-
#

import sys; reload(sys)
sys.setdefaultencoding('utf-8') # we always need failsafe utf-8, in some way

import os
import re
import hashlib
import urllib


# tag used in output
TAG = "web change checker2"

# config file path
CONF = "my.conf"

# persistent directory prefix
PER_DIR = "/var/tmp"

# temp directory prefix
TMP_DIR = "/tmp"

# make verbose output - cron will spam you :p
DEBUG = "true"



def main():
    # read all lines
    for line in open(CONF, 'r'):
        line = line.strip()
        if not re.match('^[^#]', line):
            continue
        
        #print line
        
        args = [arg for arg in line.split(';')]
        
        site, striphtml = args[0:2]
        print "site: %s" % site
        print "  striphtml: %s" % striphtml
        
        emails = args[2:]
        
        tname = hashlib.md5(site).hexdigest()[0:8]
        print "  tname: %s" % tname
        
        tsite = re.sub(r'[^/]*\/\/([^@]*@)?([^:/]*).*', r'\2', site)
        print "  tsite: %s" % tsite
        
        # persistent files
        MD5_FILE = os.path.join(PER_DIR, tname+'.md5')
        SITE_FILE = os.path.join(PER_DIR, tname+'.site')
        
        # temp files
        #TMP_MD5 = os.path.join(TMP_DIR, tname+'.md5')
        #TMP_SITE = os.path.join(TMP_DIR, tname+'.site')
        TMP_DIFF = os.path.join(TMP_DIR, tname+'.diff')
        TMP_DIFF2 = os.path.join(TMP_DIR, tname+'.diff2')
        TMP_MAIL = os.path.join(TMP_DIR, tname+'.mail')
        
        new_data = urllib.urlopen(site).read()
        new_md5 = hashlib.md5(new_data).hexdigest()
        
        if not os.path.exists(MD5_FILE):
            outmd5 = open(MD5_FILE, 'w')
            outmd5.write(new_md5+'\n')
            outmd5.close()
            
            outdata = open(SITE_FILE, 'w')
            outdata.write(new_data+'\n')
            outdata.close()
            continue
            
        inmd5 = open(MD5_FILE, 'r')
        old_md5 = inmd5.readline().strip()
        inmd5.close()
        
        #print old_md5+" "+new_md5
        
        
        #print data
        
        
        #for addr in emails:
        #    print "  addr: %s" % (addr)
        
        

if __name__ == '__main__':
    main()
