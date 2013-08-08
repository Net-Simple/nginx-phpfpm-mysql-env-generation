#!/bin/bash

#######################################################################################
#                                                                                     #
# Предварительно необходимо использовать скрипт установки ПО на сервер или установить #
# его самостоятельно                                                                  #
# Скрипт автоматического создания окружения для php-приложения, версия 2.             #
# Создается пользователь, все необходимые каталоги, устанавливаются права             #
# Создается пользователь и база данных MySQL                                          #
# Создаются все необходимые конфигурационные файлы (nginx, php5-fpm, backup)          #
# Перезапускаются сервисы (nginx, php5-fpm)                                           #
# На e-mail администратора сайта высылается уведомление с всеми параметрами           #                                                        #
#                                                                                     #
# Скрипт разработан в компании Net-Simple. Разрешено свободное использование          #
# http://net-simple.ru info@net-simple.ru                                             #
#                                                                                     #
#######################################################################################

###### ПЕРЕМЕННЫЕ ИСПОЛЬЗУЕМЫЕ В СКРИПТЕ ######

USER="" # Новый пользователь (системный, MySQL, прописывается как домен в NGINX и пул в php-fpm)
USER_EMAIL="" # Адрес e-mail администратора нового сайта
MYSQL_PASS="" # Генерируемый пароль для пользователя MySQL
SFTP_PASS="" # Генерируемый пароль для доступа к каталогам нового сайта по SFTP
MYSQL_ROOT_PASS="" # Пароль пользователя root MySQL
MYSQL_DB="" # База данных MySQL
TIMEZONE="Europe/Moscow" 
CRON_BACKUP="0  3    * * *   $USER   " # Время и пользователь для создания резервных копий
SERVER_IP="" # IP-адрес сервера
SFTP_PORT=`grep -r 'Port' /etc/ssh/sshd_config | awk '{print $2}'` # Определяем SFTP
PMA_ADDR="$USER/PhpMyAdmin" # Адрес PhpMyAdmin
SFTP_GROUP=`grep -r 'Match Group' /etc/ssh/sshd_config | awk '{print $3}'` # Группа, члены которой имеют право на подключение по sftp

###### ПОЛУЧЕНИЕ НЕОБХОДИЫХ ДАННЫХ ######

	clear
	read -p "Введите домен сайта:                            " USER
	read -p "Введите e-mail администратора нового сайта:     " USER_EMAIL
	read -p "Введите пароль пользователя root MySQL:         " MYSQL_ROOT_PASS

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

	# Определяем $SFTP_GROUP


###### ПРОВЕРКИ КОРРЕКТНОСТИ ВВОДА ИНФОРМАЦИИ ######

	# Проверка корректности ввода домена сайта
	verify=`echo $USER | grep -E "[[:alnum:]]+\.{1}([A-Za-z]+)$"`
	if [ -z $verify ];
		then
			echo "Error: Домен сайта $USER введен некорректно !!!" 
			exit 1
		fi

	# Проверка на сущеcтвование системного пользователя
	if  grep $USER /etc/passwd > /dev/null
		then
			echo "$n Пользователь $USER уже существует (домен сайта = системный пользователь)" 
			exit 0
		fi


#        # Проверка корректности ввода email администратора
#        verify=`echo $USER_EMAIL |grep -E "[[:alnum:]]+@[[:alnum:]]+\.{1}([A-Za-z]+)$"`
#               if [ -z $verify ]; then
#               echo "Error: E-mail администратора $USER_EMAIL введен некорректно !!!" 
#               exit 1
#        fi

###### ГЕНЕРАЦИЯ ПАРОЛЕЙ ######

	# Генерация пароля пользователя SFTP
	SFTP_PASS=`pwgen -c -n -y 18 1`

	# Генерация пароля пользователя MySQL
	MYSQL_PASS=`pwgen -c -n -y 18 1`

##### СОЗДАНИЕ ПОЛЬЗОВАТЕЛЯ И КАТАЛОГОВ ДЛЯ НОВОГО САЙТА ######

	# Создаем необходимые каталоги
	mkdir -p /home/$USER/www/public_html
	mkdir -p /home/$USER/www/tmp
	mkdir -p /home/$USER/www/backups
	
	# Создаем пользователя/группу и задаем ему предварительно сгенерированный пароль
	groupadd $USER
	useradd $USER -G $SFTP_GROUP -g $USER -s /bin/false -d /home/$USER/ # Создаем пользователя
	echo -e ""$SFTP_PASS"\n"$SFTP_PASS"" | passwd --quiet $USER

	# Назначаем владельцем домашнего каталога пользователя root. Необходимо для chroot SFTP
	chown root:$SFTP_GROUP /home/$USER

	# Назначаем владельца и права на каталоги
	chown -R $USER:$USER "/home/$USER/www"

	find "/home/$USER/www/public_html" -type d -exec chmod 0755 '{}' \;
	find "/home/$USER/www/public_html" -type f -exec chmod 0644 '{}' \;

	find "/home/$USER/www/backups" -type d -exec chmod 0755 '{}' \;
	find "/home/$USER/www/backups" -type f -exec chmod 0644 '{}' \;

	find "/home/$USER/www/tmp" -type d -exec chmod 0755 '{}' \;
	find "/home/$USER/www/tmp" -type f -exec chmod 0777 '{}' \;


###### СОЗАДНИЕ БАЗЫ ДАННЫХ ДЛЯ НОВОГО САЙТА ######

	# Заменяем точку в имени на подчеркивание, т.к. MySQL иначе выдает ошибку
	MYSQL_DB=`echo ${USER//./_}`

	# Создаем базу и пользователя, даем права
	mysql -u root -p"$MYSQL_ROOT_PASS" -e "CREATE DATABASE IF NOT EXISTS $MYSQL_DB; GRANT ALL PRIVILEGES ON  $MYSQL_DB.* TO $MYSQL_DB@localhost;"

###### СОЗДАНИЕ КОНФИГУРАЦИОННОГО ФАЙЛА ВИРУТАЛЬНОГО ХОСТА NGINX ######

	echo "
upstream backend-$USER {server unix:/var/run/$USER-phpfpm-pool.sock}

server {
	# Указываем домен
    server_name $USER www.$USER;

    # Указываем каталог файлов сайта
    root /home/$USER/www/public_html;

    # Указываем пути и имена логов
    access_log /var/log/nginx/$USER-access.log;
	error_log /var/log/nginx/$USER-error.log;

	# Какие файлы будут переданы браузеру при обращениик домену
	index.html index.php;

	# Реализуем красивые ссылки для многих CMS
	location /
	{
        try_files $uri $uri/ /index.php?q=$uri&$args;

        open_file_cache max=1024 inactive=600s;
		open_file_cache_valid 2000s;
		open_file_cache_min_uses 1;
		open_file_cache_errors on;
	}

	# Закрываем доступ к файлами .htaccess и .htpassword
	location ~ /\.ht
	{
        deny all;
	}

	# Указываем, что не надо писать в лог, если фавикон не найден
	location = /favicon.ico
	{
        log_not_found off;
        access_log off;
	}

	# Разрешаем всем доступ к robots.txt и отключаем запись в лог обращений нему
	location = /robots.txt
	{
        allow all;
        log_not_found off;
        access_log off;
	}

	# Передаём обработку PHP-скриптов PHP-FPM
	location ~ \.php$
	{
		# Если файл не найден или ссылка не открывается, то будет открыта главная страница
        try_files $uri =/;

        # PHP-FPM слушает на Unix сокете
        fastcgi_pass   unix:/var/run/$USER-phpfpm-pool.sock;

        # Использовать cache зона one
        fastcgi_cache  one;

        # Помещать страницу в кеш, после 3-х использований.
        fastcgi_cache_min_uses 3;

        # Кешировать перечисленные ответы в течении 5 минут
        fastcgi_cache_valid 200 301 302 304 5m;

        # Формат ключа кеша - по этому ключу nginx находит правильную страничку
        fastcgi_cache_key "$request_method|$host|$request_uri";

        # Если не использовать эту опцию - то в форумах все будут сидеть под именем первого вошедшего на форум
        # fastcgi_hide_header "Set-Cookie";

        # Этот запрос заставит nginx кешировать все что проходит через него
        # fastcgi_ignore_headers "Cache-Control" "Expires";

        fastcgi_index  index.php;

        # fastcgi_intercept_errors on; # только на период тестирования

        # Включаем параметры из /etc/nginx/fastcgi_param
        include fastcgi_params;

        # Путь к скрипту, который будет передан в php-fpm
        fastcgi_param       SCRIPT_FILENAME  $document_root$fastcgi_script_name;
        fastcgi_ignore_client_abort     off;
    }

    location ~* \.(jpg|jpeg|gif|png|ico|css|js|swf)$ {
		expires max;
		root /home/$USER/www/public_html;
	}
}
	" > /etc/nginx/sites-available//$USER.conf

###### СОЗДАНИЕ КОНФИГУРАЦИОННОГО ФАЙЛА PHP-FPM ######

	echo "
[$USER]

listen = /var/run/$USER-phpfpm-pool.sock
listen.mode = 0666
user = $USER
group = $USER
chdir = /home/$USER/www

php_admin_value[upload_tmp_dir] = /home/$USER/www/tmp
php_admin_value[upload_max_filesize] = 10M
php_admin_value[post_max_size] = 10M
php_admin_value[open_basedir] = /home/$USER/www/
php_admin_value[disable_functions] = exec,passthru,shell_exec,system,proc_open,popen,curl_multi_exec,parse_ini_file,show_source
php_admin_value[cgi.fix_pathinfo] = 0
php_admin_value[date.timezone] = Europe/Moscow
php_admin_value[session.save_path] = /home/$USER/www/tmp
php_admin_value[session.auto_start] = 0

slowlog = /var/log/phpfpm-slowlog/$USER-php-slow.log

pm = dynamic
pm.max_children = 10
pm.start_servers = 2
pm.min_spare_servers = 2
pm.max_spare_servers = 4

	" > /etc/php5/fpm/pool.d/$USER-phpfpm-pool.conf

###### СОЗДАНИЕ КОНФИГУРАЦИОННОГО ФАЙЛА РЕЗЕРВНОГО КОПИРОВАНИЯ ######

	echo "  
#!/bin/bash

OLD=2                                          # Сколько дней хранить резервные копии
DATE=`date '+%F_%H-%M'`                        # Формат даты

# Создаем каталог под новый бекап

mkdir /home/$USER/www/backups/$DATE
cd /home/$USER/www/backups/$DATE

# Создаем и архивируем резервную копию БД пользователя

mysqldump -u '$USER' -p'$MYSQL_PASS' --skip-lock-tables '$MYSQL_DB' > DB-$MYSQL_DB.sql;

tar -cjf ./DB-$MYSQL_DB.tar.bz2 ./DB-$MYSQL_DB.sql
rm -rf ./DB-$MYSQL_DB.sql

# Создаем архив резервной копии файлов сайта

tar -cjf ./FILES-$USER.tar.bz2 /home/$USER/www/public_html

# Проверяем наличие бекапов старее, чем определено в OLD и удаляем их

find /home/$USER/backups -mtime +$OLD -exec rm '{}' \;

	" > /home/$USER/www/backups/$USER-backup.sh

	# Делаем скрипт резервного копирования исполняемым
	chmod +x /home/$USER/www/backups/$USER-backup.sh

	# Меняем владельца скрипта на пользователя сайта
	chown -R $USER:$USER /home/$USER/www/backups/$USER-backup.sh

	# Добавляем задание резервного копирования в crontab
	echo "$CRON_BACKUP sh /home/$USER/www/backups/$USER-backup.sh " >> /etc/crontab

###### ПЕРЕЗАПУСК ДЕМОНОВ ######

	service nginx reload
	service php5-fpm reload

###### ВЫВОД И ОТПРАВКА ПО E-MAIL УЧЕТНЫХ И ПРОЧИХ НЕОБХОДИЫМХ ДАННЫХ ######

	echo " 
	Уважаемый, администратор сайта $USER !

	Для Вас было подготовлено необходимое окружение для размещения веб-сайта $USER .

	Ниже приведены параметры окружения:

	Сайт: $USER
	Пользователь SFTP: $USER
	Пароль пользователя SFTP: $SFTP_PASS
	База данных MySQL: $MYSQL_DB
	Пользователь MySQL: $MYSQL_DB
	Пароль пользователя MySQL: $MYSQL_PASS

	Обращаем Ваше внимание, что для подключения к серверу необходимо использовать следующие параметры:

	IP-адрес сервера: $SERVER_IP
	Порт SFTP: $SFTP_PORT
	Адрес PhpMyAdmin: $PMA_ADDR

	С Уважением,
	Техническая поддержка Net-Simple.
	https://net-simple.ru

	" > /home/$USER/$USER-site.txt

	chown -R $USER:$USER /home/$USER/$USER-site.txt

	cat /home/$USER/$USER-site.txt
	cat /home/$USER/$USER-site.txt | iconv -f utf8 -t koi8-r | mail -s "Net-Simple: $USER site settings" $USER_EMAIL

exit