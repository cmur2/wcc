#!/usr/bin/env python
# -*- encoding: utf-8 -*-
#
# web change check, wcc.py -- influenced by cmur2
# Used to run as cron. Do `python wcc.py URL`, you can specify multiple
# URLs in one call, and make multiple calls of wcc.py at different times, of course.

import sys; reload(sys)
sys.setdefaultencoding('utf-8') # we always need failsafe utf-8, in some way

import os
import smtplib
import pickle

from hashlib import sha1
from urllib import urlopen
from email.mime.text import MIMEText
from zlib import compress, decompress
from difflib import Differ

# This is the main config. Tempfile, where everything is stored.
# server is a smtp-server, you can access (e.g. gmail)
# authenticate with login and pass
# mailto is the recipient, when the site has changed, including a basic diff

TMP = '/var/tmp/wcc.tmp'
server = "smtp server"; port = 587
username = "login"
passwd = "pass"
mailto = "you@example.org"

def sendmail(fr, to, title, msg):
    """stolen from the internet. No idea, what it does internally. Works.
    Basically http://docs.python.org/library/email-examples.html"""
    
    msg = MIMEText(msg)
    msg['Subject'] = title
    msg['From'] = fr
    msg['To'] = to
    
    s = smtplib.SMTP(server, port)
    s.ehlo()
    s.starttls()
    s.ehlo()
    s.login(username, passwd)
    s.sendmail(fr, [to], msg.as_string())
    s.quit()
    

def checkforupdate(url):
    """checks whether website has changed using sha1 hash stored
    in /var/tmp/wcc.tmp. Notification using sendmail()."""
    
    data = urlopen(url).read()  
    h = sha1(data).hexdigest()
    
    try:
        dict = pickle.load(open(TMP, 'r'))
    except EOFError:
        dict = {}
    
    if not url in dict:
        
        # first run
        dict[url] = (h, compress(data))
    
    elif dict.get(url)[0] != h:
        '''hash has changed, now diffing and updating dict'''
        
        diff = []
        old = decompress(dict.get(url)[1])
        data = data.split('\n')
        for i, line in enumerate(old.split('\n')):
            if line != data[i]: # diff has a multiple of quadratic runtime, only diff, when needed
                d = Differ()
                diff.append('\n'.join(d.compare([line, ], [data[i], ])))
                
        sendmail("wcc.py", mailto, "%s has changed" % url,
                 "%s.\n\n-- %s" % ('\n'.join(diff), url))
                
        dict[url] = (h, compress('\n'.join(data)))
        
    
    fp = open(TMP, 'w')
    pickle.dump(dict, fp)
    fp.close()

if __name__ == '__main__':
    if len(sys.argv) >= 2:
        if not os.path.exists(TMP):
            file(TMP, 'a')
        for arg in sys.argv[1:]:
            checkforupdate(arg)
    else:
        print >> sys.stderr, "usage: python %s URL" % sys.argv[0]
