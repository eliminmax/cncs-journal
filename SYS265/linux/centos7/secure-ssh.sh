# secure-ssh.sh
# author eliminmax

if [ "$EUID" -ne 0 ]; then
	echo -e "/033[1;31mThis script must be run as root./033[0m"
	exit 1
fi

username=$1

cd $(dirname $0)

adduser ${username}

mkdir -p /home/${username}/.ssh

if [ -f ../public-keys/id_rsa.pub ]; then
	cat ../public-keys/id_rsa.pub >> /home/${username}/.ssh/authorized_keys
else
	curl https://raw.githubusercontent.com/eliminmax/cncs_journal/master/SYS265/public-keys/id_rsa.pub >> /home/${username}/.ssh/authorized_keys || exit 2
fi

cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup
sed -i 's/ *#? *PermitRootLogin.*/PermitRootLogin no/g' /etc/ssh/sshd_config

chown -R /home/${username}/.ssh ${username}:
chmod 700  /home/${username}/.ssh/authorized_keys

