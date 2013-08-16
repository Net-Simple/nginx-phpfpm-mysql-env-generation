#!/bin/bash

#######################################################################################
#                                                                                     #
# Скрипт автоматической установки ПО и базовых настроек безопасности                  #
# для последующего развертывания PHP-приложений.                                      #                                             #
#                                                                                     #
# Скрипт разработан в компании Net-Simple. Разрешено свободное использование          #
# http://net-simple.ru info@net-simple.ru                                             #
#                                                                                     #
#######################################################################################

###### ПЕРЕМЕННЫЕ ИСПОЛЬЗУЕМЫЕ В СКРИПТЕ ######

SSH_PORT=""			# Устанавливаемый порт для подключения по SSH-протоколу
SFTP_GROUP=""		# Группа, пользователи которой будут иметь доступ к SFTP
SUDO_USER=""		# Административный пользователь с правами на sudo 
SUDO_USER_PASS=""	# Пароль sudoer'а
SUDO_GROUP="sudo"	# Группа судоеров
ROOT_PASS=""		# Новый пароль пользователя root
SERVER_IP="" 		# IP-адрес сервера
ADMIN_EMAIL=""		# E-Mail администратора сервера

###### ПОЛУЧЕНИЕ НЕОБХОДИЫХ ДАННЫХ ######

clear
read -p "Введите новый порт SSH:											" SSH_PORT
read -p "Введите название группы, которой будет дан доступ по SFTP:			" SFTP_GROUP
read -p "Введите новый пароль пользователя root:							" ROOT_PASS
read -p "Введите имя пользователя администратора сервера:					" SUDO_USER
read -p "Введите e-mail администратора сервера:								" ADMIN_EMAIL

# Определяем IP сервера
DEV="eth0";
if [ "$DEV" = "" ] 
	then 
		echo "No eth0 Device?"; 
		exit 1; 
	else 
		ETH0="`/sbin/ifconfig $DEV | awk -F: '/inet addr/ {print $2}'`"; 
		SERVER_IP="`echo $ETH0 | awk -F" " '{print $1}'`"; 
	fi

###### НАСТРОЙКИ ОС ######

# Обновляем систему
apt-get update && apt-get upgrade -y

# Добавляем группу для пользователей SFTP
groupadd $SFTP_GROUP

### Делаем резервную копию оригинальных настроек SSH-сервера и заменяем на свои
mv /etc/ssh/sshd_config /etc/ssh/sshd_config.orig

echo "

Port $SSH_PORT
ListenAddress 0.0.0.0
Protocol 2

HostKey /etc/ssh/ssh_host_rsa_key
HostKey /etc/ssh/ssh_host_dsa_key
HostKey /etc/ssh/ssh_host_ecdsa_key

UsePrivilegeSeparation yes

KeyRegenerationInterval 3600
ServerKeyBits 768

SyslogFacility AUTH
LogLevel INFO

LoginGraceTime 1m
PermitRootLogin no
StrictModes yes

PubkeyAuthentication yes
AuthorizedKeysFile      %h/.ssh/authorized_keys

IgnoreRhosts yes
RhostsRSAAuthentication no
HostbasedAuthentication no

PermitEmptyPasswords no

ChallengeResponseAuthentication no

PasswordAuthentication yes

X11Forwarding yes
X11DisplayOffset 10
PrintMotd no
PrintLastLog yes
TCPKeepAlive yes
Compression yes

MaxStartups 10

AcceptEnv LANG LC_*

Subsystem sftp internal-sftp

UsePAM yes

Match Group $SFTP_GROUP
ChrootDirectory %h
ForceCommand internal-sftp

" > /etc/ssh/sshd_config

###### ТЮНИНГУЕМ ЯДРО ######

# Защита от SYN-флуда
echo net.ipv4.tcp_syncookies = 1 >> /etc/sysctl.conf

echo net.ipv4.icmp_echo_ignore_all = 1 >> /etc/sysctl.conf
echo net.ipv4.tcp_synack_retries = 1 >> /etc/sysctl.conf
# Защита от спуфинга
echo net.ipv4.conf.all.rp_filter = 1  >> /etc/sysctl.conf
echo net.ipv4.conf.default.rp_filter = 1 >> /etc/sysctl.conf

echo net.ipv4.tcp_keepalive_time = 60 >> /etc/sysctl.conf
echo net.ipv4.tcp_keepalive_intvl = 10 >> /etc/sysctl.conf
echo net.ipv4.tcp_keepalive_probes = 5 >> /etc/sysctl.conf
# Запрещаем маршрутизацию от источника
echo net.ipv4.conf.all.accept_source_route = 0 >> /etc/sysctl.conf
echo net.ipv4.conf.default.accept_source_route = 0 >> /etc/sysctl.conf
echo net.ipv4.conf.all.accept_redirects = 0 >> /etc/sysctl.conf
# Защита от smurf-атак
echo net.ipv4.icmp_echo_ignore_broadcasts = 1 >> /etc/sysctl.conf
# Мы не маршрутизатор
echo net.ipv4.ip_forward = 0 >> /etc/sysctl.conf
echo net.ipv4.conf.all.send_redirects = 0 >> /etc/sysctl.conf
echo net.ipv4.conf.default.send_redirects = 0 >> /etc/sysctl.conf
# Увеличиваем максимальный размер TCP-буферов
echo net.core.somaxconn = 4096  >> /etc/sysctl.conf
echo net.ipv4.tcp_max_orphans = 2255360  >> /etc/sysctl.conf
echo net.ipv4.tcp_fin_timeout = 10  >> /etc/sysctl.conf
echo kernel.msgmnb = 65536  >> /etc/sysctl.conf
echo kernel.msgmax = 65536  >> /etc/sysctl.conf
echo kernel.shmmax = 494967295  >> /etc/sysctl.conf
echo kernel.shmall = 268435456  >> /etc/sysctl.conf
echo net.ipv4.tcp_max_syn_backlog = 4096 >> /etc/sysctl.conf
echo net.core.netdev_max_backlog = 30000 >> /etc/sysctl.conf
echo net.ipv4.tcp_window_scaling = 1 >> /etc/sysctl.conf
# Защита от неправильных ICMP-сообщений
echo net.ipv4.icmp_ignore_bogus_error_responses = 1 >> /etc/sysctl.conf
# Включаем ExecShield
echo kernel.exec-shield = 1 /etc/sysctl.conf
echo kernel.randomize_va_space = 1 /etc/sysctl.conf

###### УСТАНАВЛИВАЕМ НУЖНОЕ ПО ######

### Устанавливаем MariaDB 10
# apt-get install software-properties-common -y
# apt-key adv --recv-keys --keyserver keyserver.ubuntu.com 0xcbcb082a1bb943db
# add-apt-repository 'deb http://mirror.timeweb.ru/mariadb/repo/10.0/ubuntu raring main'

touch /etc/apt/sources.list.d/mariadb.list
echo "
# MariaDB 10.0 repository list - created 2013-08-16 15:10 UTC
# http://mariadb.org/mariadb/repositories/
deb http://mirror.timeweb.ru/mariadb/repo/10.0/ubuntu raring main
deb-src http://mirror.timeweb.ru/mariadb/repo/10.0/ubuntu raring main
" > /etc/apt/sources.list.d/mariadb.list

# Добавляем PUB-key репозитрия TimeWeb для установки MariaDB
apt-key adv --recv-keys --keyserver keyserver.ubuntu.com 0xcbcb082a1bb943db

# Еще раз обновляем список пакетов и систему
apt-get update && apt-get upgrade -y

# Устанавливаем ПО, необходимое для работы сайтов
apt-get install mariadb-server mariadb-client -y
apt-get install mc software-properties-common htop iptraf nginx php5-cli php5-common php5-mysql php5-gd php5-fpm php5-cgi php-pear php5-mcrypt php-apc memcached php5-memcached postfix pwgen -y

###### БАЗОВЫЕ НАСТРОЙКИ ######

### Создание пользователя SUDOER'а

# Генерация пароля пользователя SFTP
SUDO_USER_PASS=`pwgen -c -n -y 25 1`

# Создаем пользователя/группу и задаем ему предварительно сгенерированный пароль
groupadd $SUDO_USER
useradd $SUDO_USER -g $SUDO_USER -G $SUDO_GROUP -s /bin/bash -m -b -p"$SUDO_USER_PASS" # Создаем пользователя

# Назначаем владельцем домашнего каталога пользователя root. Необходимо для chroot SFTP
chown $SUDO_USER:$SUDO_USER /home/$SUDO_USER

# Создаем каталог для логов медленных запросов php
mkdir /var/log/phpfpm-slowlog

### NGINX

# Копируем оригинальный конфиг в отдельный файл
mv /etc/nginx/nginx.conf /etc/nginx/nginx.conf.orig

# Создаем свой основной конфиг для Nginx
echo "
# Пользователь с правами которого работает nginx
user www-data;

# Директива задаёт приоритет рабочих процессов от -20 до 20 (отрицательное число означает более высокий приоритет). 
worker_priority -5;

# Уменьшает число системных вызовов gettimeofday(), что приводит к увеличению производительности
timer_resolution 100ms;

# Рекомендуется устанавливать по числу ядер
worker_processes 4;

pid /var/run/nginx.pid;
worker_rlimit_nofile 8192;

events {

# Максимальное число подключений к серверу на один worker-процесс
worker_connections 1024;

# Эффективный метод обработки соединений, используемый в Linux 2.6+
use epoll;
}

http {
# Базовые настройки
    
    # Организовываем кеш для FastCGI сервера, я использую раздел в ram
    fastcgi_cache_path /tmp/fcgi-cache/ levels=1:2   keys_zone=one:50m;


    # Директива описывает зону, в которой хранятся состояния сессий. 
    # Значения сессий определяется заданной переменной. 
    # В данном случае состояния сессий хранятся в зоне "two" размером 
    # 10 мегабайт и средняя скорость запросов для этой зоны не может 
    # более 5 запросов в секунду.     
    limit_req_zone $binary_remote_addr zone=two:10m  rate=5r/s;


    # Используем sendfile, но осторожно, если надо отдавать большие файлы, то sendfile случается вредит
    sendfile on;

    # Расширяем буфера отдачи
    #output_buffers   32 512k;

    # Ограничиваем размер сегмента отправляемой за одну блокируемую отдачу
    sendfile_max_chunk  128k;

    # Буфер отдачи которы используется для обрабатываемых данных
    postpone_output  1460;

    # Размер хеша для доменных имен.
    server_names_hash_bucket_size 64;

    # Размер данных принемаемых post запросом
    client_max_body_size 15m;
        tcp_nopush on;
        tcp_nodelay on;
        keepalive_timeout 5 5;
        types_hash_max_size 2048;
        # При ошибках не говорим врагу версию nginx
        server_tokens off;
        include /etc/nginx/mime.types;
        default_type application/octet-stream;

    # Максимальный размер буфера для хранения тела запроса клиента
	client_body_buffer_size 1K;

	# Максимальный размер буфера для хранения заголовков запроса клиента
	client_header_buffer_size 1k;

	# Количество и размер буферов для чтения большого заголовка запроса клиента
	large_client_header_buffers 2 1k;

	# Таймаут при чтении тела запроса клиента
	client_body_timeout 10;

	# Таймаут при чтении заголовка запроса клиента
	client_header_timeout 10;

	# Таймаут при передаче ответа клиенту
	send_timeout 10;

	# Настройка логов
	access_log /var/log/nginx/access.log;
	error_log /var/log/nginx/error.log;

	# Настройки сжатия
    gzip on;
    gzip_disable "msie6";
    ssi on;
    gzip_min_length 1100;
  	gzip_buffers 64 8k;
  	gzip_comp_level 3;
  	gzip_http_version 1.1;
  	gzip_proxied any;
  	gzip_types text/plain application/xml application/x-javascript text/css;

	# Настройка виртуальных доменов
	include /etc/nginx/conf.d/*.conf;
	include /etc/nginx/sites-enabled/*.conf;
}
" > /etc/nginx/nginx.conf

### Немного повышаем безопасность

echo php_admin_value session.auto_start 0 >> /etc/php5/fpm/php.ini
echo cgi.fix_pathinfo = 0 >> /etc/php5/fpm/php.ini 

echo "
apc.enabled=1
apc.shm_segments=1
apc.shm_size=32
apc.ttl=7200
apc.user_ttl=7200
apc.num_files_hint=1024
apc.mmap_file_mask=/tmp/apc.XXXXXX
apc.max_file_size = 200M
apc.post_max_size = 200M
apc.upload_max_filesize = 200M
apc.enable_cli=1
apc.rfc1867=1
" >> /etc/php5/fpm/conf.d/20-apc.ini

###### ВЫВОД И ОТПРАВКА ПО E-MAIL УЧЕТНЫХ И ПРОЧИХ НЕОБХОДИЫМХ ДАННЫХ ######

	echo " 
	Уважаемый, администратор сервера !

	Для Вас было подготовлено необходимое окружение для размещения веб-сайтов на PHP .

	Ниже приведены параметры окружения:

	Пароль пользователя root:										$ROOT_PASS
	Имя пользователя администратора сервера:						$SUDO_USER
	Пароль администратора сервера (пользователь: $SUDO_USER):		$SUDO_USER_PASS
	Порт SSH/SFTP:													$SSH_PORT
	Группа пользователей, имеющих доступ по SFTP:					$SFTP_GROUP

	Обращаем Ваше внимание, что для подключения к серверу необходимо использовать следующие параметры:

	IP-адрес сервера: $SERVER_IP

	С Уважением,
	Техническая поддержка Net-Simple.
	https://net-simple.ru

	" > /home/$SUDO_USER/server.txt

	chown -R $SUDO_USER:$SUDO_USER /home/$SUDO_USER/server.txt

	cat /home/$SUDO_USER/server.txt
	cat /home/$SUDO_USER/server.txt | iconv -f utf8 -t koi8-r | mail -s "Net-Simple: $USER site settings" $ADMIN_EMAIL

exit
