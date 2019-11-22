# WxSat-Linux-Code
Linux code to automate the reception and processing of NOAA and METEOR satellite data

This code is a fork of Paolo Franchini's work at https://github.com/pfranchini/weather-satellites and was born out of the frustration of doing this under Windows. Although great results are possible using Windows I found it too high maintenance to be feasible. Instead Linux scripts do the work here and the system is very reliable.

This code was developed on Manjaro Linux but should work on other distributions. It uses the following external code:

meteor_demodulator
medet

It also has the following dependencies:

Hardware - Software Defined Radio (SDR), suitable antenna (I use a homemade QFH), laptop or desktop with suitable Linux distro.

Software - wxtoimg (for NOAA satellites). rtl_fm package, sox, Imagemagick, rectify.py
