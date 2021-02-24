# Websphere_MQ_Scripts
Websphere MQ scripts used to automate daily MQ tasks.

What it does?

This script will automatically fetch the sequence mismatch number from the AMQERR01.LOG and then 
reset the connection with the last matched sequence number. For more information about the error 
and for manual process to troubleshoot for the same, please refer below link.
https://www.ibm.com/support/pages/amq9526-message-sequence-number-error-channel

How it does?

The fetches the information from the active error log AMQERR01.LOG and tabulates in below format 
inside the reset_rec_files.
Number_of_occurrences Channel_name Required_sequence_number
49  A.B 3117675
11  B.C 536907
123 C.D 3105074
15  D.E 5654125
Second Column --> Affected Channel
Third Column --> Expected/Sent Sequence Number
First Column --> Number of occurrences for that particular channel and sequence number.
Every time the script executes, a new record file is generated and compared with the existing one. By 
use of diff command, 3 stage verification is done to find any discrepancy. If any new channel is found, 
the information is passed onto the files final_chl_list and final_seq_list for Execution.


First Time Set Up:

Tested Environment - MQ v9.1, Linux
Change the permissions to executable 755 seq_mis_reset.sh.
The script executes for every Queue Manager in batch mode. So we need to call the function for every 
QM at the last line.
reset_for_qmgr QM\!A_QM
reset_for_qmgr QM\!B_QM
The script has a record tracking system to avoid repetition of channel reset. We need to touch create 
the files in below manner inside.
Create a directory named reset_rec_files at your $HOME directory
mkdir reset_rec_files
Touch create the files in below manner.
reset_rec_QM.A_QM
reset_rec_QM.B_QM

Rules for setting cron frequency and sleep time duration:

Consider the lines 42, 46 & 48 in the Execution stanza where the sleeps commands are given.
line 42: Waits for 5s after channels are stopped
line 46: Waits for 5s after channels are reset
Line 48: Waits for 100s to see if the channels come up after reset and if not so, an alert mail will be 
triggered meaning the channel is done but the channel has not yet come up. If the alert mail is not 
triggered after the given amount of time, it means that the channel reset is done successfully and the 
channel is up and running. Please do update the mail id in the same line before use.


Suppose we have 3 Queue Managers and we need to run the script every 5 mins
reset_for_qmgr QM\!A_QM
reset_for_qmgr QM\!B_QM
reset_for_qmgr QM\!C_QM
Consider below equation:
Maximum script execution time per QM = (Cron Job Frequency) / (No. of Queue Managers)
(X + Y + Z + 5) = T/N
X --> Sleep time after channel stop 
Y --> Sleep time after channel reset
Z --> Sleep time to check if channel has come up after reset
T --> Cron Job Frequency (In this case, it'll be 300s)
N --> No. of Queue Managers
5s --> Miscellanous execution time 
All units are in seconds
Consider the worst-case scenario that at a time all 3 QMs will have to execute the channel reset i.e. 
time taken by each QM will be approx 5+5+100+5 = 115s
And for 3 QMs will be 115*3 = 345s which is more than 300s.
In this scenario, the script will be run again before we give time for it to complete causing the script to 
malfunction.
if we still want to run the script every 5 mins, then let's use the above equation and tune the sleep time
duration accordingly.
(X + Y + Z + 5) = T/N
(5 + 5 + Z + 5) = 300/3
Z = 100 - 15 = 85s
Therefore, you need to update the line 48 will sleep 85.



Deploy script for already running Queue Manager:

For already running Queue Managers, we need to sync up the reset record file because the error which 
had occurred before might be outdated and already actioned. In order to do this, we need to disable the 
script execution i.e comment all the lines in the "Execution" stanza, run the script once manually and 
revert the change by uncommenting all the lines in the Execution stanza.


DONT's:

1. Do not manually run the script while cron job is enabled.
2. Do not replicate the script into multiple scripts and run all together at the same time.
3. Do not use in Solaris Env.
4. Do not use the script if error log file rotation is linear. We need to make few changes.
Explanation: To keep track of number of appearances of the error, the active log file should be refreshed 
once it reaches the memory limit which is not the case for linearly
rotating error log files. Make below changes before using the script for linear error log files.
Before: 
cat -n seq_mis_reset_cron.sh | grep "uniq"
22 paste -d " " sdr_chl_list sdr_seq_nums | sort | uniq -c > new_reset_$qmgr
32 paste -d " " rcvr_chl_list rcvr_seq_nums | sort | uniq -c >> new_reset_$qmgr
After:
cat -n seq_mis_reset_cron.sh | grep "uniq"
22 paste -d " " sdr_chl_list sdr_seq_nums | sort | uniq > new_reset_$qmgr
32 paste -d " " rcvr_chl_list rcvr_seq_nums | sort | uniq >> new_reset_$qmgr
5. Do not use the script directly without reading these instructions
