use v6;
use Router::Tiny;

unit class Router::Tiny::Method;

has Router::Tiny $!router;

has %!data;

has @!path;
has %!path-seen;

method add(@method, $path, $stuff) {
    $!router = Nil; # clear cache

    unless %!path-seen{$path}++ {
        @!path.push($path);
    }

    %!data{$path}.push([@method, $stuff]);
}

method routes() {
    my @routes;

    for @!path -> $path {
        for @(%!data{$path}) -> @route {
            my ($method, $stuff) = @route;
            @routes.push([$method, $path, $stuff]);
        };
    };

    return @routes;
}

method !method-match(Str $request-method, @matcher) {
    if @matcher.elems === 0 {
        return True;
    }

    for @matcher -> $m {
        return True if $m eq $request-method;
    }

    return False;
}

method match(Str $request-method, Str $path) {
    unless $!router.defined {
        $!router = self!build-router;
    }

    if my $matched = $!router.match($path) {
        my @allowed_methods;

        for @($matched<stuff>) -> $pattern {
            if (self!method-match($request-method, $pattern[0])) {
                return {
                    stuff              => $pattern[1],
                    captured           => $matched<captured>,
                    is-method-not-allowed => False,
                    allowed-methods    => [],
                };
            }
            @allowed_methods.append(|$pattern[0])
        }
        return {
            stuff              => Nil,
            captured           => {},
            is-method-not-allowed => True,
            allowed-methods    => @allowed_methods,
        };
    }

    return {};
}

method regexp() {
    unless $!router.defined {
        $!router = self!build-router
    }
    return $!router;
}

method !build-router() {
    my $router = Router::Tiny.new;
    @!path.map(-> $path {
        $router.add($path, %!data{$path}) # TODO
    });
    return $router;
}

=begin pod

=head1 NAME

Router::Tiny::Method - blah blah blah

=end pod

