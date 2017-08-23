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

RUN npm install -g bower && \
    npm install -g grunt && \
    npm install -g gulp && \
    npm install -g typescript

ADD ./ ./

RUN dos2unix ./build.sh

ENTRYPOINT ["./build.sh"]
