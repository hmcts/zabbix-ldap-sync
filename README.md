# zabbix-ldap-sync
Script to sync ldap users with zabbix users and mush people into correct groups

You'll need an `env.rb` file in the same directory that has content like this:

```ruby
ENV['zabbix_username'] = "setmezabbixusername"
ENV['zabbix_password'] = "setmezabbix"
ENV['zabbix_url'] = "setmezabbixurl.com"
ENV['ldap_username'] = "setmeldapusername"
ENV['ldap_password'] = "setmeldap"
ENV['ldap_url'] = "setmeldapurl.com"
```
