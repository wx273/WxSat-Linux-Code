#!/bin/bash

###############################################
source ./config.cfg
###############################################

mkdir -p $output/noaa
mkdir -p $output/noaa/deleted
mkdir -p $output/meteor

sat="$1$2"
start=$3
stop=$4
specie=$1
elevation=$5

filename=`date --date=@${start} +%Y%m%d-%H%M%S`_${sat}
rectime=$[$stop-$start]
at_start=`date --date=@${start} +%H:%M`

if [ "$sat" == "NOAA15" ]; then
    #frequency=137.620
    frequency=${NOAA15}
    sampling=36
fi
if [ "$sat"  == "NOAA18" ]; then
    #frequency=137.9125
    frequency=${NOAA18}
    sampling=36
fi
if [ "$sat" == "NOAA19" ]; then
    #frequency=137.100
    frequency=${NOAA19}
    sampling=36
fi
if [ "$sat" == "METEOR-M2" ]; then
    frequency=${METEORM2}
    sampling=120
fi
if [ "$sat" == "METEOR-M22" ]; then
    frequency=${METEORM22}
    sampling=110
fi

# Logging:
echo `date --date=@${start} +%Y%m%d-%H%M%S` $sat $elevation>> recordings.log

# -s it the bandwidth

# Submit satellite:
if [ "$specie" == "NOAA" ]; then
    
    # Record: (-p 0.0, 55.0 ppm ????, added -E dc -A fast)
    echo "timeout $rectime rtl_fm  -f ${frequency}M -s ${sampling}k -g 25 -p 0.0 -E wav -E dc -E deemp -F 9 - | sox -t raw -e signed -c 1 -b 16 -r ${sampling}k - ${output}/noaa/${filename}.wav &>> jobs.log"  > job.txt 

    # Resample and Decode:
    echo "/bin/bash /home/user1/Satellite/code/apt.sh ${output}/noaa/${filename} &>> jobs.log" >> job.txt

    # Submission:
    at $at_start -f job.txt &> /dev/null
    rm job.txt



fi

if [ "$specie" == "METEOR-M" ] || [ "$specie" == "METEOR-M2" ]; then
    # Record:

    # Priority to Meteor's
    echo "pkill -9 rtl_fm" > job.txt

    echo "timeout $rectime rtl_fm -M raw -f ${frequency}M -s ${sampling}k -g 5 -p 0.0 | sox -t raw -r ${sampling}k -c 2 -b 16 -e s - -t wav ${output}/meteor/${filename}.wav rate 96k" >> job.txt
    
    # Resample and Decode:
    echo "/bin/bash lrpt.sh ${output}/meteor/${filename} &>> jobs.log" >> job.txt

    at $at_start -f job.txt &> /dev/null
    rm job.txt
    
fi
