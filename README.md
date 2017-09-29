# videoguy
video convert agent guy

# how it works?

1. put a video file into your s3 bucket. for example name: MYVIDEO.mp4
2. and put a profile file at same bucket: MYVIDEO.mp4.profile
   put your target video bitrate into it. you can use comma into value for multi bitrate converting
```
bitrate:1500k,1024k,512k
```
3. run bin/conv.pl, it will convert videos for you, and generate files like thses:
```
MYVIDEO.mp4
MYVIDEO.mp4.profile
MYVIDEO.mp4.result
MYVIDEO-1500k.mp4
MYVIDEO-1024k.mp4
MYVIDEO-512k.mp4
```

4. converted file's info will be saved in a result file: MYVIDEO.mp4.result. and save real bitrate in it. sort is same as your profile's bitrate
```
bitrate:1484k,912k,489k
```

# todo

add notification when convert is over. return the result if it is succeed or failed.

# author

itsusony <meng.xiangliang1985@gmail.com>

# copyright

FreakOut 2017-
