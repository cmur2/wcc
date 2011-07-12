#!/usr/bin/env python
# -*- encoding: utf-8 -*-
#

import sys; reload(sys)
sys.setdefaultencoding('utf-8') # we always need failsafe utf-8, in some way

import os
import re
import time
import hashlib
import urllib
import difflib
import smtplib

from email.mime.text import MIMEText


# tag used in output
TAG = "web change checker2"

# config file path
CONF = "conf"

# persistent directory prefix
PER_DIR = "/var/tmp/wcc"

# temp directory prefix
TMP_DIR = "/tmp/wcc"

# make verbose output - cron will spam you :p
DEBUG = True

# assume a local mail server without authentiction at port 25
SERVER = "localhost"
PORT = 25


def sendMail(msg, subject, to):
    fr = "chrnicolai@gmail.com"

    text = MIMEText(msg)
    text['Subject'] = subject
    text['From'] = fr
    text['To'] = to
    
    s = smtplib.SMTP(SERVER, PORT)
    s.starttls()
    s.sendmail(fr, [to], text.as_string())
    s.quit()
    

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
        #TMP_DIFF = os.path.join(TMP_DIR, tname+'.diff')
        #TMP_DIFF2 = os.path.join(TMP_DIR, tname+'.diff2')
        #TMP_MAIL = os.path.join(TMP_DIR, tname+'.mail')
        
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
            if DEBUG: print "  Change detected:"
            
            # content of email
            content = "Change at %s - diff follows:\n\n" % site
            
            diffGen = difflib.unified_diff(
                old_data,
                new_data.splitlines(True),
                "OLD",
                "NEW",
                '(%s)' % time.strftime('%Y-%m-%d %H:%M:%S',
                                time.gmtime(os.path.getmtime(MD5_FILE))),
                '(%s)' % time.strftime('%Y-%m-%d %H:%M:%S', time.localtime()),
                1)
            
            diff = ''.join([line for line in diffGen])
            
            #if striphtml == "yes":
            #
            
            content += diff
                        
            for addr in emails:
                if DEBUG: print "    addr: %s" % addr
                sendMail(content, "[%s] %s changed" % (TAG, tsite), addr)
                
            # syslog connection
            #logger -t "$TAG" "Change at $site (tag $tname) detected"
            
            # do update
            outmd5 = open(MD5_FILE, 'w')
            outmd5.write(new_md5+'\n')
            outmd5.close()
            
            outdata = open(SITE_FILE, 'w')
            outdata.write(new_data+'\n')
            outdata.close()

if __name__ == '__main__':
    from optparse import OptionParser
    parser = OptionParser()
    parser.add_option("-v", "--verbose", action="store_true",
                dest="verbose", default=True, help="prints all debug messages")
                
    (options, args) = parser.parse_args()
    DEBUG = options.verbose
    
    main()
