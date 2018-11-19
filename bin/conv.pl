#! /usr/bin/env perl
use strict;
use warnings;
use Amazon::S3;
use Encode;

use constant {
    CONF => '/usr/local/videoguy.conf',
    FFMPEG_BINPATH => '/usr/local/bin/',
    TMP_FILE => '/tmp/tmpvideo.mp4',
    TMP_OUTPUT => '/tmp/tmpoutput.mp4',
};

# read videoguy.conf
open my $fp_conf, CONF or die 'can\'t open videoguy.conf';
my @conf = map { chomp; $_; } grep { length; } <$fp_conf> or die 'conf is empty';
close $fp_conf;
die 'conf is wrong' unless @conf == 3;

my ($access_id, $access_key, $bucket_name) = @conf;

my $s3 = Amazon::S3->new(
    {   aws_access_key_id     => $access_id,
        aws_secret_access_key => $access_key,
        retry                 => 3
    }
);

my $buckets = $s3->buckets;
if ($buckets && length $buckets->{owner_id} &&
                length $buckets->{owner_displayname}) {

    my $bucket = $s3->bucket($bucket_name) or die 'can\'t open bucket: '.$bucket_name;
    my $list = $bucket->list_all;

    my (@fn_mp4, @fn_profile, @fn_result);
    my @total_fn = grep { length; } map { lc $_->{key}; } @{$list->{keys}};

    # video mp4 files
    @fn_mp4 = grep { /\.mp4$/i } @total_fn;

    # video profile files
    @fn_profile = grep { /\.mp4.profile$/i } @total_fn;

    # video converted result files
    @fn_result = grep { /\.mp4.result$/i } @total_fn;

    my @jobs;

    for my $mp4 (@fn_mp4) {
        $mp4 = encode_utf8 $mp4 if $mp4;
        if (my $has_profile = (grep { $_ eq $mp4.'.profile' } @fn_profile) ? 1 : 0) {
            unless (my $converted = (grep { $_ eq $mp4.'.result' } @fn_profile) ? 1 : 0) {
                if (my $profile_data_value = ($bucket->get_key($mp4.'.profile') // {})->{value}) {
                    my $job = {
                        filename => $mp4,
                        profile => $profile_data_value,
                    };
                    push @jobs, $job;
                }
            }
        }
    }

    for my $job (@jobs) {
        next unless $job->{filename} =~ /(.+)\.mp4$/;
        my $prefix_filename = $1;
        if ($job->{profile} =~ /bitrate:([0-9k,]+)/m) {
            # delete tmp file if exist
            unlink (TMP_FILE, TMP_OUTPUT);

            my @arr_target_bitrates = split ",", $1;
            my @converted_bitrates;
            for my $target_bitrate (@arr_target_bitrates) {
                next unless $target_bitrate =~ /^(\d+)k$/;
                my $val_target_bitrate = $1;

                my $new_filename = sprintf '%s-%s.mp4', $prefix_filename, $target_bitrate;
                next if grep {$_ eq $new_filename} @fn_mp4;

                my $point1_retried = 0;
                retry_point1:
                unless ($bucket->get_key_filename($job->{filename}, 'GET', TMP_FILE)) {
                    if (++$point1_retried <= 2) {
                        goto retry_point1;
                    } else {
                        die 'downlaod file error:'. $job->{filename};
                    }
                }

                my $video_info = get_video_info(TMP_FILE);
                if (defined $video_info->{bitrate} && $video_info->{bitrate} <= $val_target_bitrate) {
                    system sprintf FFMPEG_BINPATH . 'ffmpeg -y -i "%s" -vcodec %s -b:v %s -loglevel quiet "%s"', TMP_FILE, $video_info->{codec}, $target_bitrate, TMP_OUTPUT;

                    # check video output
                    if (my $new_video_info = get_video_info(TMP_OUTPUT)) {
                        # upload video file
                        if ($bucket->add_key_filename($new_filename, TMP_OUTPUT)) {
                            push @converted_bitrates, $new_video_info->{bitrate};
                        }
                    }

                    # delete tmp files
                    unlink (TMP_FILE, TMP_OUTPUT);
                }
            }

            if (@converted_bitrates) {
                @converted_bitrates = map { $_ . 'k'; } @converted_bitrates;
                # write result file, finish it
                $bucket->add_key(
                    $job->{filename} . '.result',
                    'bitrate:'.(join ",", @converted_bitrates),
                );
            }
        }
    }
}

sub get_video_info {
    my $video_path = shift or return;
    return unless -r $video_path;
    my $video_metadata = readpipe FFMPEG_BINPATH . 'ffprobe -i ' . "\"$video_path\" 2>\&1" or return;

    my $ret = {};
    if ($video_metadata =~ /Stream.+Video: (.+)$/m) {
        my $stream_video = $1;
        if ($stream_video =~ /([^ ]+)/) {
            $ret->{codec} = $1;
        }
        if ($stream_video =~ / (\d+)x(\d+) /) {
            $ret->{size} = sprintf "%dx%d", $1, $2;
        }
        if ($stream_video =~ / (\d+) kb\/s/) {
            $ret->{bitrate} = int($1);
        }
    }
    return $ret if %$ret;
    return;
}
