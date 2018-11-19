yum -y install nasm

cd /usr/local/src
curl http://ffmpeg.org/releases/ffmpeg-4.1.tar.bz2 | tar -xj

cd ffmpeg-4.1
./configure
make
make install
