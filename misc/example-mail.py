#!/usr/bin/env python

import sys; reload(sys)
sys.setdefaultencoding('utf-8')

import smtplib
from email.mime.text import MIMEText

server = "localhost"; port = 25#587
#username = "login"
#passwd = "pass"
#mailto = "you@example.org"

#def sendmail(fr, to, title, msg):

fr = "chrnicolai@gmail.com"
to = "christian.nicolai@student.hpi.uni-potsdam.de"

msg = MIMEText("Test")
msg['Subject'] = "test.py"
msg['From'] = fr
msg['To'] = to

s = smtplib.SMTP(server, port)
#    s.ehlo()
#    s.starttls()
#    s.ehlo()
#    s.login(username, passwd)
s.sendmail(fr, [to], msg.as_string())
s.quit()
	
