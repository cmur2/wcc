web change checker
==================

Implemented in Ruby, tested with Ruby 1.8.7. The main file is 'wcc.rb'.

Usage
-----

The web-change-checker ruby script can be either invoked by hand or
automatically via *cron* on a server environment since it. It contains
a shebang line for '/usr/bin/ruby'.

On calling this script you need at least provide the 'From:' mail address
on command line using '-f'. Additionally a configuration file name (default is 'conf'
in current directory) which defines the websites to check can be specified there.

An example crontab entry that runs wcc every 10 minutes might look like this:
> */10 *  * * *   root    cd /path/to/wcc;./wcc.rb -q -f "root@example.com"

The '-q' flag is important to suppress any output below the ERROR log level!
It is recommended to place 'wcc.rb' and 'conf' within an separate directory and
use `cd` in cron entry.

Setup
-----

First you need to install ruby (preferably version 1.8.x) and rubygems since wcc depends
on some gems (currently one but number will grow):

* htmlentities (preferably 4.3.0)

Install the listed gems via 'gem install **name**'.

Old Implementations
-------------------

* Bash - has been abandoned, production usage is discouraged!
* Python - has been abandoned
