package Nagios::Web::Controller::extinfo;

use strict;
use warnings;
use parent 'Catalyst::Controller';
use Nagios::Web::Helper;

=head1 NAME

Nagios::Web::Controller::extinfo - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut


=head2 index

=cut

##########################################################
sub index :Path :Args(0) :MyAction('AddDefaults') {
    my ( $self, $c ) = @_;
    my $type = $c->{'request'}->{'parameters'}->{'type'} || 0;

    my $infoBoxTitle;
    if($type == 0) {
        $infoBoxTitle = 'Nagios Process Information';
        $c->detach('/error/index/1') unless $c->check_user_roles( "authorized_for_system_information" );
        $self->_process_process_info_page($c);
    }
    if($type == 1) {
        $infoBoxTitle = 'Host Information';
        $self->_process_host_page($c);
    }
    if($type == 2) {
        $infoBoxTitle = 'Service Information';
        $self->_process_service_page($c);
    }
    if($type == 3) {
        $infoBoxTitle = 'All Host and Service Comments';
        $self->_process_comments_page($c);
    }
    if($type == 4) {
        $infoBoxTitle = 'Performance Information';
        $self->_process_perf_info_page($c);
    }
    if($type == 5) {
        $infoBoxTitle = 'Hostgroup Information';
        $self->_process_hostgroup_cmd_page($c);
    }
    if($type == 6) {
        $infoBoxTitle = 'All Host and Service Scheduled Downtime';
        $self->_process_downtimes_page($c);
    }
    if($type == 7) {
        $infoBoxTitle = 'Check Scheduling Queue';
        $self->_process_scheduling_page($c);
    }
    if($type == 8) {
        $infoBoxTitle = 'Servicegroup Information';
        $self->_process_servicegroup_cmd_page($c);
    }

    $c->stash->{title}          = 'Extended Information';
    $c->stash->{infoBoxTitle}   = $infoBoxTitle;
    $c->stash->{page}           = 'extinfo';
    $c->stash->{template}       = 'extinfo_type_'.$type.'.tt';
}


##########################################################
# SUBS
##########################################################

##########################################################
# create the downtimes page
sub _process_comments_page {
    my ( $self, $c ) = @_;
    $c->stash->{'hostcomments'}    = $c->{'live'}->selectall_arrayref("GET comments\n".Nagios::Web::Helper::get_auth_filter($c, 'comments')."\nColumns: host_name id source type author comment entry_time entry_type expire_time expires\nFilter: service_description = ", { Slice => {} });
    $c->stash->{'servicecomments'} = $c->{'live'}->selectall_arrayref("GET comments\n".Nagios::Web::Helper::get_auth_filter($c, 'comments')."\nColumns: host_name service_description id source type author comment entry_time entry_type expire_time expires\nFilter: service_description != ", { Slice => {} });
}

##########################################################
# create the downtimes page
sub _process_downtimes_page {
    my ( $self, $c ) = @_;
    $c->stash->{'hostdowntimes'}    = $c->{'live'}->selectall_arrayref("GET downtimes\n".Nagios::Web::Helper::get_auth_filter($c, 'downtimes')."\nFilter: service_description = \nColumns: author comment end_time entry_time fixed host_name id start_time triggered_by", { Slice => {} });
    $c->stash->{'servicedowntimes'} = $c->{'live'}->selectall_arrayref("GET downtimes\n".Nagios::Web::Helper::get_auth_filter($c, 'downtimes')."\nFilter: service_description != \nColumns: author comment end_time entry_time fixed host_name id service_description start_time triggered_by", { Slice => {} });
}

##########################################################
# create the host info page
sub _process_host_page {
    my ( $self, $c ) = @_;
    my $host;

    my $backend  = $c->{'request'}->{'parameters'}->{'backend'};
    my $hostname = $c->{'request'}->{'parameters'}->{'host'};
    $c->detach('/error/index/5') unless defined $hostname;
    my $hosts = $c->{'live'}->selectall_hashref("GET hosts\n".Nagios::Web::Helper::get_auth_filter($c, 'hosts')."\nFilter: name = $hostname\nColumns: has_been_checked accept_passive_checks acknowledged action_url address alias checks_enabled check_type current_attempt current_notification_number event_handler_enabled execution_time flap_detection_enabled groups icon_image icon_image_alt is_executing is_flapping last_check last_notification last_state_change latency long_plugin_output max_check_attempts name next_check notes notes_url notifications_enabled obsess_over_host parents percent_state_change perf_data plugin_output scheduled_downtime_depth state state_type", 'peer_key', {AddPeer => 1});

    # we only got one host
    if(scalar keys %{$hosts} == 1) {
        my @data = values(%{$hosts});
        $host = $data[0];
    }
    else {
        if(defined $backend and defined $hosts->{$backend}) {
            $host = $hosts->{$backend};
        } else {
            my @data = values(%{$hosts});
            $host = $data[0];
        }
    }

    $c->detach('/error/index/5') unless defined $host;

    my @backends = keys %{$hosts};
    $self->_set_backend_selector($c, \@backends, $host->{'peer_key'});

    $c->stash->{'host'}     = $host;
    my $comments            = $c->{'live'}->selectall_arrayref("GET comments\n".Nagios::Web::Helper::get_auth_filter($c, 'comments')."\nFilter: host_name = $hostname\nFilter: service_description =\nColumns: author id comment entry_time entry_type expire_time expires persistent source", { Slice => 1 });
    my $sortedcomments      = Nagios::Web::Helper->sort($c, $comments, 'id', 'DESC');
    $c->stash->{'comments'} = $sortedcomments;
}

##########################################################
# create the hostgroup cmd page
sub _process_hostgroup_cmd_page {
    my ( $self, $c ) = @_;

    my $hostgroup = $c->{'request'}->{'parameters'}->{'hostgroup'};
    $c->detach('/error/index/5') unless defined $hostgroup;

    my $groups = $c->{'live'}->selectall_hashref("GET hostgroups\n".Nagios::Web::Helper::get_auth_filter($c, 'hostgroups')."\nColumns: name alias\nFilter: name = $hostgroup\nLimit: 1", 'name');
    my @groups = values %{$groups};
    $c->detach('/error/index/5') unless defined $groups[0];

    $c->stash->{'hostgroup'}       = $groups[0]->{'name'};
    $c->stash->{'hostgroup_alias'} = $groups[0]->{'alias'};
}

##########################################################
# create the service info page
sub _process_service_page {
    my ( $self, $c ) = @_;
    my $service;
    my $backend  = $c->{'request'}->{'parameters'}->{'backend'};

    my $hostname = $c->{'request'}->{'parameters'}->{'host'};
    $c->detach('/error/index/5') unless defined $hostname;

    my $servicename = $c->{'request'}->{'parameters'}->{'service'};
    $c->detach('/error/index/5') unless defined $servicename;

    my $services = $c->{'live'}->selectall_hashref("GET services\n".Nagios::Web::Helper::get_auth_filter($c, 'services')."\nFilter: host_name = $hostname\nFilter: description = $servicename\nColumns: has_been_checked accept_passive_checks acknowledged action_url checks_enabled check_type current_attempt current_notification_number description event_handler_enabled execution_time flap_detection_enabled groups host_address host_alias host_name icon_image icon_image_alt is_executing is_flapping last_check last_notification last_state_change latency long_plugin_output max_check_attempts next_check notes notes_url notifications_enabled obsess_over_service percent_state_change perf_data plugin_output scheduled_downtime_depth state state_type", 'peer_key', {AddPeer => 1});

    # we only got one service
    if(scalar keys %{$services} == 1) {
        my @data = values(%{$services});
        $service = $data[0];
    }
    else {
        if(defined $backend and defined $services->{$backend}) {
            $service = $services->{$backend};
        } else {
            my @data = values(%{$services});
            $service = $data[0];
        }
    }

    $c->detach('/error/index/5') unless defined $service;

    my @backends = keys %{$services};
    $self->_set_backend_selector($c, \@backends, $service->{'peer_key'});

    $c->stash->{'service'}  = $service;
    my $comments            = $c->{'live'}->selectall_arrayref("GET comments\n".Nagios::Web::Helper::get_auth_filter($c, 'comments')."\nFilter: host_name = $hostname\nFilter: service_description = $servicename\nColumns: author id comment entry_time entry_type expire_time expires persistent source", { Slice => 1 });
    my $sortedcomments      = Nagios::Web::Helper->sort($c, $comments, 'id', 'DESC');
    $c->stash->{'comments'} = $sortedcomments;
}

##########################################################
# create the servicegroup cmd page
sub _process_servicegroup_cmd_page {
    my ( $self, $c ) = @_;

    my $servicegroup = $c->{'request'}->{'parameters'}->{'servicegroup'};
    $c->detach('/error/index/5') unless defined $servicegroup;

    my $groups = $c->{'live'}->selectall_hashref("GET servicegroups\n".Nagios::Web::Helper::get_auth_filter($c, 'servicegroups')."\nColumns: name alias\nFilter: name = $servicegroup\nLimit: 1", 'name');
    my @groups = values %{$groups};
    $c->detach('/error/index/5') unless defined $groups[0];

    $c->stash->{'servicegroup'}       = $groups[0]->{'name'};
    $c->stash->{'servicegroup_alias'} = $groups[0]->{'alias'};
}

##########################################################
# create the scheduling page
sub _process_scheduling_page {
    my ( $self, $c ) = @_;

    my $sorttype   = $c->{'request'}->{'parameters'}->{'sorttype'}   || 1;
    my $sortoption = $c->{'request'}->{'parameters'}->{'sortoption'} || 7;

    my $order = "ASC";
    $order = "DESC" if $sorttype == 2;

    my $sortoptions = {
                '1' => [ ['host_name', 'description'],   'host name'       ],
                '2' => [ 'description',                  'service name'    ],
                '4' => [ 'last_check',                   'last check time' ],
                '7' => [ 'next_check',                   'next check time' ],
    };
    $sortoption = 7 if !defined $sortoptions->{$sortoption};

    my $services = $c->{'live'}->selectall_arrayref("GET services\n".Nagios::Web::Helper::get_auth_filter($c, 'services')."\nColumns: host_name description next_check last_check check_options active_checks_enabled\nFilter: active_checks_enabled = 1\nFilter: check_options != 0\nOr: 2", { Slice => {} });
    my $hosts    = $c->{'live'}->selectall_arrayref("GET hosts\n".Nagios::Web::Helper::get_auth_filter($c, 'hosts')."\nColumns: name next_check last_check check_options active_checks_enabled\nFilter: active_checks_enabled = 1\nFilter: check_options != 0\nOr: 2", { Slice => {}, rename => { 'name' => 'host_name' } });
    my $queue    = Nagios::Web::Helper->sort($c, [@{$hosts}, @{$services}], $sortoptions->{$sortoption}->[0], $order);
    $c->stash->{'queue'}   = $queue;
    $c->stash->{'order'}   = $order;
    $c->stash->{'sortkey'} = $sortoptions->{$sortoption}->[1];
}


##########################################################
# create the process info page
sub _process_process_info_page {
    my ( $self, $c ) = @_;

    # all other data is already set in addDefaults
    my @possible_backends             = $c->{'live'}->peer_key();
    $c->stash->{'backends'}           = \@possible_backends;
    $c->stash->{'nagios_data_source'} = $c->{'live'}->peer_name();
}

##########################################################
# create the performance info page
sub _process_perf_info_page {
    my ( $self, $c ) = @_;

    my $stats      = Nagios::Web::Helper->get_service_exectution_stats($c);
    my $live_stats = $c->{'live'}->selectrow_arrayref("GET status\n".Nagios::Web::Helper::get_auth_filter($c, 'status')."\nColumns: connections connections_rate host_checks host_checks_rate requests requests_rate service_checks service_checks_rate neb_callbacks neb_callbacks_rate", { Slice => 1, Sum => 1 });

    $c->stash->{'stats'}      = $stats;
    $c->stash->{'live_stats'} = $live_stats;
}

##########################################################
# show backend selector
sub _set_backend_selector {
    my ( $self, $c, $backends, $selected ) = @_;
    my %backends = map { $_ => 1 } @{$backends};

    my @backends;
    my @possible_backends = $c->{'live'}->peer_key();
    for my $back (@possible_backends) {
        next if !defined $backends{$back};
        push @backends, $back;
    }

    $c->stash->{'backends'} = \@backends;
    $c->stash->{'backend'}  = $selected;
}

=head1 AUTHOR

Sven Nierlein, 2009, <nierlein@cpan.org>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
