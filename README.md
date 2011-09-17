web change checker
==================

This is a simple script to track changes of websites and get notified via mail on
change with configurable scope of adresses per website. All mails contain a unified diff
from old content to new content so minor changes produce only few lines of text even on large sites.

Note: wcc relies on native `diff` command to produce the unified diff shown in mails -
plans are to remove this dependency by using [something like this](https://github.com/samg/diffy) later...

Implemented in Ruby, tested with Ruby 1.8.7. The main file is 'wcc.rb'.

Usage
-----

The web-change-checker ruby script can be either invoked by hand or
automatically via *cron* on a server environment since it contains a shebang
line for '/usr/bin/ruby'.

For using wcc you need to specify some options:

* either via the command line (see `wcc.rb -h`)
* or in a configuration file in [YAML](https://secure.wikimedia.org/wikipedia/en/wiki/YAML) format

The location of the configuration file (usually called 'conf.yml' or something like this)
can itself be given on command line as last argument. Each option has an hard-coded default
(e.g. the configuration file name is assumed to be './conf.yml'). Command line options
overwrite configuration file entries.

The core option is the From: mail address and the SMTP configuration for sending emails.
It is highly encouraged to use the configuration file for all rare changing things
(even because you have to specify the list of tracked sites there anyways).

An example crontab entry that runs wcc every 10 minutes might look like this:

	*/10 *  * * *   root    cd /path/to/wcc;./wcc.rb

By default wcc only outputs ERROR messages to avoid your cron daemon spammin' around.
It is recommended to place 'wcc.rb' and 'conf.yml' within an separate directory and
use `cd` in cron entry.

Setup
-----

First you need to install ruby (preferably version 1.8.7) and rubygems since wcc depends
on some gems (currently one but number will grow):

* [htmlentities](http://htmlentities.rubyforge.org/) (preferably 4.3.0)

Install the listed gems via:

	sudo gem install *name*

(If you use [rvm](http://beginrescueend.com/) you should omit the 'sudo'.)

Old Implementations
-------------------

* Bash - has been abandoned, production usage is discouraged!
* Python - has been abandoned
