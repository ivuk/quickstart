#!/bin/bash -x

set -euo pipefail

ldap_admin_password=${1:-admin}
ldap_version=${2:-1.2.4}
ldapimage="osixia/openldap"
ldap_organization="Example Org"
ldap_domain="example.com"
ldap_hostname="ldap-01.example.com"

# Pull the OpenLDAP Docker image
until docker inspect $ldapimage:$ldap_version > /dev/null 2>&1; do
  docker pull $ldapimage:$ldap_version
  sleep 2
done

# Run the OpenLDAP server
# Note that this is set up for the osixia/openldap image
if [[ $(docker ps --format '{{.Names}}' --filter "name=openldap-server") == "openldap-server" ]]; then
    echo "Container openldap-server already running, skipping."
else
    docker run -p 389:389 -p 636:636 \
        --name openldap-server \
        --env LDAP_ORGANISATION="${ldap_organization}" \
        --env LDAP_DOMAIN="${ldap_domain}" \
        --env LDAP_ADMIN_PASSWORD="${ldap_admin_password}" \
        --hostname ${ldap_hostname} \
        --detach osixia/openldap:${ldap_version}
fi

# Wait for OpenLDAP container to be ready
until docker exec openldap-server ldapsearch -x -H ldap://localhost -b "dc=example,dc=com" -D "cn=admin,dc=example,dc=com" -w "admin" &>/dev/null; do
    sleep 5
done

# Add the OU and an example user account
# User password is set to 'user'
docker exec -i openldap-server ldapadd -x -H ldap://localhost -D "cn=admin,dc=example,dc=com" -w "admin" <<-EOF
dn: ou=users,dc=example,dc=com
objectclass: organizationalunit
ou: users
description: user ou

dn: ou=groups,dc=example,dc=com
objectclass: organizationalunit
ou: groups
description: group ou

dn: cn=group,ou=groups,dc=example,dc=com
objectclass: groupofnames
cn: group
description: first group
member: cn=user,ou=users,dc=example,dc=com

dn: cn=user,ou=users,dc=example,dc=com
uid: user
cn: user name
givenName: user
sn: name
mail: user@example.com
objectClass: inetOrgPerson
objectClass: posixAccount
objectClass: top
loginShell: /bin/bash
homeDirectory: /home/user
uidNumber: 10000
gidNumber: 10000
userPassword: {SSHA}HSdDPkfhAwGc1q9EIGFtqeFEE/+bAVU+

dn: cn=user2,ou=users,dc=example,dc=com
uid: user2
cn: user2 name
givenName: user2
sn: name
mail: user2@example.com
objectClass: inetOrgPerson
objectClass: posixAccount
objectClass: top
loginShell: /bin/bash
homeDirectory: /home/user2
uidNumber: 10001
gidNumber: 10001
userPassword: {SSHA}HSdDPkfhAwGc1q9EIGFtqeFEE/+bAVU+
EOF
