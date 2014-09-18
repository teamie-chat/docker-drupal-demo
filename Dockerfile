FROM ubuntu:trusty
MAINTAINER Amarnath Ravikumar <amar@semantics3.com>

USER root

# Install httpd, MySQL, Redis, nodeJS, PHP and the PHP modules required by Drupal. 
RUN apt-get upgrade -y && \
    apt-get update -y && \
    apt-get install -y python-software-properties software-properties-common && \
    add-apt-repository ppa:chris-lea/node.js && \
    apt-get upgrade -y && \
    apt-get update -y && \
    apt-get install -y apache2 nodejs mysql-server redis-server libapache2-mod-php5 git && \
    apt-get install -y php5-mysql php5-gd php-pear php-apc curl && \
    mkdir -p /usr/local/bin

# Setup MySQL.
ADD mysql_setup.sh /usr/local/bin/
ADD my.cnf /etc/
RUN chmod u+x /usr/local/bin/mysql_setup.sh && \
    /usr/local/bin/mysql_setup.sh

# Install Composer, Drush.
ENV PATH $HOME/.composer/vendor/bin:$PATH
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin && \
    mv /usr/local/bin/composer.phar /usr/local/bin/composer && \
    composer global require drush/drush:6.* && \
    composer global update

# Quick install Drupal using the minimal profile.
WORKDIR /var/www/html
# https://www.drupal.org/node/1826652
RUN service mysql start && \
    mkdir -p drupal/src && \
    cd drupal && \
    php -d sendmail_path=/bin/true $HOME/.composer/vendor/bin/drush.php --yes qd --account-pass="admin" \
        --db-su="root" --db-su-pw="root" \
        --db-url="mysql://root:root@localhost/drupal" --no-server --profile=minimal \
        --root=/var/www/html/drupal/src && \
    service mysql stop

# Clone the t_chat, t_chat_demo modules.
RUN cd drupal/src/sites/all/modules && \
    git clone --branch 7.x-1.x-dev http://git.drupal.org/sandbox/teamie/2038505.git t_chat && \
    git clone https://github.com/teamie-chat/drupal-demo t_chat_demo && true 

# Install the dependencies required by the t_chat nodeJS server app.
RUN cd drupal/src/sites/all/modules/t_chat/server && \
    npm install && \
    cp conf.js.example conf.js && \
    sed -i 's/myVerySecretToken/KzaZtxEJlTDLrxIjD2a-wtEXMODQ76TXsKnpWxdB8ys/' conf.js

# Enable the Bootstrap theme and install the t_chat_demo module.
RUN cd drupal/src/sites/default && \
    service mysql start && \
    drush --yes en bootstrap && \
    drush ev "theme_enable( array( 'bootstrap' ) )" && \
    sed -i 's/dependencies\[\] = fe_block//' ../all/modules/t_chat_demo/t_chat_demo.info && \
    sed -i 's/\(dependencies\[\] = og.*\)/;\1/' ../all/modules/t_chat/t_chat.info && \
    drush --yes dl og-7.x-1.5 && drush --yes en og && \
    drush --yes en t_chat && \
    drush --yes en t_chat_demo && \
    drush --yes dl features_extra && drush --yes en fe_block && \
    drush --yes fr t_chat_demo && \
    drush --yes en devel_generate && \
    service mysql stop

# Run the Drupal permissions script.
ADD fix-drupal-permissions.sh /var/www/html/drupal/
RUN chmod u+x drupal/fix-drupal-permissions.sh && \
    cd drupal && \
    ./fix-drupal-permissions.sh --drupal_path=src/ --drupal_user=root

# Generate dummy users and chat rooms on the site.
RUN service mysql start && \
    cd drupal/src/sites/default && \
    drush genc --types="chat_room" --skip-fields="group_group" 10 && \
    drush genu 100 && \
    service mysql stop

# Expose volumes to track logs from the host.
VOLUME ["/var/log/apache2"]

# Configure Apache to allow rewrites and respect Drupal's .htaccess file.
ADD apache2.conf /etc/apache2/
RUN a2enmod rewrite

# Set global git config. (for stashing stuff.)
RUN git config --global user.email john.doe@example.com && \
    git config --global user.name "John Doe"

# Start httpd, Redis, MySQL and the t_chat server.
CMD service apache2 start && \
    service redis-server start && \
    service mysql start && \
    cd drupal/src/sites/all/modules/t_chat_demo && \
    git stash && git pull && git stash pop && \
    cd ../t_chat && \
    git stash && git pull && git stash pop && \
    cd server/ && \
    node server.js

EXPOSE 80
EXPOSE 8888
