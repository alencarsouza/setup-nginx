#!/bin/bash -e
#
# ngnix.sh - Setup Ngnix with PHP-FPM
#
# Copyright (c) 2013 Junior Holowka <junior.holowka@gmail.com>
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.
#

# VHOSTS="/var/www"			> your workspace or htdocs                       
# HOST="host"				> /etc/hosts - (Ex: 127.0.0.1 host) 
# DOMAIN="project.com"		> domain.com                                     
# PARAMN="/app/webroot"		> some framework paramn (optional)               
#
#
# HOWTO: sudo ./ngnix.sh  host domain.com

# check for root privileges
if [ "$(id -u)" != "0" ]; then
   echo "You must run this script as root" 1>&2
   exit 1
fi

if [ -z "$1$2" ]; then
	echo "Usage: $0 [HOSTNAME] [DOMAIN]"
	exit 1;
fi



VHOSTS="/var/www"
PARAMN="/index"
HOST="$1"
DOMAIN="$2"


echo -e "\033[1m===> Installing nginx and php5-fpm ... \033[0m\n"
	apt-get install -y nginx-full php5-fpm
echo ""

echo -e "\033[1m> Creating reference to /etc/hosts ...\033[0m\n"
	sh -c 'echo "127.0.0.1			'${HOST}'	'${DOMAIN}'" >> /etc/hosts'
echo ""


echo -e "\033[1m===> Creating configuration file for nginx ... \033[0m\n"

touch /etc/nginx/sites-available/$DOMAIN

cat > /etc/nginx/sites-available/$DOMAIN<<-EOF

server {
    listen 80;

    set \$host_path "${VHOSTS}/${DOMAIN}";
    access_log    /var/log/nginx/$DOMAIN.access.log;
    error_log    /var/log/nginx/$DOMAIN.error.log;

    server_name $HOST $DOMAIN;
    root \$host_path$PARAMN;
	set \$bootstrap "index.php";
    
    charset UTF-8;

    location / {
        index index.html index.php;
        try_files \$uri \$uri/ /\$bootstrap?\$args;
        }

    # Deny access to some files/folders
    location = /nginx.conf { deny all; access_log off; }

    location ~ ^/(protected|framework|themes/\w+/views) {
        deny  all;
        }

    #avoid processing of calls to unexisting static files
    location ~ \.(js|css|png|jpg|gif|swf|ico|pdf|mov|fla|zip|rar)$ {
        try_files \$uri =404;
        }

    # pass the PHP scripts to FastCGI server listening on 127.0.0.1:9000
    location ~ \.php {
        fastcgi_split_path_info  ^(.+\.php)(.*)$;

        #let yii catch the calls to unexising PHP files
        set \$fsn /\$bootstrap;
        if (-f \$document_root\$fastcgi_script_name){
            set \$fsn \$fastcgi_script_name;
            }

        fastcgi_pass unix:/var/run/php5-fpm.sock;
        include fastcgi_params;
        fastcgi_param  SCRIPT_FILENAME  \$document_root\$fsn;

        #PATH_INFO and PATH_TRANSLATED can be omitted, but RFC 3875 specifies them for CGI
        fastcgi_param  PATH_INFO        \$fastcgi_path_info;
        fastcgi_param  PATH_TRANSLATED  \$document_root\$fsn;
        }

    # prevent nginx from serving dotfiles (.htaccess, .svn, .git, etc.)
    location ~ /\. {
        deny all;
        access_log off;
        log_not_found off;
        }
}

EOF
echo ""

echo -e "\033[1m===> Creating symbolic link for $DOMAIN ... \033[0m\n"
	ln -s /etc/nginx/sites-available/$DOMAIN /etc/nginx/sites-enabled/$DOMAIN
echo ""

echo -e "\033[1m> Restarting ngnix service  ...\033[0m\n"
	service nginx restart
echo ""

echo -e "\033[1m> Restarting php5-fpm service  ...\033[0m\n"
	service php5-fpm restart
echo ""

