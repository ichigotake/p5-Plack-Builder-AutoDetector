package App::CrossGate;
use 5.008005;
use strict;
use warnings;
use parent 'Plack::Component';
use File::Basename qw/basename dirname/;
use Path::Tiny;
use Plack::Util;
use Plack::Builder;

our $VERSION = "0.05";

sub new {
    my $self = bless {}, shift;
}

sub to_app {
    my $self = shift;
    my %args = @_;

    my (undef, $filename, undef) = caller;
    $args{caller} = {
        filename => $filename,
        dirname  => dirname($filename),
    };

    my $builder = Plack::Builder->new;
    $builder->mount( '/', $self->_build_from_directory(%args) );
    $builder->to_app;
}

sub _build_from_directory {
    my $self = shift;
    my %args = @_;

    my @apps = $self->_get_app_configs_from_dir(%args);

    my $builder = Plack::Builder->new;
    for my $conf ( @apps ) {
        print "auto mount '$conf->{endpoint}' => $conf->{app_path}" . $/;
        $builder->mount( $conf->{endpoint} => $self->_build_app($conf->{app_path}) );
    }
    $builder->to_app;
}

sub _build_app {
    my $self = shift;
    my $path = shift;

    return Plack::Util::load_psgi("$path");
}

sub _get_app_configs_from_dir {
    my $self = shift;
    my %args = @_;

    my @apps;
    my $base_dir = path($args{ dir } || '.')->realpath;
    my $iter = $base_dir->iterator({
        recurse => 1,
        follow_symlinks => 0,
    });
    while ( my $app_path = $iter->() ) {
        
        if ($args{caller}->{filename} eq $app_path->realpath
            || ! -f $app_path
            || $app_path !~ m/\.psgi$/) {
            next;
        }

        my $endpoint = dirname($app_path->realpath);
        $endpoint =~ s/^$base_dir//;

        my ($psgi_name) = basename($app_path->realpath) =~ m/(.*)\.psgi/;
        if ('app' ne $psgi_name && basename($app_path->parent) ne $psgi_name) {
            $endpoint .= "/$psgi_name";
        }

        $endpoint = '/'.$endpoint unless $endpoint =~ m|^/|;

        (my $load_app_path = $app_path->realpath)
            =~ s|^$args{caller}->{dirname}/||;

        my $conf = +{
            endpoint => $endpoint,
            app_path => path($load_app_path),
        };
        push( @apps, $conf );
    }

    return @apps;
}

1;
__END__

=encoding utf-8

=head1 NAME

App::CrossGate - Multiple application connection gate

=head1 SYNOPSIS

    $ crossgate ./example/apps
    auto mount '/hey' => hey.psgi
    auto mount '/hello' => hello/app.psgi
    auto mount '/mount' => mount/app.psgi
    auto mount '/mount/deep' => mount/deep/app.psgi
    auto mount '/mount/deep/app2' => mount/deep/app2.psgi
    HTTP::Server::PSGI: Accepting connections at http://0:5000/

    # or

    # app.psgi with `plackup`
    use App::CrossGate;
    $app = App::CrossGate->new;
    $app->to_app(
        dir => './apps',
    );

    $ plackup

=head1 DESCRIPTION

This module is auto mount path for app.psgi.

Mount path is a directry path. And "app.psgi" is root path. ("/")

=head1 EXAMPLE

If this structure and app.psgi there,

    # app.psgi
    use App::CrossGate;
    $app = App::CrossGate->new;
    $app->to_app( dir => '.' );

    # directory structure
    |- app.psgi # to_app( dir => '.' );
    |- hey.psgi
    |- /hello
    |   `- app.psgi
    `- /mount
        |- app.psgi
        `- deep/
            |- app.psgi
            `- app2.psgi

same a following mount path.

    use Plack::Builder;

    builder {
        mount '/hey'             => Plack::Util::load_psgi('hey.psgi');
        mount '/hello'           => Plack::Util::load_psgi('hello/app.psgi');
        mount '/mount'           => Plack::Util::load_psgi('mount/app.psgi');
        mount '/mount/deep'      => Plack::Util::load_psgi('mount/deep/app.psgi');
        mount '/mount/deep/app2' => Plack::Util::load_psgi('mount/deep/app2.psgi');
    };

=head1 SEE ALSO

You can see "example/" directory for example detail.

Plack::Builder

=head1 LICENSE

Copyright (C) ichigotake.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHOR

ichigotake E<lt>k.wisiiy@gmail.comE<gt>

Special thanks

Songmu

=cut

