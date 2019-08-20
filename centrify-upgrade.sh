#! /bin/bash
#
# Title: centrify-upgrade.sh
# Author: David Thiele <jdthiele@gmail.com>
# Date Created: 2018-11-13
# Date Revised: 2019-08-20
# Revision: 1.1
# Purpose: automate the centrify install/upgrade process
#
# Logic;
#
# The output is tee to stdout and the log file
# Calling scripts: 
# Called scripts: 
# Exit code: 0 indicates all went well.
#            1 indicates an error.
# Constants:
PKG_DIR=/nfsshare/centrify/
TMP_DIR=/var/tmp
YOUR_ORG=ORG_NAME_HERE

# Variables:
UPGRADE=0 # set to 1 to disable agent upgrades
DACONF=0 # set to 1 to disable config enforcement

#############
# Functions
#############
# None

#function one {
#   return 0
#}

#############
# Main
#############

## Find the OS release
cat /etc/*release | grep Solaris | awk '{print $3}' | grep 11 > /dev/null && REL=S11
cat /etc/*release | grep "Red Hat" > /dev/null && { REL=RHEL; }
cat /etc/*release | grep Ubuntu > /dev/null && { REL=Ubuntu; }

if [ $REL = S11 ]; then
  [ `pkginfo -l CentrifyDC | grep VERSION | awk '{print $2}'` = "5.5.3-704" ] && { echo "already at the latest version"; UPGRADE=1; }
  PKG=centrify-infrastructure-services-19.2-sol10-sparc.tgz
elif [ $REL = "RHEL" ]; then
  [ `yum info centrifydc 2>&1 | grep Version | awk '{print $3}'` = "5.5.3" ] && { echo "already at the latest version"; UPGRADE=1; }
  PKG=centrify-infrastructure-services-19.2-rhel5-x86_64.tgz
elif [ $REL = "Ubuntu" ]; then
  PKG=centrify-infrastructure-services-19.2-deb8-x86_64.tgz
else
  echo "I am not sure what OS you are running this from. Exitting..."
  exit 1
fi

if [ $UPGRADE = 0 ]; then
  # copy and extract the agent installer
  cd ${TMP_DIR}
  cp ${PKG_DIR}/${PKG} .
  tar -xzvf ${PKG}
  
  # if dacontrol is already installed, disable it so we can do an upgrade
  if [ -x /sbin/dacontrol ]; then
    dacontrol -da
    dacontrol -s
  elif [ -x /usr/sbin/dacontrol ]; then
    dacontrol -da
    dacontrol -s
  fi
  
  # do the upgrade
  ./install.sh --ent-suite || { echo; echo; echo "install/upgrade FAILED... exitting..."; exit 1; }
fi

if [ $DACONF = 0 ]; then
  # check daconfig to see if desired configs are in place
  DACONF_OUT=`dainfo`
  echo "$DACONF_OUT" | grep "DA_${YOUR_ORG}" > /dev/null || dacontrol -i DA_${YOUR_ORG}
  echo "$DACONF_OUT" | grep "DirectAudit NSS module" | awk '{print $4}' | grep Active > /dev/null || dacontrol -e
  echo "$DACONF_OUT" | grep "DirectAudit is not configured for per command auditing" && dacontrol -r
  for CMD in /bin/su /usr/bin/su /usr/bin/sudo /usr/share/centrifydc/bin/dzdo; do
    [ ${CMD} = /bin/su ] && ls -ld /bin | grep /usr/bin > /dev/null && continue # if /bin is a symlink to /usr/bin, skip it
    [ -x ${CMD} ] && { echo "$DACONF_OUT" | egrep '^   '${CMD}'$' > /dev/null || dacontrol -e -c ${CMD}; } # if cmd exists and isn't audited, start auditing
  done
fi

# Exit with a code of 0 indicating all went well
exit 0
