cd /usr/local/src
curl http://ffmpeg.org/releases/ffmpeg-3.3.4.tar.bz2 | tar -xj

cd ffmpeg-3.3.4
./configure
make
make install
