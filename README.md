# perl-postfix-policyServer
A perl written policyServer with plugins which can be used with postfix SMTP Access Policy Delegation.  
http://www.postfix.org/SMTPD_POLICY_README.html

**Installation hints:**
- Create a mysql database (i.e. postfixdb) and import database.sql
- Put main server script policyServer.pl and the directory policyServer-plugins to /usr/local/sbin.
- Put policyServer.conf to /usr/local/etc and edit the file to fit your needs.
- Add policyServer.service script to your systemd service directory (e.g. /etc/systemd/system) and enable it.

**Postfix configuration:**
Add the following line to your postfix main.cfg below smtpd_recipient_restrictions:
```
check_policy_service inet:<server>:<port>
<server> is either localhost if policyServer.pl runs on the same machine or the name of the server you installed the script.
<port> is the port where policyServer.pl ist listening for connection which is configured in policyServer.conf (Standard: 10031)
```

**Additional Infos:**
- policyServer.pl based on Net::Server::Fork so you have to install this Perl module via Packetmanager or CPAN.
- Other required Perl modules are: Sys::Syslog and Net::CIDR for ACLs configured in policyServer.conf
- The location of the config file is statically written in policyServer.pl
- The sequence of the plugin written in policyServer.conf is essential - accounting.pm has to be the first in list.
- The plugin configuration has to be done directly in the plugins below the directory policyServer-plugins
  -plugin.pm:  Mail recipient configuration uses by plugins to be able to inform an user.  
               The plugin spamcheck.pm use this in case a user is blocked after spamming detection occured (see below).
  - spamcheck.pm: Change the spam detection limits according to your needs
  - senderReject.pm and recipientReject.pm: global sender (DB column sender_blacklist) and recipient (recipient_blacklist) blacklists (Regex)
  - senderRecipientCheck.pm a per user blacklist (Regex).
    
If you stuck in configuration and nothing will work - feel free to ask for help (Email: roderick.braun@ph-freiburg.de)
