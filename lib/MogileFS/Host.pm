package MogileFS::Host;
use strict;
use warnings;
use Net::Netmask;
use Carp qw(croak);

my $all_loaded = 0;
my %singleton;  # hostid -> instance

sub of_hostid {
    my ($class, $hostid) = @_;
    return undef unless $hostid;
    return $singleton{$hostid} ||= bless {
        hostid    => $hostid,
        _loaded   => 0,
    }, $class;
}

sub clear_cache {
    my ($class) = @_;
    # call old API
    Mgd::invalidate_host_cache("no_recurse");
    $all_loaded = 0;

    foreach my $host (values %singleton) {
        $host->{_loaded} = 0;
    }
}

sub reload_hosts {
    my $class = shift;

    # mark them all invalid for now, until they're reloaded
    foreach my $host (values %singleton) {
        $host->{_loaded} = 0;
    }

    Mgd::reload_host_cache();

    # get rid of ones that could've gone away:
    foreach my $hostid (keys %singleton) {
        my $host = $singleton{$hostid};
        delete $singleton{$hostid} unless $host->{_loaded}
    }

    $all_loaded = 1;
}

sub hosts {
    my $class = shift;
    $class->reload_hosts unless $all_loaded;
    return values %singleton;
}

# --------------------------------------------------------------------------

sub id { $_[0]{hostid} }

sub absorb_dbrow {
    my ($host, $hashref) = @_;
    foreach my $k (qw(status hostname hostip http_port http_get_port altip altmask)) {
        $host->{$k} = $hashref->{$k};
    }
    $host->{mask} = Net::Netmask->new2($host->{altmask})
        if $host->{altip} && $host->{altmask};

    $host->{_loaded} = 1;
}

sub http_port {
    my $host = shift;
    $host->_load;
    return $host->{http_port};

}

sub http_get_port {
    my $host = shift;
    $host->_load;
    return $host->{http_get_port} || $host->{http_port};
}

sub ip {
    my $host = shift;
    $host->_load;
    return $host->{hostip};
}

sub field {
    my ($host, $k) = @_;
    $host->_load;
    # TODO: validate $k to be in certain set of allowed keys?
    return $host->{$k};
}

sub status {
    my $host = shift;
    $host->_load;
    return $host->{status};
}

sub is_marked_down {
    my $host = shift;
    die "FIXME";
    # ...
}

sub exists {
    my $host = shift;
    $host->_try_load;
    return $host->{_loaded};
}

# --------------------------------------------------------------------------

sub _load {
    return if $_[0]{_loaded};
    Mgd::reload_host_cache();
    return if $_[0]{_loaded};
    my $host = shift;
    croak "Host $host->{hostid} doesn't exist.\n";
}

sub _try_load {
    return if $_[0]{_loaded};
    Mgd::reload_host_cache();
}


1;