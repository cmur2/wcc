web change checker
==================

This is a powerful ruby program to track changes of websites and get notified via mail on
change with configurable scope of adresses per website. All mails contain a unified diff
from old content to new content so minor changes produce only few lines of text even on large sites.

Since version 2.0 wcc has a completely rewritten notification system so emails are now only *one*
way to recieve notifications - the currently supported other are XMPP/Jabber and the Syslog.
These changes are reflected in 'conf.yml' as well so take care of migrating it (that basically
means to create a *recipients* section and update your site entries from *emails* to *notify*).

Note: wcc relies on native `diff` command to produce the unified diff shown in mails and native
`syslog` command as well as user information from /etc/login.

Setup
-----

You need Ruby (preferably version 1.8.7, Ruby 1.9 untested) and Rubygems installed
(consider using [rvm](http://beginrescueend.com/)). Install wcc:

	gem install wcc

(If you *don't* use [rvm](http://beginrescueend.com/) you should add a 'sudo'.)

Then you should pick an (empty!) directory for the configuration files (as 'conf.yml') for wcc
let's call it '/my/conf' for now. You do a

	cd /my/conf

and then

	wcc-init

At this time you should run the `wcc` command only in this directory since wcc reads it's
configuration by default from './conf.yml'.

Usage
-----

The installed 'wcc' gem provides a `wcc` binary on the command line.
It can invoked by hand or automatically via *cron* on a server environment.

For using wcc you need to specify some options:

* either via the command line (see `wcc -h`)
* or in a configuration file in [YAML](https://secure.wikimedia.org/wikipedia/en/wiki/YAML) format

The location of the configuration file (usually called 'conf.yml')
can itself be given on command line as last argument. Each option has a hard-coded default
(e.g. the configuration file name is assumed to be './conf.yml'). Command line options
overwrite configuration file entries.

To see how such a configuration might look open 'conf.yml' in your '/my/conf' directory after
doing `wcc-init` - it contains a bunch of comments that describe your options. The basic structure
is made up from three sections: generic entries in *conf*, user profiles in *recipients* and a
list of sites to check for changes in *sites*. Each site entry should contain an URL and a
list of user profile names to notify on change.

An example crontab entry that runs wcc every 5 minutes might look like this:

	*/5 *  * * *   root    cd /my/conf;./wcc

Since you can configure an individual check_interval per site these 5 minutes in crontab are only
the least common multiple for wcc check if each sites check_interval has passed.

By default wcc only outputs ERROR and FATAL messages to avoid your cron daemon spammin' around.
It is recommended to place 'conf.yml' (and optionally the 'filter.d' and 'template.d') within
a separate directory and use `cd` in cron entry.

Upgrade
-------

If you want to update your wcc run:

	gem update

Then don't forget to run

	wcc-upgrade

in your '/my/conf' directory which interactively asks to overwrite local 'assets'
like mail templates and filters with the original ones out of the gem (which you copied
there using `wcc-init` at the beginning).

NOTE: You should **make a backup** (especially of your **conf.yml**) of the '/my/conf'
directory **before upgrading**.

License
-------

The web change checker (aka wcc) is licensed under the Apache License, Version 2.0.
See LICENSE for more information.
