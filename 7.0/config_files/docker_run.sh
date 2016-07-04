#!/bin/sh

RET=1
while [ $RET -ne 0 ]; do
    echo "\n* Waiting for confirmation of MySQL service startup"
    sleep 5
    mysql -h $DB_SERVER -P $DB_PORT -u $DB_USER -p$DB_PASSWD -e "status" > /dev/null 2>&1
    RET=$?
done

if [ ! -f ./config/settings.inc.php  ]; then
	if [ $PS_DEV_MODE = 0 ]; then
		echo "\n* Disabling DEV mode ...";
		sed -ie "s/define('_PS_MODE_DEV_', true);/define('_PS_MODE_DEV_',\ false);/g" /var/www/html/config/defines.inc.php
	fi

	if [ $PS_HOST_MODE != 0 ]; then
		echo "\n* Enabling HOST mode ...";
		echo "define('_PS_HOST_MODE_', true);" >> /var/www/html/config/defines.inc.php
	fi

	if [ $PS_FOLDER_INSTALL != "install-dev" ]; then
		echo "\n* Renaming install folder as $PS_FOLDER_INSTALL ...";
		mv /var/www/html/install-dev /var/www/html/$PS_FOLDER_INSTALL/
	fi

	if [ $PS_FOLDER_ADMIN != "admin-dev" ]; then
		echo "\n* Renaming admin folder as $PS_FOLDER_ADMIN ...";
		mv /var/www/html/admin-dev /var/www/html/$PS_FOLDER_ADMIN/
	fi

	if [ $PS_HANDLE_DYNAMIC_DOMAIN = 0 ]; then
		rm /var/www/html/docker_updt_ps_domains.php
	else
		sed -ie "s/DirectoryIndex\ index.php\ index.html/DirectoryIndex\ docker_updt_ps_domains.php\ index.php\ index.html/g" /etc/apache2/apache2.conf
	fi

	if [ $PS_INSTALL_AUTO = 1 ]; then
		echo "\n* Installing PrestaShop, this may take a while ...";
		if [ $DB_PASSWD = "" ]; then
			mysqladmin -h $DB_SERVER -P $DB_PORT -u $DB_USER drop $DB_NAME --force 2> /dev/null;
			mysqladmin -h $DB_SERVER -P $DB_PORT -u $DB_USER create $DB_NAME --force 2> /dev/null;
		else
			mysqladmin -h $DB_SERVER -P $DB_PORT -u $DB_USER -p$DB_PASSWD drop $DB_NAME --force 2> /dev/null;
			mysqladmin -h $DB_SERVER -P $DB_PORT -u $DB_USER -p$DB_PASSWD create $DB_NAME --force 2> /dev/null;
		fi

		php /var/www/html/$PS_FOLDER_INSTALL/index_cli.php --domain=$(hostname -i) --db_server=$DB_SERVER:$DB_PORT --db_name="$DB_NAME" --db_user=$DB_USER \
			--db_password=$DB_PASSWD --firstname="John" --lastname="Doe" \
			--password=$ADMIN_PASSWD --email="$ADMIN_MAIL" --language=$PS_LANGUAGE --country=$PS_COUNTRY \
			--newsletter=0 --send_email=0

		chown www-data:www-data -R /var/www/html/
	fi
fi

# We need to remove the pid file or Apache won't start after being stopped
if [ -f /var/run/apache2/apache2.pid  ]; then
    rm -f /var/run/apache2/apache2.pid
fi

echo "\n* Almost ! Starting Apache now\n";
exec apache2 -DFOREGROUND
