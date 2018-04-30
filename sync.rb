require 'net-ldap'
require 'zabbixapi'
require 'securerandom'

# ENV for secrets and whatnot
load './env.rb' if File.exists?('./env.rb')


def checkUserExists(queryuser)
  if @zbx.users.get_id(:alias => queryuser) == nil
    return false
  end
end

def checkLdapGroups(queryuser)
  groups = []
  filter = Net::LDAP::Filter.construct("(&(objectClass=posixGroup)(memberUid=#{queryuser}))")
  @ldap.search(:base => "ou=groups,dc=dco,dc=com", :filter => filter) do |object|
    groups << object.cn
  end
  return groups.flatten
end

def checkZabbixGroups(queryuser)
  groups = []
  userid = @zbx.users.get_id(:alias => queryuser)

  usergroups = @zbx.query(
    :method => "usergroup.get",
    :params => {
      "output" => "extend",
      "userids" => [userid]
    }
  )
  usergroups.each do |user|
    groups << user['name']
  end
 return groups
end

def checkMembership(queryuser)
  ldapgroups = checkLdapGroups(queryuser)
  zabbixgroups = checkZabbixGroups(queryuser)
  if ldapgroups.include?("devops")
    unless zabbixgroups.include?("Administrators")
      @zbx.usergroups.add_user(
        :usrgrpids => [@zbx.usergroups.get_id(:name => "Administrators")],
        :userids => [@zbx.users.get_id(:alias => queryuser)]
      )
      puts "Added #{queryuser} to Administrators"
    end
    @zbx.users.update(
      :userid => @zbx.users.get_id(:alias => queryuser),
      :type => 3
    )
  end

  if ldapgroups.include?("developers")
    unless zabbixgroups.include?("Devs")
      @zbx.usergroups.add_user(
        :usrgrpids => [@zbx.usergroups.get_id(:name => "Devs")],
        :userids => [@zbx.users.get_id(:alias => queryuser)]
      )
      puts "Added #{queryuser} to Devs"
    end
  end
end

def getAllLDAPUsers
  users = []
  filter = Net::LDAP::Filter.construct("(&(objectClass=posixGroup)(|(cn=devops)(cn=developers)))")
  @ldap.search(:base => "ou=groups,dc=dco,dc=com", :filter => filter) do |object|
    users << object.memberUid
  end
  return users.flatten.uniq
end

def checkUser(user)
  uid = @zbx.users.get_id(:alias => user)
  if uid == nil
    password = SecureRandom.hex
    @zbx.users.create(
      :alias => user,
      :passwd => password,
      :usrgrps => [
        :usrgrpid => nil
      ]
    )
    puts "Created new user #{user}"
  end
end

@zbx = ZabbixApi.connect(
  :url => "#{ENV['zabbix_url']}",
  :user => "#{ENV['zabbix_username']}",
  :password => "#{ENV['zabbix_password']}"
)

ldapuser="#{ENV['ldap_username']}"
ldappass="#{ENV['ldap_password']}"

@ldap = Net::LDAP.new(:host => "#{ENV['ldap_url']}",
:port => 636,
:encryption => :simple_tls,
:auth => {
     :method => :simple,
     :username => "cn=#{ldapuser},dc=dco,dc=com",
     :password => "#{ldappass}"
})

unless @ldap.bind
  puts "Can't bind correctly to LDAP"
end

users = getAllLDAPUsers
users.each do |user|
  checkUser(user)
  checkMembership(user)
end
