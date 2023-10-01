#!/bin/bash

HADOOP_VERSION="3.3.4"
HIVE_VERSION="2.3.9"
HIVE_LISTENER_VERSION="0.0.3"

export SPARK_BUILD_S3_BUCKET="https://minio.lab.sspcloud.fr/projet-onyxia/build"
export SPARK_BUILD_NAME="spark-${SPARK_VERSION}-bin-hadoop-${HADOOP_VERSION}-hive-${HIVE_VERSION}"
export HADOOP_URL="https://downloads.apache.org/hadoop/common/hadoop-${HADOOP_VERSION}"
export HADOOP_AWS_URL="https://repo1.maven.org/maven2/org/apache/hadoop/hadoop-aws"
export HIVE_URL="https://archive.apache.org/dist/hive/hive-${HIVE_VERSION}"
export HIVE_AUTHENTICATION_JAR="hive-authentication.jar"
export HIVE_LISTENER_JAR="hive-listener-${HIVE_LISTENER_VERSION}.jar"

# Spark for Kubernetes with Hadoop, Hive and Kubernetes support
# Built here : https://github.com/InseeFrLab/Spark-hive
mkdir -p $SPARK_HOME
wget -q ${SPARK_BUILD_S3_BUCKET}/spark-hive/${SPARK_BUILD_NAME}.tgz
tar xzf ${SPARK_BUILD_NAME}.tgz -C $SPARK_HOME --owner root --group root --no-same-owner --strip-components=1
rm -f ${SPARK_BUILD_NAME}.tgz

# Hadoop
mkdir -p $HADOOP_HOME
wget -q ${HADOOP_URL}/hadoop-${HADOOP_VERSION}.tar.gz
tar xzf hadoop-${HADOOP_VERSION}.tar.gz -C ${HADOOP_HOME} --owner root --group root --no-same-owner --strip-components=1
wget -q ${HADOOP_AWS_URL}/${HADOOP_VERSION}/hadoop-aws-${HADOOP_VERSION}.jar
mkdir -p ${HADOOP_HOME}/share/lib/common/lib
mv hadoop-aws-${HADOOP_VERSION}.jar ${HADOOP_HOME}/share/lib/common/lib
rm -f hadoop-${HADOOP_VERSION}.tar.gz

# Hive
mkdir -p $HIVE_HOME
wget -q ${HIVE_URL}/apache-hive-${HIVE_VERSION}-bin.tar.gz
tar xzf apache-hive-${HIVE_VERSION}-bin.tar.gz -C ${HIVE_HOME} --owner root --group root --no-same-owner --strip-components=1
wget -q ${SPARK_BUILD_S3_BUCKET}/hive-authentication/${HIVE_AUTHENTICATION_JAR}
mv ${HIVE_AUTHENTICATION_JAR} ${HIVE_HOME}/lib/
wget -q ${SPARK_BUILD_S3_BUCKET}/hive-listener/${HIVE_LISTENER_JAR}
mv ${HIVE_LISTENER_JAR} ${HIVE_HOME}/lib/hive-listener.jar
rm -f apache-hive-${HIVE_VERSION}-bin.tar.gz

# Add postgreSQL support to Hive
wget -q https://jdbc.postgresql.org/download/postgresql-42.2.18.jar
mv postgresql-42.2.18.jar ${HIVE_HOME}/lib/postgresql-jdbc.jar

# Fix versions inconsistencies of some binaries between Hadoop & Hive distributions
rm ${HIVE_HOME}/lib/guava-14.0.1.jar
cp ${HADOOP_HOME}/share/hadoop/common/lib/guava-27.0-jre.jar ${HIVE_HOME}/lib/
wget -q https://repo1.maven.org/maven2/jline/jline/2.14.6/jline-2.14.6.jar
mv jline-2.14.6.jar ${HIVE_HOME}/lib/
rm ${HIVE_HOME}/lib/jline-2.12.jar

### Jigsaw specifics
# Python 3.10: already installed in previous steps or parent image
# Java JDK 11: openjdk already installed in previous steps or parent image
# VSCode: already installed in previous steps or parent image
# Spark: requested v3.2.3 but unavailable from Onyxia team, keeping v3.3.1 already installed in previous steps

# Configuuring Hadoop
git clone https://github.com/cip-core/hadoop-install.git
(cd hadoop-install && ./create_dirs.sh)
cp -R hadoop-install/etc/hadoop/* $HADOOP_CONF_DIR/
rm -rf hadoop-install
hadoop namenode -format

# Apache kafka
# Requested v3.0, installing v3.0.2 (latest v3.0)
# Latest version available: v3.4.x
mkdir -p $KAFKA_HOME
wget -q https://downloads.apache.org/kafka/3.0.2/kafka_2.13-3.0.2.tgz
tar xzf kafka_2.13-3.0.2.tgz -C $KAFKA_HOME --owner root --group root --no-same-owner --strip-components=1
rm -f kafka_2.13-3.0.2.tgz

# kafka-python-
# No specific version requested, installing latest
pip install kafka-python

# MongoDB community & MongoDB Shell
# No MongoDB server version requested, installing latest
# Requested MongoDB Shell v2.6+, but latest available from provided link is v1.8.2
mkdir -p $MONGODB_HOME
wget -q https://fastdl.mongodb.org/linux/mongodb-linux-x86_64-ubuntu2204-6.0.5.tgz
tar xzf mongodb-linux-x86_64-ubuntu2204-6.0.5.tgz -C $MONGODB_HOME --owner root --group root --no-same-owner --strip-components=1
wget -q https://downloads.mongodb.com/compass/mongosh-1.8.2-linux-x64.tgz
tar xzf mongosh-1.8.2-linux-x64.tgz -C $MONGODB_HOME --owner root --group root --no-same-owner --strip-components=1 mongosh-1.8.2-linux-x64/bin/
rm -f mongodb-linux-x86_64-ubuntu2204-6.0.5.tgz 
rm -f mongosh-1.8.2-linux-x64.tgz

# Mongo Spark Connector
# No specific version requested, installing latest available
apt-get -y install maven
mvn dependency:get -DgroupId=org.mongodb.spark -DartifactId=mongo-spark-connector_2.13 -Dversion=10.1.1

# Hadoop startup script will make ssh connection and we need the environment variables defined as well when the remote connections are opened.
cat <<EOT >> /etc/environment
# Env from Insee's Spark container
export HADOOP_HOME="/opt/hadoop"
export SPARK_HOME="/opt/spark"
export HIVE_HOME="/opt/hive"
export PYTHONPATH="/opt/spark/python:/opt/spark/python/lib"
export SPARK_OPTS="--driver-java-options=-Xms1024M --driver-java-options=-Xmx4096M"
export JAVA_HOME="/usr/lib/jvm/java-11-openjdk-amd64"
export HADOOP_OPTIONAL_TOOLS="hadoop-aws"
export PATH="${PATH}:\${JAVA_HOME}/bin:${SPARK_HOME}/bin:${HADOOP_HOME}/bin:${HADOOP_HOME}/sbin:${KAFKA_HOME}/bin:${MONGODB_HOME}/bin:${HIVE_HOME}/bin:${PATH}"

# Jigsaw's specifics
export KAFKA_HOME="/opt/kafka"
export MONGODB_HOME="/opt/mongodb"
EOT
