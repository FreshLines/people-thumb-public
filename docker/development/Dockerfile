FROM node:latest
WORKDIR /srv/www/people_thumb
run apt-get update
run apt-get install -y vim
run apt-get install -y imagemagick
ENV PATH /srv/www/people_thumb/node_modules/.bin:$PATH
# CMD ["ls -la /srv/www/people_thumb/"]
#CMD ["tail -f /var/log/syslog"]
# run npm link
run npm install
run npm rebuild node-sass
# Leave sleep up for testing daemon
CMD sleep 100000
