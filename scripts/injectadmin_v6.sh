#!/bin/bash

# Injects an admin user with full privileges, e.g user, privileges and policy.
# To be run on a controller
# 2020 - marx@appgate.com
#
#
# Publicly available: https://appgate-material.s3.eu-central-1.amazonaws.com/bin/injectadmin.sh
#
# Run on the controller: 
#   - install:
# bash <(curl -s  https://appgate-material.s3.eu-central-1.amazonaws.com/bin/install-adminuser.sh)
#   - uninstall:
# bash <(curl -s  https://appgate-material.s3.eu-central-1.amazonaws.com/bin/uninstall-adminuser.sh)

cd /tmp
ts=`date --utc +%FT%TZ`
tags='{cmdinjected}'
name="injadmin" #${RANDOM:0:3}

admin_role_name='InjectedFullAdmin'
policy_name='InjectedAdminPolicy'
new_password=`openssl rand -base64 30`

user() {
  new_salt=`</dev/urandom tr -dc 'A-Za-z0-9*+,-./:;<=>[\]^_' | head -c 30`
  salt=${new_salt}

  uuid=`cat /proc/sys/kernel/random/uuid` 
  password=${new_password}
  
  # calculate the hash
  hash=`printf "${password}${salt}"|sha512sum|head -c 128`
  
  # insert query
  ins_query="INSERT INTO local_user(id, name, first_name, last_name, password, password_salt, email, tags, created, updated )\
    VALUES ('${uuid}', '${name}', 'injected', 'admin', '${hash}', '${salt}', 'in.jected@packnot.com', '${tags}', '${ts}', '${ts}');"
  
    
  printf "Creating user\n------------------\nname: ${name}\npassword: ${password}\n-----------------\n"
  sudo cz-dbs pg cli -c "${ins_query}"
  #sudo -u postgres psql  -d controller -c "${ins_query}"

}



privs() {
  printf "Adding user...\n" 
  
  uuid_role=`cat /proc/sys/kernel/random/uuid` 
  uuid_priv=`cat /proc/sys/kernel/random/uuid`


  query_role="INSERT INTO administrative_role(id, name, tags, created, updated) \
    VALUES('${uuid_role}', '${admin_role_name}', '${tags}', '${ts}', '${ts}');"

  query_priv="INSERT INTO administrative_privilege(id, administrative_role_id, type, target, scope_all) \
    VALUES ('${uuid_priv}', '${uuid_role}', 'All', 'All', 't' )"

  sudo cz-dbs pg cli -c "${query_role}"
  sudo cz-dbs pg cli -c "${query_priv}"
  #sudo -u postgres psql  -d controller -c "${query_role}"
  #sudo -u postgres psql  -d controller -c "${query_priv}"
}


policy() {
        printf "Adding privileges...\n"
        idp_uuid_query="SELECT id FROM identity_provider WHERE name = 'local';"
        uuid_idp=`sudo cz-dbs pg cli -c "${idp_uuid_query}" | grep -i '[A-Z0-9]*\-[A-Z0-9]' | xargs`
        #uuid_idp=`sudo -u postgres psql -t -A -F"," -d controller -c "${idp_uuid_query}"`

        uuid_policy=`cat /proc/sys/kernel/random/uuid`

       # expression="    var result = false;
       # if/*claims.user.ag.identityProviderId*/(claims.user.ag && claims.user.ag.identityProviderId === \"${uuid_idp}\")/*end claims.user.ag.identityProviderId*/ { result = true; } else { return false; }
       # if/*claims.user.username*/(claims.user.username === \"${name}\")/*end claims.user.username*/ { result = true; } else { return false; }
       # return result;"

	expression="var result = false;
if/*identity-provider*/(claims.user.ag.identityProviderId === \"${uuid_idp}\")/*end identity-provider*/ { result = true; } else { return false; }
if/*claims.user.username*/(claims.user.username ===  \"${name}\")/*end claims.user.username*/ { result = true; } else { return false; }
return result;"


        # Since v5.5 a new field was added which defaults to 'Combined' which is not allowed. 
        # It must be set to 'Mixed' explicitly. This will be eventually fixed in some version > 5.5  
        newVersion=16
        version=$(sudo jqr .version)
        if [ "${version}" -ge "$newVersion" ];
        then
          query_policy="INSERT INTO policy(id, name, created, updated, tags, expression, type)\
                      VALUES('${uuid_policy}', '${policy_name}', '${ts}', '${ts}', '${tags}', '${expression}', 'Mixed'   )"
        else
          query_policy="INSERT INTO policy(id, name, created, updated, tags, expression)\
                      VALUES('${uuid_policy}', '${policy_name}', '${ts}', '${ts}', '${tags}', '${expression}' )"
        fi

        query_policy_adminrole="INSERT INTO policy_administrative_role(policy_id, administrative_role_id)\
                SELECT '${uuid_policy}',id FROM administrative_role WHERE name = '${admin_role_name}'"


        sudo cz-dbs pg cli -c "${query_policy}"
        sudo cz-dbs pg cli -c "${query_policy_adminrole}" 
        #sudo -u postgres psql  -d controller -c "${query_policy_adminrole}"
        #sudo -u postgres psql  -d controller -c "${query_policy_adminrole}"


}

cleanup(){
  printf "Cleaning up...\n" 
        rm_user_query="DELETE FROM local_user WHERE name = '${name}';"
  rm_adminrole_query="DELETE FROM administrative_role WHERE name = '${admin_role_name}';"
  rm_policy_query="DELETE FROM policy WHERE name = '${policy_name}';"


  sudo cz-dbs pg cli -c "${rm_user_query}"
  sudo cz-dbs pg cli -c "${rm_adminrole_query}"
  sudo cz-dbs pg cli -c "${rm_policy_query}"
  #sudo -u postgres psql  -d controller -c "${rm_user_query}"
  #sudo -u postgres psql  -d controller -c "${rm_adminrole_query}"
  #sudo -u postgres psql  -d controller -c "${rm_policy_query}"
}



autoclean(){
  printf "Setting up auto-uninstall when tokens detected (even outdated ones)...\n"
  cleaner="/tmp/clean-$$.sh"


  #nr_tokens=\$(sudo -u postgres psql   -t -A -d controller -c "SELECT COUNT(*) FROM token_record WHERE username = '\${username}';")

  cat  << EOF > ${cleaner}
#!/bin/bash
cd /tmp
trap 'rm -f ${cleaner}' 0
trap 'exit $?' 1 2 3 15

username=$name

while :
  do
  nr_tokens=\$(sudo cz-dbs pg cli -c "SELECT COUNT(*) FROM token_record WHERE username = '\${username}';")
        if [ \${nr_tokens} -ne 0 ]; then
                echo "\${nr_tokens} tokens found for user \${username}; Removing privileges and local user account."
           bash <(curl -s  https://appgate-material.s3.eu-central-1.amazonaws.com/bin/uninstall-adminuser.sh)
           exit 0
        else
           echo "No tokens found for user \${username}, continue testing..."
        fi
        sleep 2
  done

EOF
  chmod +x ${cleaner}
  nohup ${cleaner} > ${cleaner}.log 2>&1 </dev/null &
}



revoke(){
  printf "Revoking token for ${name}...\n"
  query_revoke="DELETE FROM token_record WHERE username = '${name}'"
  sudo cz-dbs pg cli -c "${query_revoke}"
  #sudo -u postgres psql  -d controller -c "${query_revoke}"
}

autoinstall(){
  user
  privs
  policy
  autoclean
}



install(){
  user
  privs
  policy
}

uninstall(){
  cleanup
} 




# bash test if func defined
if declare -f "$1" > /dev/null
then
  "$@"
else
  echo "'$1' is not a known function name. Use install ur uninstall" >&2
  exit 1
fi

