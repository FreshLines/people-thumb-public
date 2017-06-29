#
# This is meant to be run from project root
# cd <root-folder> 
# docker build -f docker/production/Dockerfile -t people-thumb:0.0.1 .
#
FROM amazonlinux:latest
COPY . /srv/www/people_thumb
WORKDIR /srv/www/people_thumb
run ls -la /srv/www/people_thumb
run yum -y upgrade
run curl -sL https://rpm.nodesource.com/setup_8.x | bash -
run yum -y install nodejs
run yum -y install vim
run yum install -y ImageMagick 
ENV PATH /srv/www/people_thumb/node_modules/.bin:$PATH
ENV NODE_ENV production
#CMD ["ls -la /srv/www/highlight_people/"]
#CMD ["tail -f /var/log/syslog"]
run npm install
run npm rebuild node-sass
CMD npm start
# CMD sleep 200000

