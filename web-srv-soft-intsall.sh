#!/bin/bash

#######################################################################################
#                                                                                     #
# Скрипт автоматической установки ПО и базовых настроек безопасности                  #
# для последующего развертывания PHP-приложений.                                      #
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

SSH_PORT="" # Устанавливаемый порт для подключения по SSH-протоколу
SFTP_GROUP="" # Группа, пользователи которой будут иметь доступ к SFTP

###### ПОЛУЧЕНИЕ НЕОБХОДИЫХ ДАННЫХ ######

clear
read -p "Введите новый порт SSH:                            " SSH_PORT
read -p "Введте название группы, которой будет дан доступ по SFTP: " SFTP_GROUP

###### НАСТРОЙКИ ОС ######

# Обновляем систему
apt-get update && apt-get upgrade

# Добавляем группу для пользователей SFTP
groupadd $SFTP_GROUP

# Делаем резервную копию оригинальных настроек SSH-сервера и заменяем на свои
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