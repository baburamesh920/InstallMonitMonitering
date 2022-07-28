#! /bin/bash

WP_INSTALLER_LINK='https://wordpress.org/wordpress' #-4.9.9.zip
SQL_USER='root'
SQL_PASSWORD='Opencart@mysql123'

print_help()
{
    echo ""
    echo "*********************************************************************************"
    echo "*                                                                               *"
    echo "*           ------------ READ INSTRUCTIONS CAREFULLY !!! ----------------       *"
    echo "*                                                                               *"
    echo "* 1. Make sure your domain points to this server where you are going to         *"
    echo "*    host the wordpress site. IP address of this server is 139.59.24.217        *"
    echo "*                                                                               *"
    echo "* 2. This script will install the wordpress version of your choice and          *"
    echo "*    developers can connect to admin panel to install themes and plugins        *"
    echo "*                                                                               *"
    echo "* 3. This script has totally 5 steps, and prompting for confirmation at each    *"
    echo "*    step. Below are the 5 steps:                                               *"
    echo "*       Step 1 - Create New User with FTP and shell access                      *" 
    echo "*       Step 2 - Download and install wordpress                                 *" 
    echo "*       Step 3 - Setup wordpress folder permissions                             *"
    echo "*       Step 4 - Create virtualhost entry for the domain                        *"
    echo "*       Step 5 - Import SQL if the site was migrated from different hosting     *"                                                                                                                       
    echo "*                                                                               *"
    echo "* 4. If the site is migrated from another hosting at the end of Step 4,         *"
    echo "*    you can upload the sql and replace wp-content directory and then proceed   *"
    echo "*    to step 5. You have to use the new user credentials for FTP upload         *" 
    echo "*                                                                               *"
    echo "*********************************************************************************"
    echo ""
}

add_new_wpuser()
{
    echo ""
    echo "*********************************************************************************"
    echo ""
    read -p "Step 1 - Do you want to proceed with new user creation, or skip (y/n) ? " choice
    if [ "$choice" = "n" ]
    then
        return
    fi
    echo ""
    echo "*********************************************************************************"
    echo ""

    getent passwd $1 > /dev/null 2&>1

    if [ $? -eq 0 ]; then
        echo "INFO:: User already exists, proceeding to next step..."
        return
    fi

    useradd $1
    echo "$1:$2" | chpasswd
    echo "INFO:: Successfully created new user..."

    usermod -a -G apache $1
    echo "INFO:: Added new user to the apache group..."

    chmod 755 /home/$1
    echo "INFO:: Successfully setup home directory permissions..."
}

install_wp()
{
    echo ""
    echo "*********************************************************************************"
    echo ""
    read -p "Step 2 - Do you want to proceed with wordpress installation, or skip (y/n) ? " choice
    if [ "$choice" = "n" ]
    then
        return
    fi

    echo ""
    echo "*********************************************************************************"
    echo ""
    echo "INFO:: Adding new html directory for the new user..."

    dir="/home/$1/html"

    if [ -d "$dir" ]; then
       # Control will enter here if $DIRECTORY exists.
         echo "INFO:: web directoty already exists, proceeding to next step..."
    else
        mkdir $dir
        chown -R $1:apache $dir 
    fi

    echo "INFO:: Downloading wordpress version $2 ..."
   
    url="$WP_INSTALLER_LINK-$2.zip"
    filename="$dir/wordpress-$2.zip"
    wget -O $filename $url

    if [[ $? -ne 0 ]]; then
         echo ""
         echo "ERROR:: Failed to download wordpress version $2 ... Please check the wordpress version and retry...Aborting...."
         echo ""
         exit 1
    fi

    echo "INFO:: Successfully downloaded the required wordpress version. Unpacking now..."

    unzip $filename -d $dir
    mv $dir/wordpress/* $dir

    # cleanup installer files
    rm $filename
    rm -rf $dir/wordpress
}

setup_wp_perms()
{
    echo ""
    echo "*********************************************************************************"
    echo ""
    read -p "Step 3 - Do you want to proceed with wordpress file permissions setup, or skip (y/n) ? " choice
    if [ "$choice" = "n" ]
    then
        return 1
    fi

    echo ""
    echo "*********************************************************************************"
    echo ""

    dir="/home/$1/html"

    echo "INFO:: Setting up file permissions..."

    # setup wordpress permissions
    chown -R $1:apache $dir
    find $dir -type f -exec chmod 644 {} +
    find $dir -type d -exec chmod 755 {} +
    chmod -R 775 $dir/wp-content
    
    echo "INFO:: wordpress file permissions updated successfully..."
}


setup_domain()
{
    echo ""
    echo "*********************************************************************************"
    echo ""
    read -p "Step 4 - Do you want to proceed with virtual host configuration setup, or skip (y/n) ? " choice
    if [ "$choice" = "n" ]
    then
        return 1
    fi

    echo ""
    echo "*********************************************************************************"
    echo ""
    path="/home/$1/html"

    echo "INFO:: Adding virtual host entry for the new website..."

    cat >> /etc/httpd/conf.d/sites.conf <<EOL

<VirtualHost *:80>
    DocumentRoot "$path"
    ServerName $2
    ServerAlias www.$2
    RewriteEngine On    
    <Directory $path>        
        Options FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>
</VirtualHost>
EOL

    echo "139.59.24.217 $2" >> /etc/hosts

    echo "INFO:: Successfully added virtualhost entry for website $2 ..."

    service httpd restart
    echo "INFO:: Restarted apache, virtual host entry should be effective now..."
}

migrate_site()
{
    echo ""
    echo "*********************************************************************************"
    echo ""
    read -p "Step 5 - Do you want to migrate old hosting files or skip (y/n) ? " choice
    if [ "$choice" = "n" ]
    then
        return 1
    fi
    
    path="/home/$1/html"

    echo ""
    echo "*********************************************************************************"
    echo "* Will need sql dump and wp-content folders from the existing site for migration."
    echo "*  1. Take sql dump from the current site"
    echo "*  2. Replace domain name in the sql with the current domain name of the site"
    echo "*  3. Use FTP Credentials: $1 / $2, to upload sql file and replace wp-content "
    echo "*********************************************************************************"
    echo ""
    read -p "Confirm Upload is completed and proceed (y/n) ? " choice
    if [ "$choice" = "n" ]
    then
        echo "ERROR:: Cannot proceed with migration without the files. Aborting migration !!!.."
        return 1
    fi

    read -p "Please Enter SQL filename here : " sqlfile
    read -p "Please Enter Wordpress database name : " dbname
    read -p "Please Enter Wordpress table prefix string : " tbprefix

    filename="$path/$sqlfile"
    if [ -f $filename ]; then
	echo "INFO:: Starting DB migration to $dbname ..."
        mysql -u $SQL_USER -p$SQL_PASSWORD $dbname < $filename

    	# Also update wp-config.php file with db credentials
	cp $path/wp-config-sample.php $path/wp-config.php
    	sed -ie "s/DB_USER'\, '.*')/DB_USER'\, '$SQL_USER')/g" $path/wp-config.php
    	sed -ie "s/DB_PASSWORD'\, '.*')/DB_PASSWORD'\, '$SQL_PASSWORD')/g" $path/wp-config.php
    	sed -ie "s/table_prefix  = 'wp_'/table_prefix  = '$tbprefix'/g" $path/wp-config.php


	# setup wordpress permissions
    	chown -R $1:apache $path
    	find $path -type f -exec chmod 644 {} +
    	find $path -type d -exec chmod 755 {} +
    	chmod -R 775 $path/wp-content
	
 	echo "INFO:: wordpress site migration completed successfully..."
    else
       echo "ERROR:: File $filename does not exist. Aborting migration...!!!"
    fi
}

# Main script exeuction starts here
print_help

if [ [$1 == '-h'] ]; then
    exit 0
fi

read -p "Please Enter New Username : " username
read -p "Please Enter Strong Password : " password
read -p "Please Enter Domain name without www (eg: test.com) : " domain
read -p "Please Enter Exact Wordpress Version (eg: 5.0.3) : " wpversion
echo ""
read -p "Please check all inputs before proceeding. Are you sure, you want to Continue (y/n) ? " choice

if [ "$choice" = "y" ]
    then
      # do the dangerous stuff
        add_new_wpuser $username $password
        sleep 3
        install_wp $username $wpversion
        sleep 3
        setup_wp_perms $username
        sleep 3
        setup_domain $username $domain
        sleep 3
        migrate_site $username $password
        sleep 3
    echo ""
    echo "*********************************************************************************"
    echo "* !!! Your wordpress site is setup successfully...				  *"
    echo "*********************************************************************************"
    echo ""
else
       echo ""
       echo "ERROR:: Aborting . Please try again"
       echo ""
       exit 1
fi

exit 0
