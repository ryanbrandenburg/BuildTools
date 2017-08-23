FROM ubuntu:16.04

RUN apt-get update && \
    apt-get install -y git && \
    apt-get install -y libunwind8 && \
    apt-get install -y npm && \
    apt-get install -y wget && \
    apt-get install -y unzip && \
    apt-get install -y sudo && \
    apt-get install -y apt-transport-https && \
    apt-get install -y libcurl3

RUN npm install -g bower && \
    npm install -g grunt && \
    npm install -g gulp && \
    npm install -g typescript

ADD ./ ./

RUN rm ./korebuild-lock.txt

ENTRYPOINT ["./build.sh"]
