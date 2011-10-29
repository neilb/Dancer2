use strict;
use warnings;
use Test::More import => ['!pass'];
use File::Spec;

use Carp;

my @hooks = qw(
    before_request
    after_request

    before_file_render
    after_file_render

    before_serializer
    after_serializer
);

my $tests_flags = {};
{
    use Dancer;
    set serializer => 'JSON';

    for my $hook (@hooks) {
        hook $hook => sub {
            $tests_flags->{$hook} ||= 0;
            $tests_flags->{$hook}++;
        };
    }

    get '/send_file' => sub {
        send_file(File::Spec->rel2abs(__FILE__), system_path => 1);
    };

    get '/' => sub { 
        "ok"
    };

    hook 'before_serializer' => sub {
        my $data = shift;
        push @{$data}, (added_in_hook => 1);
    };

    get '/json' => sub { 
        [ foo => 42 ]
    };
    
    # make sure we compile all the apps without starting a webserver
    main->dancer_app->finish;
}

use Dancer::Test;

subtest 'request hooks' => sub {
    my $r = dancer_response get => '/';
    is $tests_flags->{before_request}, 1, "before_request was called";
};

subtest 'serializer hooks' => sub {
    require 'JSON.pm';
    my $r = dancer_response get => '/json';
    my $json = JSON::to_json([foo => 42, added_in_hook => 1]);
    is $r->[2][0], $json, 'response is serialized';
    is $tests_flags->{before_serializer}, 1, 'before_serializer was called';
    is $tests_flags->{after_serializer}, 1, 'after_serializer was called';
};

subtest 'file render hooks' => sub {
    my $resp = dancer_response get => '/send_file';
    is $tests_flags->{before_file_render}, 1, "before_file_render was called";
    is $tests_flags->{after_file_render},  1, "after_file_render was called";

    $resp = dancer_response get => '/file.txt';
    is $tests_flags->{before_file_render}, 2, "before_file_render was called";
    is $tests_flags->{after_file_render},  2, "after_file_render was called";
};

done_testing;
