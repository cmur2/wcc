web change checker
==================

This is a simple ruby script to track changes of websites and get notified via mail on
change with configurable scope of adresses per website. All mails contain a unified diff
from old content to new content so minor changes produce only few lines of text even on large sites.

Note: wcc relies on native `diff` command to produce the unified diff shown in mails -
plans are to remove this dependency by using [something like this](https://github.com/samg/diffy) later...

Setup
-----

You need Ruby (preferably version 1.8.7) and Rubygems installed
(consider using [rvm](http://beginrescueend.com/)). Install wcc:

	gem install wcc

(If you *don't* use [rvm](http://beginrescueend.com/) you should add a 'sudo'.)

Then you should pick an (empty!) directory for the configuration files (as 'conf.yml') for wcc
let's call it '/my/conf' for now. You do a

	cd /my/conf

and then

	wcc-init

At this time you should run the ´wcc´ command only in this directory since wcc reads it's
configuration by default from './conf.yml'.

Usage
-----

The installed 'wcc' gem provides a ´wcc´ binary on the command line.
It can invoked by hand or automatically via *cron* on a server environment.

For using wcc you need to specify some options:

* either via the command line (see `wcc -h`)
* or in a configuration file in [YAML](https://secure.wikimedia.org/wikipedia/en/wiki/YAML) format

The location of the configuration file (usually called 'conf.yml' or something like this)
can itself be given on command line as last argument. Each option has a hard-coded default
(e.g. the configuration file name is assumed to be './conf.yml'). Command line options
overwrite configuration file entries.

The core option is the From: mail address and the SMTP configuration for sending emails.
It is highly encouraged to use the configuration file for all rare changing things
(even because you have to specify the list of tracked sites there anyways).

An example crontab entry that runs wcc every 10 minutes might look like this:

	*/10 *  * * *   root    cd /path/to/dir/with/conf;./wcc

By default wcc only outputs ERROR and FATAL messages to avoid your cron daemon spammin' around.
It is recommended to place 'conf.yml' (and optionally the 'filter.d' and 'template.d') within
a separate directory and use `cd` in cron entry.
