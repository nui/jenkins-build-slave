FROM openjdk:8-stretch as withDockerCli

RUN apt-get -yq update \
    && apt-get -yq upgrade \
    && apt-get -yq --no-install-recommends install \
        apt-transport-https \
        ca-certificates \
        curl \
        gosu \
        gnupg2 \
        software-properties-common

RUN curl -fsSL https://download.docker.com/linux/debian/gpg | apt-key add - \
    && add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/debian $(lsb_release -cs) stable" \
    && apt-get -yq update \
    && apt-get -yq --no-install-recommends install docker-ce-cli \
    && groupadd -g 999 docker

FROM withDockerCli as withJenkinsSlave

# Setup jenkins-slave
RUN set -eux \
    && COMMIT="62074482d19ea949b1247ddcf4232300a21a17ad" \
    && SOURCE="https://raw.githubusercontent.com/jenkinsci/docker-jnlp-slave/${COMMIT}/jenkins-slave" \
    && TARGET="/usr/local/bin/jenkins-slave" \
    && curl -sSLo $TARGET $SOURCE \
    && chmod 755 $TARGET

# see https://github.com/jenkinsci/docker-slave/blob/master/Dockerfile
ARG remoting_version=3.30
ARG uid=1000
ARG user=jenkins
LABEL jenkins.remoting.version="$remoting_version"

ARG AGENT_WORKDIR=/workspace
RUN addgroup --gid $uid $user \
    && adduser --uid $uid --gecos "" --gid $uid --disabled-password $user \
    && gpasswd -a $user docker \
    && curl --create-dirs -fsSLo /usr/share/jenkins/slave.jar \
        https://repo.jenkins-ci.org/public/org/jenkins-ci/main/remoting/${remoting_version}/remoting-${remoting_version}.jar \
    && chmod 755 /usr/share/jenkins \
    && chmod 644 /usr/share/jenkins/slave.jar \
    && mkdir -m 777 -p ${AGENT_WORKDIR}

VOLUME ${AGENT_WORKDIR}

FROM withJenkinsSlave as withGoogleSDK

RUN export CLOUD_SDK_REPO="cloud-sdk-$(lsb_release -c -s)" \
    && echo "deb http://packages.cloud.google.com/apt $CLOUD_SDK_REPO main" | tee -a /etc/apt/sources.list.d/google-cloud-sdk.list \
    && curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add - \
    && apt-get -yq update && apt-get install -yq google-cloud-sdk kubectl

FROM withGoogleSDK

RUN apt-get -yq install zsh

# install sbt
RUN echo "deb https://dl.bintray.com/sbt/debian /" | tee -a /etc/apt/sources.list.d/sbt.list \
    && apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv 2EE0EA64E40A89B84B2DF73499E82A75642AC823 \
    && apt-get -yq update \
    && apt-get -yq install sbt

# config sbt
RUN config_file="/etc/sbt/sbtopts" \
    && echo '-sbt-dir  ~/cache/sbt' >> $config_file \
    && echo '-sbt-boot ~/cache/sbt/boot' >> $config_file \
    && echo '-ivy ~/cache/ivy2' >> $config_file

RUN rm -rf /var/lib/apt/lists/*

VOLUME /home/jenkins/cache

COPY entrypoint.sh /
RUN chmod +x /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]

