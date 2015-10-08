use v6;
use Router::Tiny::Node;
unit class Router::Tiny;

has Router::Tiny::Node $.root is rw = Router::Tiny::Node.new(:key("'/'"));
has $.regexp is rw; # can private?
has @.leaves is rw; # can private?

# Compiler stuff
has Int $!_paren-cnt = 0;
has @!_leaves = [];
has @!_parens = [];

method !is-normal-capture(Str $pattern) returns Bool {
    # True if : ()
    # False if : []
    return $pattern.match(/'('/).defined;
}

my grammar PathGrammar {
    token named-regex-capture { \{ ( [\{<[0..9 ,]>+\} | <-[{ }]>+]+ ) \} } # /blog/{year:\d{4}}
    token named-capture       { ':' ( <[A..Z a..z  0..9 _]>+ ) }              # /blog/:year
    token wildcard            { \* }                                       # /blog/*/*
    token normal-string       { <-[{ : *]>+ }
    token term                { <named-regex-capture> | <named-capture> | <wildcard> | <normal-string> }

    rule TOP {
        ^ <term> | <term>* $
    }
}

my class PathActions {
    method named-regex-capture($/) {
        $/.make: ~$/.values[0];
    }
    method named-capture($/) {
        $/.make: ~$/.values[0];
    }
    method wildcard($/) {
        $/.make: ~$/;
    }
    method normal-string($/) {
        $/.make: ~$/;
    }
    method term($/) {
        # say $/;
        $/.make: $/;
    }
    method TOP($/) {
        $/.make: $<term>;
    }
}

method add(Router::Tiny:D: Str $path, Str $stuff) {
    my $p = $path;
    $p ~~ s!^'/'!!;

    # $.regexp = Nil; # clear cache

    my $node = $.root;
    my @capture;
    my $matched = PathGrammar.parse($p, :actions(PathActions));
    for $matched.made -> $m {
        my $captured = $m.values[0].made.values[0];
        given $m.hash.keys[0] {
            when 'named-regex-capture' {
                my ($name, $pattern) = $captured.split(':', 2);
                if $pattern.defined && self!is-normal-capture($pattern) {
                    die q{You can't include parens in your custom rule.};
                }
                @capture.push($name);
                $pattern = $pattern ?? "($pattern)" !! "(<-[/]>+)";
                $node = $node.add-node($pattern);
            }
            when 'named-capture' {
                @capture.push($captured);
                $node = $node.add-node("(<-[/]>+)");
            }
            when 'wildcard' {
                @capture.push('*');
                $node = $node.add-node("(.+)");
            }
            when 'normal-string' {
                $node = $node.add-node("'$captured'"); # TODO do not interpolate
            }
            default {
                # TODO
            }
        }
    }

    $node.leaf = [[@capture], $stuff];
}

method match(Str $path) {
    $path = '/' if $path eq '';

    my $regexp = self!regexp;
    if ($regexp.defined && $path.match($regexp).defined) {
    }

    return ();
}

method !regexp() {
    if !$.regexp.defined {
        self!build-regexp;
    }
    return $.regexp;
}

method !build-regexp() {
    temp @!_leaves = [];
    temp @!_parens = [];
    temp $!_paren-cnt = 0;

    my $re = self!to-regexp($.root);
    say $re;

    @.leaves = @!_leaves;
    $.regexp = rx{^<$re>};
}

method !to-regexp(Router::Tiny::Node $node) {
    # temp @!_parens = @!_parens;

    my $key = $node.key;
    if $key.match(/'('/).defined {
        $!_paren-cnt++;
        @!_parens.push($!_paren-cnt);
    }

    my @re;
    if ($node.children.elems > 0) {
        @re.push(
            $node.children.map(-> $child { self!to-regexp($child) })
        );
    }

    if ($node.leaf) {
    }

    my $re = $node.key;
    if (@re == 0) {
        # nop
    } elsif (@re == 1) {
        $re ~= @re[0];
    } else {
        $re ~= '[' ~ @re.join('|') ~ ']';
    }

    return $re;
}

=begin pod

=head1 NAME

Router::Tiny - blah blah blah

=head1 SYNOPSIS

  use Router::Tiny;

=head1 DESCRIPTION

Router::Tiny is ...

=head1 COPYRIGHT AND LICENSE

Copyright 2015 moznion <moznion@gmail.com>

This library is free software; you can redistribute it and/or modify it under the Artistic License 2.0.

=end pod
