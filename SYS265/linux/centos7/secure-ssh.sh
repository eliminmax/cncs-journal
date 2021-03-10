# secure-ssh.sh
# author eliminmax

if [ "$EUID" -ne 0 ]; then
	echo "This script must be run as root."
	exit 1
fi
if [ "$#" -ne 1 ]; then
	echo -e "This script must take exactly 1 argument."
	exit 2
fi


username=$1

cd $(dirname $0)

adduser ${username}

mkdir -p /home/${username}/.ssh

if [ -f ../public-keys/id_rsa.pub ]; then
	cat ../public-keys/id_rsa.pub >> /home/${username}/.ssh/authorized_keys
else
	curl https://raw.githubusercontent.com/eliminmax/cncs_journal/master/SYS265/public-keys/id_rsa.pub >> /home/${username}/.ssh/authorized_keys || exit 3
fi

cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup
sed -i 's/ *#? *PermitRootLogin.*/PermitRootLogin no/g' /etc/ssh/sshd_config

chown -R ${username}: /home/${username}/.ssh
chmod 700  /home/${username}/.ssh/authorized_keys

