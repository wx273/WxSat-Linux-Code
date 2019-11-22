
####################
source config.cfg
####################

file=$1
echo "" >> ${dir}/jobs.log
echo ${file} >> ${dir}/jobs.log

echo "Decoding & resampling audio" >> ${dir}/jobs.log
sox ${file}.wav ${file}_norm.wav gain -n -2  # Normalise audio sample

echo "Demodulating wav using meteor_decoder" >> ${dir}/jobs.log
# Demodulate normalised sample using meteor_demod to qpsk or oqpsk file:
if [[ ${file: -2} == "M2" ]]; then
    yes | $demod -B -m qpsk -b 90 -f 64 -o ${file}.qpsk ${file}_norm.wav    
else
    yes | $demod -B -r ${M22RATE} -m oqpsk -o ${file}.qpsk ${file}_norm.wav
fi

# Preserve original file date/time
touch -r ${file}.wav ${file}.qpsk

echo "Decoding dec file" >> ${dir}/jobs.log
# Decode using medet - creates .dec & .bmp:
if [[ ${file: -2} == "M2" ]]; then
    # Settings for M2
    $decoder ${file}.qpsk ${file} -cd -r 65 -g 65 -b 64 -q       # For RGB 125
    #$decoder ${file}.qpsk ${file} -cd -q	                 # For RGB 123
else
    # Settings for M2-2
    $decoder ${file}.qpsk ${file} -diff -cd -r 65 -g 65 -b 64 -q # For RGB 125
    #$decoder ${file}.qpsk ${file} -diff -cd -q	                 # For RGB 123

# Use -diff for M2-2
# Use -int for 80k signal, such as:
#    $decoder ${file}.qpsk ${file} -int -cd -q
fi

touch -r ${file}.wav ${file}.dec

# Convert Bitmap image to PNG
echo "Coverting bitmap to png" >> ${dir}/jobs.log
convert -quiet ${file}.bmp ${file}.png

touch -r ${file}.wav ${file}.png

# Cleanup files except decoded data and output image
#rm -f ${file}_norm.wav ${file}.wav ${file}.qpsk ${file}.bmp
#rm -f ${file}.dec

# Test if image is too dark & if so process with IR settings
echo "Checking image brightness" >> ${dir}/jobs.log
BRIGHTNESS=`magick identify -verbose ${file}.png | grep mean | tail -1 | awk '{print $2}' | awk -F"." '{print $1}'`

if [ ${BRIGHTNESS} -lt 20 ] ; then
  echo "Image too dark - re-decoding with IR settings" >> ${dir}/jobs.log
  ${decoder} ${file}.dec ${file} -d -q -r 68 -b 68 -g 68
  echo "Contrast enhance IR image using CLAHE filter" >> ${dir}/jobs.log
  /usr/bin/magick ${file}.bmp -virtual-pixel mirror -clahe 300x300+128+2 ${file}.png
  rm ${file}.bmp   # Remove the old bitmap file
else
  echo "Image brightness ok - contrast enhance vis image using CLAHE filter" >> ${dir}/jobs.log
  /usr/bin/magick ${file}.png -virtual-pixel mirror -clahe 300x300+128+2 ${file}a.png
  mv ${file}a.png ${file}.png   # Correct filename to png
  # Rectify the vis image - only works for 64-65-66 images
  echo "Rectifying Visible Image" >> ${dir}/jobs.log
  ${dir}/rectify.py ${file}.png ; mv ${file}.png.rec ${file}.png
fi

# Invert image if hour is > 12:00
HOUR=`echo ${file} | awk -F "/" '{print $NF}' | cut -c10,11`       # Calc current hour
if [ ${HOUR} -gt 12 ] ; then
  echo "Inverting image" >> ${dir}/jobs.log
  convert -quiet -rotate 180 ${file}.png ${file}.png.inv
  mv -f ${file}.png.inv ${file}.png
fi

# Copy final image to webdir and run webpage update script
cp ${file}.png ${webdir} 		# Copy file to www directory
cd ${webdir} ; ./makethumbs >/dev/null	# Rebuild web page
