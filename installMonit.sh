cd ~
wget http://mmonit.com/monit/dist/binary/5.32.0/monit-5.32.0-linux-x64.tar.gz
tar zxf monit-5.32.0-linux-x64.tar.gz
cd monit-5.32.0/
cp bin/monit /usr/bin/
mkdir /etc/monit
touch /etc/monit/monitrc
chmod 0700 /etc/monit/monitrc
ln -s /etc/monit/monitrc /etc/monitrc
wget https://gist.githubusercontent.com/gaurish/964456aa08c9fa2e43ee/raw/1aa107e62ecaaa2dacfdb61a12f13efb6f15005b/monit -P /etc/init.d/
chmod u+x /etc/init.d/monit
echo "START=yes" > /etc/default/monit
monit -t