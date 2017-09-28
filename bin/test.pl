#! /usr/bin/env perl
use strict;
use warnings;
use Amazon::S3;
use Test::More;

use constant CONF => '/usr/local/videoguy.conf';

# read videoguy.conf
open my $fp_conf, CONF or die 'can\'t open videoguy.conf';
ok my @conf = map { chomp; $_; } grep { length; } <$fp_conf>;
close $fp_conf;
is @conf, 3, 'check videoguy.conf data';

my ($access_id, $access_key, $bucket_name) = @conf;

ok my $s3 = Amazon::S3->new(
    {   aws_access_key_id     => $access_id,
        aws_secret_access_key => $access_key,
        retry                 => 1
    }
);

ok my $buckets = $s3->buckets, 'buckets';
ok length $buckets->{owner_id}, 'check owner_id';
ok length $buckets->{owner_displayname}, 'check owner_displayname';

ok my $bucket = $s3->bucket($bucket_name);

my $test_key = $access_id.'_test_file';

$bucket->delete_key($test_key) if $bucket->head_key($test_key);
ok $bucket->add_key($test_key, $access_id), 'add_key';

ok my $obj = $bucket->get_key($test_key);
ok $obj->{content_length} > 0;
ok length $obj->{etag};
is $obj->{content_type}, 'binary/octet-stream';
is $obj->{value}, $access_id;

ok $bucket->delete_key($test_key), 'delete_key';

done_testing;
