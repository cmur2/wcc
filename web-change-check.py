#!/usr/bin/env python
# -*- encoding: utf-8 -*-
#

import sys; reload(sys)
sys.setdefaultencoding('utf-8') # we always need failsafe utf-8, in some way

import os
import re
import hashlib
import urllib
import datetime
import difflib


# tag used in output
TAG = "web change checker2"

# config file path
CONF = "conf"

# persistent directory prefix
PER_DIR = "/var/tmp"

# temp directory prefix
TMP_DIR = "/tmp"

# make verbose output - cron will spam you :p
DEBUG = True



def main():
    # read all lines
    for line in open(CONF, 'r'):
        line = line.strip()
        if not re.match('^[^#]', line):
            continue
        
        #print line
        
        args = [arg for arg in line.split(';')]
        
        site, striphtml = args[0:2]
        if DEBUG: print "site: %s" % site
        if DEBUG: print "  striphtml: %s" % striphtml
        
        emails = args[2:]
        
        tname = hashlib.md5(site).hexdigest()[0:8]
        if DEBUG: print "  tname: %s" % tname
        
        tsite = re.sub(r'[^/]*\/\/([^@]*@)?([^:/]*).*', r'\2', site)
        if DEBUG: print "  tsite: %s" % tsite
        
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
        
        indata = open(SITE_FILE, 'r')
        old_data = indata.readlines()
        indata.close()
        
        #print old_md5+" "+new_md5
        
        if old_md5 != new_md5:
            LOLD = "OLD ("+datetime.datetime.fromtimestamp(os.path.getmtime(MD5_FILE)).strftime('%Y-%m-%d %H:%M:%S')+")"
            LNEW = "NEW ("+datetime.datetime.now().strftime('%Y-%m-%d %H:%M:%S')+")"
            
            diff = difflib.unified_diff(old_data, new_data.splitlines(True), "OLD", "NEW", datetime.datetime.fromtimestamp(os.path.getmtime(MD5_FILE)).strftime('%Y-%m-%d %H:%M:%S'), datetime.datetime.now().strftime('%Y-%m-%d %H:%M:%S'))
            
            for line in diff:
                sys.stdout.write(line)
            
            
            
            # do diff
            # do mail
            # do update
        
        
        #for addr in emails:
        #    print "  addr: %s" % (addr)
        
        

if __name__ == '__main__':
    from optparse import OptionParser
    parser = OptionParser()
    parser.add_option("-v", "--verbose", action="store_true",
                dest="verbose", default=True, help="prints all debug messages")
                
    (options, args) = parser.parse_args()
    DEBUG = options.verbose
    
    main()
