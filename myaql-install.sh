#!/bin/bash
############################################################
#
# The password of root will put to the /root/mysql_accoun.txt
#
############################################################
#mysql list must be updated when the new version discribute,if not it may not download the install packages.
mysql_list="5.5.54 5.6.35"

#select the version you want to install.
echo "step 1:Select the version of mysql :"
mysql_version=`select var in $mysql_list ; do echo $var; if [ "$var" != "" ]; then break; fi; done`
mysql_preversion=`echo $mysql_version | cut -d '.' -f 1-2`

#set the path of mysql
echo -e "step 2:Plese Enter the install path of mysql if set default path press ENTER "
read -p "(default:/usr/local/mysql-$mysql_version):" mysql_path
if [ "${mysql_path}" == "" ]
	then
	mysql_path=/usr/local/mysql-$mysql_version
fi

#get the discribute of Operating System.
export ifredhat=$(cat /proc/version | grep -i redhat)
export ifcentos=$(cat /proc/version | grep -i centos)
export ifubuntu=$(cat /proc/version | grep -i ubuntu)
export ifdebian=$(cat /proc/version | grep -i debian)

#summary the install infomation
echo "mysql version : ${mysql_version}"
echo "mysql path : ${mysql_path}"
read -p "Are you sure to begin to install mysql ? (y/N):" AskYN
if [ "$AskYN" != "y" ]
	then
	echo "Not sure to exit..."
	exit
fi

#set ${mysql_path} to /usr/local/mysql and set PATH
ln -sf $mysql_path /usr/local/mysql
if_exist=`cat /etc/profile | grep '/usr/local/mysql/bin'`
if [ "$if_exist" == "" ]
	then
	echo 'export PATH=$PATH:/usr/local/mysql/bin' >> /etc/profile
fi

. /etc/profile

#install the tool for mysql compile
if [[ "$ifredhat" != "" || "$ifcentos" != "" ]]
	then
	yum clean all
	yum -y install cmake ncurses-devel bzr gcc-c++ gcc bison make perl-Module-Install.noarch
	#create user for mysql
	groupadd mysql
	useradd -g mysql -s /sbin/nologin mysql
fi

if [[ "$ifubuntu" != "" || "$ifdebian" != "" ]]
	then
	apt-get update
	apt-get install cmake libncurses5-dev bison g++ build-essential -y
	groupadd mysql
	useradd -g mysql -s /bin/false mysql
fi

#download the source package of mysql
if [ ! -f mysql-${mysql_version}.tar.gz ]
	then
	wget -c http://mirror.bit.edu.cn/mysql/Downloads/MySQL-${mysql_preversion}/mysql-${mysql_version}.tar.gz
fi

rm -rf mysql-${mysql_version}
tar zxf mysql-${mysql_version}.tar.gz
cd mysql-${mysql_version}

#begin install mysql ,after 5.5 ,the compile tool using cmake
if [ "$mysql_preversion" == "5.1" ]
	then
	./configure --prefix=${mysql_path} --with-charset=utf8 --with-extral-charsets=all
	else
	cmake . -DCMAKE_INSTALL_PREFIX=${mysql_path} -DMYSQL_DATADIR=${mysql_path}/data -DSYSCONFDIR=${mysql_path}/my.cnf -DDEFAULT_CHARSET=utf8 -DDEFAULT_COLLATION=utf8_general_ci -DEXTRA_CHARSETS=all -DENABLED_LOCAL_INFILE=1 -DINSTALL_PLUGINDIR=${mysql_path}/plugin
fi

#use the most processes to make
CPU_NUM=$(cat /proc/cpuinfo | grep processor | wc -l)
if [ $CPU_NUM -gt 1 ];then
	make -j$CPU_NUM
	else
	make
fi

make install

#modify privileges of ${mysql_path}
chown mysql:mysql ${mysql_path} -R
if [ "${mysql_preversion}" == "5.1" ]
	then
	${mysql_path}/bin/mysql_install_db --datadir=${mysql_path}/data/ --basedir=${mysql_path} --user=mysql
	cp support-files/mysql.server /etc/init.d/mysqld
	else
	${mysql_path}/scripts/mysql_install_db --datadir=${mysql_path}/data/ --basedir=${mysql_path} --user=mysql
	cp -f ${mysql_path}/support-files/mysql.server /etc/init.d/mysqld
fi

cd ..
sed -i 's#^basedir=$#basedir=/usr/local/mysql#' /etc/init.d/mysqld
sed -i 's#^datadir=$#datadir=/usr/local/mysql/data#' /etc/init.d/mysqld

#set the configure file for mysql
cat > /etc/my.cnf <<END
	[client]
	port = 3306
	socket = /tmp/mysql.sock
	default-character-set = utf8
	[mysqld]
	port = 3306
	socket = /tmp/mysql.sock
	skip-external-locking
	key_buffer_size = 16M
	max_allowed_packet = 1M
	table_open_cache = 64
	sort_buffer_size = 512K
	net_buffer_length = 8K
	read_buffer_size = 256K
	read_rnd_buffer_size = 512K
	myisam_sort_buffer_size = 8M
	log-bin=mysql-bin
	binlog_format=mixed
	server-id = 1
	sql_mode=NO_ENGINE_SUBSTITUTION,STRICT_TRANS_TABLES
	character-set-server = utf8	
	collation-server = utf8_general_ci
	bind-address = 0.0.0.0
	[mysqldump]
	quick
	max_allowed_packet = 16M
	[mysql]
	no-auto-rehash
	[myisamchk]
	key_buffer_size = 20M
	sort_buffer_size = 20M
	read_buffer = 2M
	write_buffer = 2M
	[mysqlhotcopy]
	interactive-timeout
END

chmod 755 /etc/init.d/mysqld
/etc/init.d/mysqld start
if_exist=`cat /etc/rc.local | grep /etc/init.d/mysqld`
if [ "$if_exist" == "" ]
	then
	echo '/etc/init.d/mysqld start' >> /etc/rc.local
fi

echo "Begin to reset the password for mysql user!"

#set the random password from mysql root
random_s=''
random(){
	str=$1
	len=${#str}
	let i=$RANDOM%${len}
	random_s="${random_s}${str:$i:1}"
}

str1='~!@#%^&_+=-.,'
str2='abcdefghijklnmopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ'
str3='0123456789'
random $str2
random $str3
random $str1

for j in `seq 1 10`
	do
	let i=$RANDOM%3
	if [ "$i" == "0" ]
		then
		random $str1
	fi
	if [ "$i" == "1" ]
		then
		random $str2
	fi
	if [ "$i" == "2" ]
		then
		random $str3
	fi
done

echo "all root password is $random_s  \n mysql-user: vfaith password: vfaith!!! " > /root/mysql_account.txt
. /etc/profile
mysql << EOF
	drop database if exists test;
	use mysql
	delete from user where user='';
	update user set password=password("${random_s}") ;
	CREATE USER 'vfaith'@'%' IDENTIFIED BY 'vfaith';
	GRANT ALL PRIVILEGES ON *.* TO 'vfaith'@'%';
	commit;
	flush privileges;
	quit
EOF

echo "MySQL password had updated !"
echo "#############################################"
echo "The mysql path is $mysql_path"
echo "The configure file is /etc/my.cnf"
echo "The startup file is /etc/rc.local"
echo "You can find password of root at /root/mysql_account.txt!"
echo "#############################################"
echo "mysql-${mysql_version} install end"
