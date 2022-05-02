#!/bin/bash

###############################
# this is intended for Ubuntu #
###############################

hadoop_version="3.3.2"
hdr_pad="###########################################################################"
final_msg="Items Completed:"

printf "This script is intended for Ubuntu + Hadoop ${hadoop_version}\n\tSee https://hadoop.apache.org/docs/stable/hadoop-project-dist/hadoop-common/SingleCluster.html\n"


# update os
printf "\n\n${hdr_pad}\nEnsuring the OS is up to date\n${hdr_pad}\n"
sudo apt update
final_msg="${final_msg}\n\tapt updated"


# install ssh and pdsh
printf "\n\n${hdr_pad}\nInstalling SSH...i\n${hdr_pad}\n"
sudo apt install ssh
final_msg="${final_msg}\n\tssh installed"


printf "\n\n${hdr_pad}\nInstalling PDSH\n${hdr_pad}\n"
sudo apt install pdsh
final_msg="${final_msg}\n\tpdsh installed"


# install java versions 8 & 11
printf "\n\n${hdr_pad}\nInstalling Java versions 11 (max supported version) and 8 (for compiling)\n${hdr_pad}\n"
sudo apt install openjdk-8-jdk
final_msg="${final_msg}\n\tJava 8 installed"

sudo apt install openjdk-11-jdk
final_msg="${final_msg}\n\tJava 11 installed"


# download hadoop
printf "\n\n${hdr_pad}\nDownloading Hadoop (version ${hadoop_version})\n${hdr_pad}\n"
wget https://dlcdn.apache.org/hadoop/common/hadoop-${hadoop_version}/hadoop-${hadoop_version}.tar.gz -P ~/Downloads
wget https://dlcdn.apache.org/hadoop/common/hadoop-${hadoop_version}/hadoop-${hadoop_version}.tar.gz.sha512 -P ~/Downloads
final_msg="${final_msg}\n\tHadoop ${hadoop_version} downloaded (~/Downloads/hadoop-${hadoop_version}.tar.gz)"


printf "\n\n${hdr_pad}\nVerifying the SHA512\n${hdr_pad}\n"
intended_sha=`cat ~/Downloads/hadoop-${hadoop_version}.tar.gz.sha512 | awk '$0-/=\s(*)/ {print $4}'`
actual_sha=`sha512sum ~/Downloads/hadoop-${hadoop_version}.tar.gz | awk '$0-/\s/ {print $1}'`
printf "\tIntended SHA512: \n\t\t${intended_sha}\n\tActual SHA512: \n\t\t${actual_sha}\n"

if [ "$intended_sha" == "$actual_sha" ]; then
	printf "\n\tSHA512 MATCHES!  You may proceed\n\n"
	read -p "Would you like to proceed? [Y/n] " proceed
	final_msg="${final_msg}\n\tSHA512 verified"
	
	if [ ${proceed} == "Y" ] || [ ${proceed} == "y" ] || [ ${proceed,,} == "yes" ]; then
		printf "\tLets do this....continuing on to file extraction...\n"
	else
		printf "\tEXITING\n"
		final_msg="${final_msg} (but user exited anyway)"
		printf "\n${hdr_pad}\nSCRIPT EXITED EARLY (User Forced)\n${hdr_pad}\n${final_msg}\n"

		exit -1
	fi	
else
	printf "\n\tMAYDAY MAYDAY!!!! SHA512 does not match, EXITING!!!!\n"
	final_msg="${final_msg}\n\tSHA512 checked but did not match (system forced exit)"
	printf "\n${hdr_pad}\nSCRIPT EXITED EARLY (System Forced)\n${hdr_pad}\n${final_msg}\n"

	exit -1
fi


printf "\n\n${hdr_pad}\nExtracting the downloaded hadoop files\n${hdr_pad}\n"
hadoop_home=~/hadoop-${hadoop_version}
rm -rf ${hadoop_home}
tar -xf ~/Downloads/hadoop-${hadoop_version}.tar.gz --directory ~/
printf "Extracted to ${hadoop_home}\n"
final_msg="${final_msg}\n\tExtracted to ${hadoop_home}"

hadoop_running=`ls /tmp/hadoop* | wc -l`
if [ ${hadoop_running} > 0 ];
then
	printf "Previous instance of Hadoop is running.  Stopping instance." 
       	${hadoop_home}/sbin/stop-all.sh
	rm -rf /tmp/hadoop*
	rm -rf /tmp/*datanode*
	rm -rf /tmp/*hdfs*
	rm -rf /tmp/*secondary*
fi

read -p "Add HADOOP_HOME environment variable to .bashrc? [Y/n] " set_hadoop_home
if [ $set_hadoop_home == "Y" ] || [ $set_hadoop_home == "y" ] || [ ${set_hadoop_home,,} == "yes" ]; then
	echo "" >> ~/.bashrc
	echo "#######################" >> ~/.bashrc
	echo "# Hadoop related vars #" >> ~/.bashrc
	echo "#######################" >> ~/.bashrc
	echo "export HADOOP_HOME=${hadoop_home}" >> ~/.bashrc
	echo "export PDSH_RCMD_TYPE=ssh" >> ~/.bashrc
	echo "export PATH=${PATH}:${hadoop_home}/bin/:${hadoop_home}/sbin/" >> ~/.bashrc

	# enable the environment variables for the duration of the script
	source ~/.bashrc

	printf "\t.bashrc updated with HADOOP_HOME mapping (${hadoop_home}).\n\tHADOOP_HOME will be available in terminals opened in the future.\n\tTo activate it for the current terminal session, run command:\n\t\tsource ~/.bashrc\n"
	final_msg="${final_msg}\n\tAdded HADOOP_HOME to ~/.bashrc - run 'source ~/.bashrc' to activate in current shell"

fi


# Configure Standalone Hadoop
printf "\n\n${hdr_pad}\nConfiguring Hadoop (Standalone by default)\n${hdr_pad}\n"
# replace the JAVA_HOME entry of hadoop-env.sh script
read -p "Enter the JAVA_HOME path (default: /usr/lib/jvm/java-11-openjdk-amd64/): " java_home
if [ ! -f "${java_home}" ];
then
	java_home=/usr/lib/jvm/java-11-openjdk-amd64/
fi
sed -i "s/# export JAVA_HOME=/export JAVA_HOME=${java_home//[\/]/\\\/}/" ${hadoop_home}/etc/hadoop/hadoop-env.sh
final_msg="${final_msg}i\n\tConfigured JAVA_HOME in ${hadoop_home}/etc/hadoop/hadoop-env.sh"


# Test Standalone Hadoop
printf "\n\n${hdr_pad}\nTest Hadoop Standalone Operation (Default Setup)\n${hdr_pad}\n"
printf "By default, Hadoop is configured to run in a non-distributed mode, as a single Java process. (https://hadoop.apache.org/docs/stable/hadoop-project-dist/hadoop-common/SingleCluster.html#Standalone_Operation)\n\n"
read -p "Would you like to run a quick test? [Y/n] " run_test
if [ $run_test == "Y" ] || [ $run_test == "y" ] || [ ${run_test,,} == "yes" ]; then
	printf "\nRUNNING TEST: Looking through configuration files for any strings with minimum length of 4 that start with 'dfs'\n"

	mkdir ${hadoop_home}/input
	cp ${hadoop_home}/etc/hadoop/*.xml ${hadoop_home}/input
	${hadoop_home}/bin/hadoop jar ${hadoop_home}/share/hadoop/mapreduce/hadoop-mapreduce-examples-${hadoop_version}.jar grep ${hadoop_home}/input ${hadoop_home}/output 'dfs[a-z.]+'
	test_results=`cat ${hadoop_home}/output/*`

	printf "\n\nRESULTS FOUND:\n${test_results}\n"
	final_msg="${final_msg}\n\tTested Hadoop Default Setup"
fi


# Configure Pseudo-Distributed Hadoop
printf "\n\n${hdr_pad}\nConfiguring Pseudo-Distributed Hadoop\n${hdr_pad}\n"
read -p "Would you like to setup Hadoop in 'Psudeo-Distributed' Operation? [Y/n] " pseudo_distributed
if [ $pseudo_distributed == "Y" ] || [ $pseudo_distributed == "y" ] || [ ${pseudo_distributed,,} == "yes" ]; then
	final_msg="${final_msg}\n\tConfigured for Pseudo-Distributed Operation:"

	# Add configuration properties
	config_property="    <property>\n      <name>fs.defaultFS</name>\n       <value>hdfs://localhost:9000</value>\n    </property>\n\n</configuration>"
	sed -i "s/<\/configuration>/${config_property//[\/]/\\\/}/" ${hadoop_home}/etc/hadoop/core-site.xml
	final_msg="${final_msg}\n\t\tUpdated ${hadoop_home}/etc/hadoop/core-site.xml"
	

	config_property="    <property>\n      <name>dfs.replication</name>\n      <value>1</value>\n   </property>\n\n</configuration>"
	sed -i "s/<\/configuration>/${config_property//[\/]/\\\/}/" ${hadoop_home}/etc/hadoop/hdfs-site.xml
	final_msg="${final_msg}\n\t\tUpdated ${hadoop_home}/etc/hadoop/hdfs-site.xml"

	# Add passwordless SSH
	read -p "Setup passwordless ssh to localhost? [Y/n] " setup_ssh
	if [ $setup_ssh == "Y" ] || [ $setup_ssh == "y" ] || [ ${setup_ssh,,} == "yes" ]; then
		ssh_file=~/.ssh/id_rsa
		if [ -f "${ssh_file}" ]; then
			printf "\n\tUsing existing ssh key files (~/.ssh/id_rsa)\n"

		else
			printf "\n\tGenerating a new ssh key files (~/.ssh/id_rsa)\n"
			ssh-keygen -t rsa -P '' -f ~/.ssh/id_rsa
		fi

		cat ~/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys
		chmod 0600 ~/.ssh/authorized_keys

		final_msg="${final_msg}\n\t\tSetup passwordless SSH capability to localhost"
	fi
fi


# Test Pseudo-Distributed Hadoop
if [ $pseudo_distributed == "Y" ] || [ $pseudo_distributed == "y" ] || [ ${pseudo_distributed,,} == "yes" ]; then
	printf "\n\n${hdr_pad}\nTest Hadoop Pseudo-Distrbuted Operation\n${hdr_pad}\n"
	read -p "Would you like to run a quick test? [Y/n] " run_test
	if [ $run_test == "Y" ] || [ $run_test == "y" ] || [ ${run_test,,} == "yes" ]; then
		printf "\nRUNNING TEST:\n\tFormatting the filesystem\n"
		${hadoop_home}/bin/hdfs namenode -format

		printf "\n\tStarting the NameNode and Data Node daemons\n"
		${hadoop_home}/sbin/start-dfs.sh

		printf "\n\t Navigate to http://localhost:9870/ to view the web interface for the NameNode\n"

		printf "\n\tMaking the HDFS directories required to execute Map Reduce jobs (within hdfs: /user/$USER)\n"
		${hadoop_home}/bin/hdfs dfs -mkdir /user
		${hadoop_home}/bin/hdfs dfs -mkdir /user/$USER
		
		printf "\n\tCopying the input files into the distributed file system (dfs)\n"
		printf "\t\thdfs dfs -mkdir input\n"
		printf "\t\thdfs dfs -mkdir output\n"
		printf "\t\thdfs dfs -put ${hadoop_home}/etc/hadoop/*.xml input\n"
		${hadoop_home}/bin/hdfs dfs -mkdir input
		${hadoop_home}/bin/hdfs dfs -put ${hadoop_home}/etc/hadoop/*.xml input


		printf "\n\tRunning example search for file entries matching regular expression 'dfs[a-z.]+' (same as standalone test)i\n"
		printf "\t\thadoop jar ${hadoop_home}/share/hadoop/mapreduce/hadoop-mapreduce-examples-${hadoop_version}.jar grep input output 'dfs[a-z.]+'\n"
		${hadoop_home}/bin/hadoop jar ${hadoop_home}/share/hadoop/mapreduce/hadoop-mapreduce-examples-${hadoop_version}.jar grep input output 'dfs[a-z.]+'

	
		printf "\n\tCopying results from hdfs to local filessystem\n"
		printf "\t\thdfs dfs -get output ${hadoop_home}/output2\n"
		printf "\t\tor\n"
		printf "\t\thdfs dfs -cat output/*\n"
		#mkdir ${hadoop_home}/output2
		#${hadoop_home}/bin/hdfs dfs -get output ${hadoop_home}/output2

		#test_results=`cat ${hadoop_home}/output2/*`
		test_results=`${hadoop_home}/bin/hdfs dfs -cat output/*`
	
		printf "\n\nRESULTS FOUND:\n${test_results}\n"
		final_msg="${final_msg}\n\tTested Hadoop Pseudo-Distributed Setup"

		printf "\n\nStopping the Hadoop processes (stop-all.sh)\n"
		${hadoop_home}/sbin/stop-all.sh
	fi
fi


final_msg="${final_msg}\n\n Commands to be aware of:\n\thdfs\n\thadoop\n\tstart-dfs.sh\n\tstart-all.sh\n\tstop-dfs.sh\n\tstop-all.sh\n\tjps"
printf "\n${hdr_pad}\nSCRIPT COMLETED SUCCESSFULLY\n${hdr_pad}\n${final_msg}\n"

