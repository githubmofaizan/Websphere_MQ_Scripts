#!/bin/bash

reset_for_qmgr() {

a=$(echo $1 | awk '{print substr($1, 4)}')
b=$(echo QM.)
qmgr=$(echo $b$a)

#Grep all the sequence mismtach errors from the log
cat /var/mqm/qmgrs/QM\!$a/errors/AMQERR01.LOG | grep -i -A 6 AMQ9526 > seq_log

#Make a list of channels affected
cat seq_log | grep AMQ9526 | cut -d "'" -f2 > chl_list

#Segregate log for sender channels
cat chl_list | sed "s/.*/DIS CHL(&) CHLTYPE/" | runmqsc $qmgr | grep -i 'CHLTYPE(SDR)' | cut -d "(" -f2 | cut -d ")" -f1 > sdr_chl_list
grep -A 6 -f sdr_chl_list seq_log > sdr_seq_log

#Grep the sender sequence numbers
cat sdr_seq_log | grep "A message" > sdr_seq_line1
cat sdr_seq_log | grep "was expected" > sdr_seq_line2
paste sdr_seq_line1 sdr_seq_line2 | awk -F 'The remote host' '{print $1}' | grep -oE '[0-9]{0,9}' | awk 'NR % 2 == 0' > sdr_seq_nums
paste -d " " sdr_chl_list sdr_seq_nums | sort | uniq -c > new_reset_$qmgr

#Segregate log for receiver channels
cat chl_list | sed "s/.*/DIS CHL(&) CHLTYPE/" | runmqsc $qmgr | grep -i 'CHLTPYE(RCVR)' | cut -d "(" -f2 | cut -d ")" -f1 > rcvr_chl_list
grep -A 6 -f rcvr_chl_list seq_log > rcvr_seq_log

#Grep the recever sequence numbers
cat rcvr_seq_log | grep "A message" > rcvr_seq_line1
cat rcvr_seq_log | grep "was expected" > rcvr_seq_line2
paste rcvr_seq_line1 rcvr_seq_line2 | awk -F 'The remote host' '{print $1}' | grep -oE '[0-9]{0,9}' | awk 'NR % 2 == 1' > rcvr_seq_nums
paste -d " " rcvr_chl_list rcvr_seq_nums | sort | uniq -c >> new_reset_$qmgr

#Compare between new_reset_$qmgr and reset_rec_$qmgr to avoid repetitiveness
diff new_reset_$qmgr /$HOME/reset_rec_files/reset_rec_$qmgr | grep '<' | awk '{print $3}' > final_chl_list
diff new_reset_$qmgr /$HOME/reset_rec_files/reset_rec_$qmgr | grep '<' | awk '{print $4}' > final_seq_list

#Execution
if [[ -s final_chl_list ]]
then
        cat final_chl_list | sed "s/.*/STOP CHL(&)/" | runmqsc $qmgr
        sleep 5
        cat final_chl_list | sed "s/.*/RESET CHL(&)/" > reset_col1
        cat final_seq_list | sed "s/.*/SEQNUM(&)/" > reset_col2
        paste -d " " reset_col1 reset_col2 | runmqsc $qmgr
        sleep 5
        cat final_chl_list | sed "s/.*/START CHL(&)/" | runmqsc $qmgr
        sleep 100
        cat final_chl_list | sed "s/.*/DIS CHS(&)/" | runmqsc $qmgr | grep -B 1 AMQ8420 | grep CHS | cut -d "(" -f2 | cut -d ")" -f1 > unresetchls
        [ -s unresetchls ] && echo "Sending Mail..." && cat unresetchls | mailx -s "Waiting for channel(s) to come up" <mail_id> && echo "Mail Sent to" <mail_id>
        echo "Sequence number reset done successfully for $qmgr at `date`"
        rm reset_col1 reset_col2
fi

#Old and New file rotation
rm /$HOME/reset_rec_files/reset_rec_$qmgr
mv new_reset_$qmgr reset_rec_$qmgr
mv reset_rec_$qmgr /$HOME/reset_rec_files/

#Delete unwanted files
rm seq_log chl_list
rm sdr_chl_list sdr_seq_log sdr_seq_line1 sdr_seq_line2 sdr_seq_nums
rm rcvr_chl_list rcvr_seq_log rcvr_seq_line1 rcvr_seq_line2 rcvr_seq_nums
rm final_chl_list final_seq_list
}

reset_for_qmgr QM\!A_QM
reset_for_qmgr QM\!B_QM
