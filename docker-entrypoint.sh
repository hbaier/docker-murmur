#!/bin/bash

set -e

get_config() {
  local -n configuration=$1

  # database configuration
  configuration+=(
    [database]="${MURMUR_HOME}/murmur.sqlite"
    [dbDriver]='QSQLITE'
    [;sqlite_wal]='0' # SQLite write-ahead log
  )

  # security stuff
  configuration+=(
    [allowping]="${MURMUR_INI_ALLOWPING:-true}"
    [;autobanAttempts]='10'
    [;autobanTime]='300'
    [;autobanTimeframe]='120'
    [kdfIterations]='-1' # only change this value if you know what you are doing
    [legacyPasswordHash]='false'
    [;obfuscate]='false'
    [;sendversion]='true'
    [serverpassword]="${MURMUR_INI_SERVERPASSWORD}"
    [uname]='murmur'
  )

  # connectivity
  configuration+=(
    [bandwidth]="${MURMUR_INI_BANDWIDTH:-72000}"
    [bonjour]='false'
    [host]='0.0.0.0' # listen on all interfaces
    [port]='64738'
    [;sslCiphers]='EECDH+AESGCM:EDH+aRSA+AESGCM:DHE-RSA-AES256-SHA:DHE-RSA-AES128-SHA:AES256-SHA:AES128-SHA'
    [;timeout]='30'
  )
  if [ -e ${MURMUR_HOME}/cert.pem ] && [ -e ${MURMUR_HOME}/key.pem ]; then
    configuration[sslCert]="${MURMUR_HOME}/cert.pem" # SSL certificate
    configuration[sslKey]="${MURMUR_HOME}/key.pem" # SSL private key
    [ ! -z "${MURMUR_INI_SSLPASSPHRASE}" ] && configuration[sslPassPhrase]="${MURMUR_INI_SSLPASSPHRASE}" # optional SSL passphrase
    if [ -e ${MURMUR_HOME}/class1.intermediate.pem ]; then
      configuration[sslCA]="${MURMUR_HOME}/class1.intermediate.pem" # optional intermediate certificate
    else
      echo 'WARN: No intermediate certificate found ...'
    fi
  else
    echo 'WARN: SSL certificate or private key missing. Using self signed certificate ...'
  fi
  if [ -e ${MURMUR_HOME}/dh.pem ]; then
    echo 'INFO: Diffie-Hellman parameters file found ...'
    configuration[sslDHParams]="${MURMUR_HOME}/dh.pem" # PEM-encoded file with Diffie-Hellman parameters
  else
    configuration[sslDHParams]="${MURMUR_INI_SSLDHPARAMS:-@ffdhe2048}" # named set of Diffie-Hellman parameters
  fi

  # users and channels
  configuration+=(
    [;allowhtml]='true'
    [;certrequired]='false'
    [;channelcountlimit]='1000'
    [;channelname]='[ \-=\w\#\[\]\{\}\(\)\@\|]+'
    [;channelnestinglimit]='10'
    [;defaultchannel]='0'
    [;imagemessagelength]='131072' # maximum length in bytes
    [messageburst]="${MURMUR_INI_MESSAGEBURST:-5}"
    [messagelimit]="${MURMUR_INI_MESSAGELIMIT:-1}"
    [;opusthreshold]='100'
    [;rememberchannel]='true'
    [;textmessagelength]='5000' # maximum length in bytes
    [;username]='[-=\w\[\]\{\}\(\)\@\|\.]+'
    [users]="${MURMUR_INI_USERS:-100}" # maximum number of users
    [;usersperchannel]='0' # the default is 0, for no limit
  )

  # server registration
  configuration+=(
    [;registerHostname]=''
    [;registerLocation]=''
    [;registerName]='' # also used as root channel name
    [;registerPassword]='' # an empty value disable registration
    [;registerUrl]=''
  )

  # miscellaneous
  configuration+=(
    [logdays]='-1' # disable logging to the database
    [;suggestPositional]=''
    [;suggestPushToTalk]=''
    [;suggestVersion]=''
    [welcometext]="${MURMUR_INI_WELCOMETEXT}"
  )
}

# initialize Murmur home directory
echo "INFO: Initializing Murmur home directory ${MURMUR_HOME} ..."
mkdir -p ${MURMUR_HOME}
chmod 755 ${MURMUR_HOME}
chown murmur:murmur ${MURMUR_HOME}
fileNames=( 'murmur.sqlite' 'cert.pem' 'key.pem' 'class1.intermediate.pem' 'dh.pem' )
for fileName in "${fileNames[@]}"; do
  if [ -e ${MURMUR_HOME}/${fileName} ]; then
    chmod 640 ${MURMUR_HOME}/${fileName}
    chown murmur:murmur ${MURMUR_HOME}/${fileName}
  fi
done

# create configuration file murmur.ini - https://wiki.mumble.info/wiki/Murmur.ini
echo 'INFO: Creating configuration file murmur.ini ...'
printf '%s\n' '; Murmur configuration file.' ';' > /etc/murmur.ini
declare -A iniSettings && get_config iniSettings
for iniKey in "${!iniSettings[@]}"; do
  iniValue=${iniSettings[$iniKey]}
  # escape special characters
  iniValue=${iniValue//'\'/'\\'} && iniValue=${iniValue//'"'/'\"'}
  # quote values when using spaces or commas
  if [[ "${iniValue}" == *" "* ]] || [[ "${iniValue}" == *","* ]]; then
    iniValue=\"${iniValue}\"
  fi
  echo ${iniKey}=${iniValue} >> /etc/murmur.ini
done
chmod 644 /etc/murmur.ini
chown root:root /etc/murmur.ini

# set SuperUser password
echo 'INFO: Setting SuperUser password ...'
su-exec murmur /usr/bin/murmurd -v -fg -ini /etc/murmur.ini -supw ${MURMUR_SUPW:-changeme} > /dev/null 2>&1 || true

# launch Murmur server
if [ $# -eq 0 ]; then
  exec /usr/local/bin/murmur-helper.sh su-exec murmur /usr/bin/murmurd -v -fg -wipelogs -ini /etc/murmur.ini
fi

exec "$@"
