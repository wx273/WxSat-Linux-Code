##!/usr/bin/bash
####################
source config.cfg
####################

#set -x
file=$1
if [[ ${file: -2} == "M2" ]]; then 
  SAT="M2"
fi
if [[ ${file: -2} == "22" ]]; then
  SAT="M22"
fi
fileshort=`echo $file | awk -F"/" '{print $NF}'`
echo "" >> ${dir}/jobs.log
echo "Start processing pass ${fileshort}" >> ${dir}/jobs.log

/usr/bin/printf "Resampling audio - " >> ${dir}/jobs.log
sox ${file}.wav ${file}_norm.wav gain -n -2  # Normalise audio sample
echo "complete" >> ${dir}/jobs.log

echo "Fetching happysat formats" >> ${dir}/jobs.log
#wget -q -O http://happysat.nl/Meteor/html/Meteor_Status.html
/usr/bin/curl -s -o Meteor_Status.html http://happysat.nl/Meteor/html/Meteor_Status.html
M2FORMAT=`grep Visible/IR Meteor_Status.html | sed 's/[^0-9]*//g' | head -1`
M22FORMAT=`grep Visible/IR Meteor_Status.html | sed 's/[^0-9]*//g' | tail -1`
M22RATE=`grep .000K Meteor_Status.html | tail -1 | sed 's/[^0-9]*//g'`

printf "Demodulating norm.wav using meteor_demod - \n" >> ${dir}/jobs.log
# Demodulate normalised sample using meteor_demod to qpsk or oqpsk file:
if [ ${SAT} == "M2" ]; then
    yes | $demod -q -B -m qpsk -b 90 -f 64 -o ${file}.qpsk ${file}_norm.wav
else
    yes | $demod -q -B -r ${M22RATE} -m oqpsk -o ${file}.qpsk ${file}_norm.wav
fi
echo "complete" >> ${dir}/jobs.log

# Preserve original file date/time
touch -r ${file}.wav ${file}.qpsk


printf "Decoding qpsk/opqsk file using medet - \n" >> ${dir}/jobs.log
# Decode using medet - creates .dec & .bmp:
if [ ${SAT} == "M2" ]; then
    # Settings for M2
    if [[ ${M2FORMAT} == "123" ]]; then
        $decoder ${file}.qpsk ${file} -cd -cn -q                    # For RGB 123
    elif [[ ${M2FORMAT} == "125" ]]; then
        $decoder ${file}.qpsk ${file} -cd -cn -r 65 -g 65 -b 64 -q  # For RGB 125
    fi
else
    # Settings for M2-2
    if [[ ${M22FORMAT} == "123" ]]; then
    $decoder ${file}.qpsk ${file} -diff -cd -cn -q                   # For RGB 123
    elif [[ ${M22FORMAT} == "125" ]]; then
    $decoder ${file}.qpsk ${file} -diff -cd -cn -r 65 -g 65 -b 64 -q # For RGB 125
    fi
fi
echo "complete" >> ${dir}/jobs.log


touch -r ${file}.wav ${file}.dec                # Preserve original file date/time

echo "Coverting bitmap to png" >> ${dir}/jobs.log
convert -quiet ${file}.bmp ${file}.png          # Convert Bitmap image to PNG

touch -r ${file}.wav ${file}.png                # Preserve original file date/time


echo "Checking image brightness" >> ${dir}/jobs.log
BRIGHTNESS=`magick identify -verbose ${file}.png | grep mean | tail -1 | awk '{print $2}' | awk -F"." '{print $1}'`

if [ ${BRIGHTNESS} -lt 20 ] ; then
  if [ ${SAT} == "M2" ] && [ ${M2FORMAT} == "125" ]; then
    printf "Image brightness only ${BRIGHTNESS} - re-decoding with IR settings - \n" >> ${dir}/jobs.log
    $decoder ${file}.qpsk ${file} -cd -cn -r 68 -g 68 -b 68 -q 
    echo "complete" >> ${dir}/jobs.log
    printf "Contrast enhance IR image using CLAHE filter - \n" >> ${dir}/jobs.log
    /usr/bin/magick ${file}.bmp -virtual-pixel mirror -clahe 300x300+128+2 ${file}.png # rm ${file}.bmp
    echo "complete" >> ${dir}/jobs.log
  #fi 
  elif [ ${SAT} == "M22" ] && [ ${M22FORMAT} == "125" ]; then
    printf "Image brightness only ${BRIGHTNESS} - re-decoding with IR settings - \n" >> ${dir}/jobs.log
    $decoder ${file}.qpsk ${file} -diff -cd -cn -r 68 -g 68 -b 68 -q
    echo "complete" >> ${dir}/jobs.log
    printf "Contrast enhance IR image using CLAHE filter - \n" >> ${dir}/jobs.log
    /usr/bin/magick ${file}.bmp -virtual-pixel mirror -clahe 300x300+128+2 ${file}.png # rm ${file}.bmp
    echo "complete" >> ${dir}/jobs.log
  fi 
else
  printf "Image brightness ok - contrast enhance vis image using CLAHE filter - \n" >> ${dir}/jobs.log
  /usr/bin/magick ${file}.png -virtual-pixel mirror -clahe 300x300+128+2 ${file}a.png
  echo "complete" >> ${dir}/jobs.log
  mv ${file}a.png ${file}.png   # Correct filename to png
  # Rectify the vis image - only works for 123 images
  printf "Rectifying Visible Image - \n" >> ${dir}/jobs.log
  ${dir}/rectify.py ${file}.png ; mv ${file}.png.rec ${file}.png
  echo "complete" >> ${dir}/jobs.log
fi

# Invert image if hour is > 12:00
HOUR=`echo ${file} | awk -F "/" '{print $NF}' | cut -c10,11`       # Calc current hour
if [ ${HOUR} -gt 12 ] ; then
  printf "Inverting image - \n" >> ${dir}/jobs.log
  convert -quiet -rotate 180 ${file}.png ${file}.png.inv
  mv -f ${file}.png.inv ${file}.png
  echo "complete" >> ${dir}/jobs.log
fi

# Check final image is not zero bytes before adding to www dir
if [ -s ${file}.png ] ; then

# Copy final image to webdir and run webpage update script
cp ${file}.png ${webdir}                # Copy file to www directory
cd ${webdir} ; ./makethumbs >/dev/null  # Rebuild web page

else
echo "Final image is zero bytes - not copying to www dir" >> ${dir}/jobs.log
fi

echo "Completed processing pass ${fileshort}" >> ${dir}/jobs.log






# Cleanup files except decoded data and output image
#rm -f ${file}_norm.wav ${file}.wav ${file}.qpsk ${file}.bmp
#rm -f ${file}.dec




