#!/bin/bash
# ---------------
# 1.This shell backup the database of certain user at 2:00am everyday.
# 2.The backup file named as "userName_yyyymmdd.dmp", where "yyyymmdd" is the date.
# 3.Then the backup file will be compressed as "userName_yyyymmdd.tar.gz".
# 4.Consider various possible alarm situation:
#	* Database glitches.
#	* Disk-full errors.
#	* CPU occupancy error(should not be more than 60%).
#	If backup failed, retry after 10min.
# 5.Log file is needed for backup process, named "userName_yyyymmdd.log".
# 6.Log file format:
# 	[2017-07-06 08:44:15] Notice : success to init share memory, key = 0x01400075, shmid = 131076
# 	[2017-07-06 08:44:19] Notice : start read table:rbi_send_bill table
# 	[2017-07-06 08:44:19] Error  : failed to do xxx operation.
# ----------------
# Oracle environment parameters
export ORACLE_BASE=/opt/oracle/oradb
export ORACLE_HOME=/opt/oracle/oradb/home
export ORACLE_SID=inomc
export PATH=$ORACLE_HOME/bin:$PATH:$HOME/bin

# Oracle language set
export LANG=en_US.UTF-8
export NLS_LANG=AMERICAN_AMERICA.ZHS16GBK

# Get current date/time
dateFormat1=$(date +%Y%m%d)

# Backup settings
bakUser=ripple
bakPasswd=ripple7an
bakData=$bakUser"_"$dateFormat1.dmp
bakDir=$ORACLE_BASE/oradata/dbbackup
bakLog=$bakUser"_"$dateFormat1.log
bakDataCompressed=$bakUser"_"$dateFormat1.tar.gz

# Output to log file function
outputToLog() { 
	dateFormat2=$(date +"[%Y-%m-%d %H:%M:%S]")
	echo "$dateFormat2 $1" | tee -a $bakDir/$bakLog 
}

# Check/create backup directory
if [ ! -d "$bakDir" ]; then
	mkdir $bakDir
	outputToLog "Notice: create back up directory..."
fi
cd $bakDir

# Environment checkup
# Disk storage check
dbStorageThreshold=90%
dbStorageRate=`df -h | grep "/opt$" | grep -o "[0-9]\{1,3\}%"`
if [ `expr ${dbStorageRate%%%} \> ${dbStorageThreshold%%%}` -eq 1 ]; then
	outputToLog "Warning: disk storage is almost full($dbStorageRate), please release the space. Backup terminated."
	exit
else
	outputToLog "Notice: disk storage $dbStorageRate used."
fi

# CPU usage check
while [ 0 -eq 0 ]; do
	cpuUsageThreshold=60%
	cpuUsage=`top -n 1 | awk -F '[ %]+' 'NR==3 {print $2}'`
	if [ `expr $cpuUsage \> ${cpuUsageThreshold%%%}` -eq 1 ]; then
		outputToLog "Warning: CPU usage exceeds $cpuUsageThreshold, retry after 10s..."
		sleep 10s
	else
		outputToLog "Notice: current CPU usage is $cpuUsage%."
		break
	fi
done

# Start backup
# ----------------
# Here we can also backup the file by using spool:
# SPOOL $bakDir/bakfile.txt
# SELECT * from bakfile
# SPOOL OFF
# ----------------
outputToLog "Notice: oracle backup begin..."
exp $bakUser/$bakPasswd@$ORACLE_SID grants=y owner=$bakUser file=$bakDir/$bakData log=$bakDir/tem.log
cat tmp.log >> $bakDir/$bakLog 
rm tmp.log
outputToLog "Notice: backup finished."

# Compress
outputToLog "Notice: compressing the backup file..."
tar -zcvf $bakDataCompressed $bakData
rm $bakData
outputToLog "Notice: compression finished, and original backup data deleted."