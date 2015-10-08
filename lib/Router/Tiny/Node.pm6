use v6;

unit class Router::Tiny::Node;

has $.leaf is rw;
has Str $.key;
has @.children = [];

method add-node(Router::Tiny::Node:D: Str $child) {
    for @.children -> $c {
        if $c.key eq $child {
            return $c;
        }
    }

    my $new-node = Router::Tiny::Node.new(:key($child));
    @.children.push($new-node);
    return $new-node;
}

