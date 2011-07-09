#!/usr/bin/env python
# -*- encoding: utf-8 -*-

import sys; reload(sys)
sys.setdefaultencoding('utf-8') # we always need failsafe utf-8, in some way

import os
import smtplib

from hashlib import sha1
from urllib import urlopen
from email.mime.text import MIMEText

TMP = '/var/tmp/wcc.tmp'
server = "smtp-server"
username = "login"
passwd = "yourpass"

def sendmail(fr, to, title, msg):
    
    msg = MIMEText(msg)
    msg['Subject'] = title
    msg['From'] = fr
    msg['To'] = to
    
    s = smtplib.SMTP(server, 587)
    s.ehlo()
    s.starttls()
    s.ehlo()
    s.login(username, passwd)
    s.sendmail(fr, [to], msg.as_string())
    s.quit()
    

def checkforupdate(url):
    """checks wether website has changed using sha1 hash stored
    in /var/tmp/wcc.tmp. Notification using sendmail()."""
        
    h = sha1(urlopen(url).read()).hexdigest()
    hashes = [tuple(hash.split('\t')) for hash in open(TMP)]
    
    fp = open(TMP, 'w')
    if not (url, h+'\n') in hashes:
        sendmail("wcc.py", "agleicha@gmail.com", "%s has changed" % url,
                 "Your monitored site hash changed.\n\n%s" % url)
    fp.write('%s\t%s' % (url, h+'\n'))
        
    for t in hashes:
        if t[0] != url:
            fp.write('%s\t%s' % tuple(t))
    fp.close()

if __name__ == '__main__':
    if len(sys.argv) >= 2:
        if not os.path.exists(TMP):
            file(TMP, 'a')
        for arg in sys.argv[1:]:
            checkforupdate(arg)
    else:
        print >> sys.stderr, "usage: python %s URL" % sys.argv[0]