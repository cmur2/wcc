# web change checker

First implementation done in bash scripting language.
Actually re-implementing in the "high-level" languages python and ruby.

The web-change-checker bash script highly relies on **up to date Linux tools**
and may stop working on Unix systems.

## Usage

The web-change-checker bash script can be either invoked by hand or
automatically via *cron* on a server environment.

The script loads a given URL with *wget* and calls *md5sum* upon it.
When detecting changes it tries to send an email via *mutt* (you can use *mailx*
but mutt has fewer charset encoding issues) to the specified adresses
and records the event with *logger* in syslog.
