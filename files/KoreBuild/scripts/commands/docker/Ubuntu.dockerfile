FROM ubuntu:16.04

RUN apt-get update && \
    apt-get install -y git && \
    apt-get install -y libunwind8 && \
    apt-get install -y npm && \
    apt-get install -y dos2unix && \
    apt-get install -y wget && \
    apt-get install -y unzip && \
    apt-get install -y sudo && \
    apt-get install -y apt-transport-https

RUN sudo sh -c 'echo "deb [arch=amd64] https://apt-mo.trafficmanager.net/repos/dotnet-release/ xenial main" > /etc/apt/sources.list.d/dotnetdev.list' && \
    sudo apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 417A0893 && \
    apt-get update && \
    apt-get install -y dotnet-dev-1.0.4

RUN npm install -g bower && \
    npm install -g grunt && \
    npm install -g gulp && \
    npm install -g typescript

ADD ./ ./

RUN dos2unix /repo/build.sh 

CMD ["sh" "-c", "/repo/build.sh"]
