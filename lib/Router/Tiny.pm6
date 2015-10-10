use v6;
use Router::Tiny::Node;

unit class Router::Tiny;

has Router::Tiny::Node $!root = Router::Tiny::Node.new(:key("'/'"));
has Regex $!regexp;
has @!leaves;

# Matcher stuff
my $LEAF-IDX = 0;
my @CAPTURED = [];

# Compiler stuff
has Int $!_PAREN-CNT = 0;
has @!_LEAVES = [];
has @!_PARENS = [];

method !is-captured-group(Str $pattern) returns Bool {
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
        $/.make: $/;
    }
    method TOP($/) {
        $/.make: $<term>;
    }
}

method add(Router::Tiny:D: Str $path, $stuff) {
    my $p = $path;
    $p ~~ s!^'/'!!;

    $!regexp = Nil; # clear cache

    my $node = $!root;
    my @capture;
    my $matched = PathGrammar.parse($p, :actions(PathActions));
    for $matched.made -> $m {
        my $captured = $m.values[0].made.values[0];
        given $m.hash.keys[0] {
            when 'named-regex-capture' {
                my ($name, $pattern) = $captured.split(':', 2);
                if $pattern.defined && self!is-captured-group($pattern) {
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
                $node = $node.add-node("'$captured'");
            }
            default {
                die 'Unknown type has come';
            }
        }
    }

    $node.leaf = [[@capture], $stuff];
}

method match(Str $path) {
    $path = '/' if $path eq '';

    my $regexp = self!regexp;
    if $path.match($regexp).defined {
        my ($captured, $stuff) = @!leaves[$LEAF-IDX];
        my %captured;
        my $i = 0;
        for @CAPTURED.map({ .Str }) -> $cap {
            %captured{@$captured[$i]} = $cap;
            $i++;
        }

        return {
            stuff    => $stuff,
            captured => %captured
        };
    }

    return {};
}

method !regexp() {
    unless $!regexp.defined {
        self!build-regexp;
    }
    return $!regexp;
}

method !build-regexp() {
    temp @!_LEAVES = [];
    temp @!_PARENS = [];
    temp $!_PAREN-CNT = 0;

    my $re = self!to-regexp($!root);

    @!leaves = @!_LEAVES;
    $!regexp = rx{^<$re>};
}

method !to-regexp(Router::Tiny::Node $node) {
    temp @!_PARENS = @!_PARENS;

    my $key = $node.key;
    if $key.match(/'('/).defined {
        @!_PARENS.push($!_PAREN-CNT);
        $!_PAREN-CNT++;
    }

    my @re;
    if $node.children.elems > 0 {
        @re.push(| $node.children.map(-> $child { self!to-regexp($child) }));
    }

    if $node.leaf.isa(List) {
        @!_LEAVES.push($node.leaf);
        @re.push(sprintf(
            '${ $LEAF-IDX=%s; @CAPTURED = (%s) }',
            @!_LEAVES.elems - 1,
            @!_PARENS.map(-> $paren { "\$$paren" }).join(',')
        ));
        $!_PAREN-CNT = 0;
    }

    my $regexp = $node.key;
    if @re.elems == 1 {
        $regexp ~= @re[0];
    } elsif @re.elems == 0 {
        # nop
    } else {
        $regexp ~= '[' ~ @re.join('|') ~ ']';
    }

    return $regexp;
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
