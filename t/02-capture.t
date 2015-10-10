use v6;
use Test;
use Router::Tiny;

subtest {
    my $r = Router::Tiny.new();
    dies-ok { $r.add('/blog/{id:(\d+)}', 'dispatch_month') };
}, 'Capture paren is exist';

subtest {
    my $r = Router::Tiny.new();
    lives-ok { $r.add('/blog/{id:[\d+]}', 'dispatch_month') };
}, 'Capture paren is not exist';

done-testing;

