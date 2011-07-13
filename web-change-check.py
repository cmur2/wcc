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
import htmlentitydefs

from email.mime.text import MIMEText


# tag used in output
TAG = "web change checker2"

# config file path
CONF = "conf"

# persistent directory prefix
PER_DIR = "/var/tmp/wcc"

# make verbose output - cron will spam you :p
DEBUG = True

# assume a local mail server without authentiction at port 25
SERVER = "localhost"
PORT = 25
FROM = "user@localhost"

class Site:
    """ Data structure containing all information associated with a "site" """
    
    def __init__(self, url, striphtml, emails):
        self.url = url
        self.striphtml = (striphtml == "yes") # parse "yes" to True, else False
        self.emails = emails
        
        self.id = hashlib.md5(url).hexdigest()[0:8]
        self.shorturl = re.sub(r'[^/]*//([^@]*@)?([^:/]*).*', r'\2', url)



def sendMail(msg, subject, to):
    """ Sends mail containing the given message with the given subject to
the given address. """
    
    text = MIMEText(msg)
    text['Subject'] = subject
    text['From'] = FROM
    text['To'] = to
    
    s = smtplib.SMTP(SERVER, PORT)
    s.starttls()
    s.sendmail(FROM, [to], text.as_string())
    s.quit()

def stripHTML(html):
    """ Returns the input with all HTML tags deleted and all HTML
entities replaced with their unicode representation. """
    
    # delete all <tags>
    new = re.sub('<[^>]*>', ' ', html)
    
    def conv(m):
        text = m.group(0)
        try:
            text = unichr(htmlentitydefs.name2codepoint[text[1:-1]])
        except KeyError:
            pass
        return text
    
    # replace named html entities like &amp;
    return re.sub("&\w+;", conv, new)

def detectEncoding(htmlLines):
    """ Searches the given list of lines of HTML to find the <meta> tag containing
information about content-type and charset and returns this charset.
If serach fails, 'utf-8' will be returned as default. """
    
    enc = "utf-8"
    for line in htmlLines:
        if re.search(r'<meta.*?content-type.*?>', line, re.IGNORECASE):
            # found line with meta tag containing content-type information
            # now filter out the charset information:
            match = re.search(r'<meta.*charset=([a-zA-Z0-9-]*).*', line)
            if match.group(1) != "":
                enc = match.group(1).lower()
                break
    
    return enc

def parseConfig(file):
    """ Parses the given configuration file into several Site objects
and returns them as a list. """
    
    sites = []
    # read all lines
    for line in open(file, 'r'):
        line = line.strip()
        if not re.match(r'^[^#]', line):
            continue
        
        args = [arg for arg in line.split(';')]
        sites.append(Site(args[0], args[1], args[2:]))

    return sites

def updateMD5AndSiteFiles(md5File, md5Data, siteFile, siteData):
    outmd5 = open(md5File, 'w')
    outmd5.write(md5Data+'\n')
    outmd5.close()
            
    outdata = open(siteFile, 'w')
    outdata.write(siteData+'\n')
    outdata.close()

def checkAndNotify(site):
        
    # persistent files
    MD5_FILE = os.path.join(PER_DIR, site.id+'.md5')
    SITE_FILE = os.path.join(PER_DIR, site.id+'.site')
        
    # retrieve site
    new_data = urllib.urlopen(site.url).read()
    # hash before converting charset
    new_md5 = hashlib.md5(new_data).hexdigest()
        
    # detect encoding of site - assume UTF-8 as default
    enc = detectEncoding(new_data.splitlines(True))
                
    if DEBUG: print " encoding: %s" % enc

    # new_data is available in utf-8 (system default encoding)
    new_data = new_data.decode(enc)
        
    if not os.path.exists(MD5_FILE):
        updateMD5AndSiteFiles(MD5_FILE, new_md5, SITE_FILE, new_data)
        return
            
    inmd5 = open(MD5_FILE, 'r')
    old_md5 = inmd5.readline().strip()
    inmd5.close()
        
    indata = open(SITE_FILE, 'r')
    old_data = indata.readlines()
    indata.close()
        
    if old_md5 != new_md5:
        if DEBUG:
            print " Change detected:"
            print " old md5: %s, new md5: %s" % (old_md5, new_md5)
            
        # content of email
        content = "Change at %s - diff follows:\n\n" % site.url
            
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
            
        if site.striphtml:
            diff = stripHTML(diff)
            
        content += diff
                        
        for addr in site.emails:
            if DEBUG: print " addr: %s" % addr
            sendMail(content, "[%s] %s changed" % (TAG, site.shorturl), addr)
                
        # syslog connection
        #logger -t "$TAG" "Change at $site (tag $id) detected"
            
        # do update
        updateMD5AndSiteFiles(MD5_FILE, new_md5, SITE_FILE, new_data)


if __name__ == '__main__':
    from optparse import OptionParser
    parser = OptionParser()
    parser.add_option("-v", "--verbose", action="store_true",
                dest="verbose", default=True, help="prints all debug messages")
                
    (options, args) = parser.parse_args()
    DEBUG = options.verbose
    
    for site in parseConfig(CONF):
        if DEBUG:
            print "site: %s" % site.url
            print " striphtml: %s" % site.striphtml
            print " id: %s" % site.id
            print " shorturl: %s" % site.shorturl
        
        checkAndNotify(site)


