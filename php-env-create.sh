#!/bin/bash
#######################################################################################
#                                                                                     #
# Скрипт автоматического создания окружения для php-приложения, версия 2.             #
# Создается системный пользователь, все необходимые каталоги, устанавливаются права   #
# Создается пользователь и база данных MySQL                                          #
# Создаются все необходимые конфигурационные файлы (nginx, php5-fpm, backup)          #
# Перезапускаются сервисы (nginx, php5-fpm)                                           #
# На e-mail администратора сайта и администратора сервера высылается уведомление с    #
# всеми параметрами                                                                   #
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
SFTP_PORT=`grep -r 'Port' /etc/ssh/sshd_config | cut -c5-10` # Порт SFTP
PMA_ADDR="$USER/PhpMyAdmin" # Адрес PhpMyAdmin
GROUP=sftp_users # Группа, члены которой имеют право на подключение по sftp

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
		useradd $USER -G $GROUP -g $USER -s /bin/false -d /home/$USER/www # Создаем пользователя
        echo -e ""$SFTP_PASS"\n"$SFTP_PASS"" | passwd --quiet $USER

        # Назначаем владельца и права на каталоги
        chown -R $USER:$USER "/home/$USER/www";

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
    server_name $USER www.$USER;

    root /home/$USER/www/public_html;

    access_log /var/log/nginx/$USER-access.log;
	error_log /var/log/nginx/$USER-error.log;

	# Типовые настройки общие для всех доменов (если не захочется экзотики)
	index.html index.php;

	# Реализуем красивые ссылки для Drupal (и для ряда других CMS)
	location /
	{
        try_files $uri $uri/ /index.php?q=$uri&$args;
	}

	# Закрываем доступ к файлами .htaccess и .htpassword
	location ~ /\.ht
	{
        deny all;
	}

	location = /favicon.ico
	{
        log_not_found off;
        access_log off;
	}

	location = /robots.txt
	{
        allow all;
        log_not_found off;
        access_log off;
	}

	# Передаём обработку PHP-скриптов PHP-FPM
	location ~ \.php$
	{
        try_files $uri =/;

        # PHP-FPM слушает на Unix сокете
        fastcgi_pass   unix:/var/run/$USER-phpfpm-pool.sock;

        # Использовать cache зона one
        fastcgi_cache  one;

        # Помещать страницу в кеш, после 3-х использований. Меньшее число вызвало у меня труднообъяснимые глюки на формах регистрации
        fastcgi_cache_min_uses 3;

        # Кешировать перечисленные ответы
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
				}
		" > /etc/nginx/sites-available//$USER.conf

###### СОЗДАНИЕ КОНФИГУРАЦИОННОГО ФАЙЛА PHP-FPM ######

        echo "
        	[$USER]

	        include=/etc/php5/fpm/templates/default.conf

        " > /etc/php5/fpm/pool.d/$USER-phpfpm-pool.conf

###### СОЗДАНИЕ КОНФИГУРАЦИОННОГО ФАЙЛА РЕЗЕРВНОГО КОПИРОВАНИЯ ######

        echo "  
        	
        	\'$USER'=$USER
        	include /etc/nginx/templates/backup.conf

        " > /home/$USER/www/backups/$USER-backup.sh

        chmod +x /home/$USER/www/backups/$USER-backup.sh

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
    	    техническая поддержка Net-Simple.
        	https://net-simple.ru
        " > /home/$USER/$USER-site.txt

        cat /home/$USER/$USER-site.txt
        cat /home/$USER/$USER-site.txt | iconv -f utf8 -t koi8-r | mail -s "Net-Simple: $USER site settings" $USER_EMAIL tia@net-simple.ru

exit

bewitchment.ru