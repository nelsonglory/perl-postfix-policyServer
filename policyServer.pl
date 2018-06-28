#!/usr/bin/perl -w -T

#########################################################
# Main policyServer based on Net::Server		#
# All configuration is done in policyServer.conf	#
# Configured plugins are read at server start		#
#							#
# rode 2017						#
#########################################################

package policyServer;

use base qw(Net::Server::Fork);
use strict;
# run server with hard coded configuration file path
__PACKAGE__->run(conf_file => '/usr/local/etc/policyServer.conf');

sub process_request {
	#########################################################
	# process_request method parses the input               #
	#########################################################

	my $self = shift;
	my $peerhost = $self->{'server'}->{'peerhost'} ? $self->{'server'}->{'peerhost'} : 'unknown';
	$self->log('info','Connect from client %s [%s]',$peerhost, $self->{'server'}->{'peeraddr'});

	eval {
		local $SIG{'ALRM'} = sub { die "timeout\n" };
		my $timeout = defined $self->{'server'}->{'timeout'} ? $self->{'server'}->{'timeout'} : 60;

		my $previous_alarm = alarm($timeout);
		my $attr = {};
		while (<STDIN>) {
        	        if (/^([^=]{1,512})=(.{1,512})?\n$/) {
                	        $attr->{$1} = $2;
                	} elsif ($_ eq "\n") {
				if (defined $attr->{'request'} && $attr->{'request'} eq 'smtpd_access_policy') {
					my $result = $self->plugin_validation($attr);
					# permit action if no plugin obj is returned
					my $action = $result ? $result->action : 'dunno';
					# reply result
					print STDOUT 'action='.$action."\n\n";
				}elsif (!defined $attr->{'request'}) {
					$self->log('err','No request key given!');
				} else {
					$self->log('err','Unrecognized request type [%s]',$attr->{'request'});
				}
				last;
                	} else {
                        	chop;
                        	$self->log('err','Ignoring garbage: %.100s',$_);
				last;
                	}
			alarm($timeout);
		}
		alarm($previous_alarm);
	};

	if ($@ =~ /timeout/) {
		$self->log('warning', 'Request timed out');
		return;
	}
}

sub read_plugins {
	#########################################################
        # Load configured plugins              			#
        #########################################################

	my $self = shift;

	return $self->{'plugins'} if (defined $self->{'plugins'}); 
	my $plugins = [];

	my $plugin_dir = $self->get_property('plugin_dir');
	my $plugin_str = $self->get_property('plugins');

	my @configured_plugins = split(',',$plugin_str);

	if (-d $plugin_dir) {
		unshift @INC, $plugin_dir;
		# if plugins existing -> use them
		foreach (@configured_plugins) {
			if (-f "$plugin_dir/$_.pm") {
				require $_.'.pm';
				$_->import();
				# instantiate plugins and return object array
				my $plugin = $_->new();
				# give plugin access to this server object
				$plugin->{'serverObj'} = $self;
				push(@$plugins,$plugin);
			} else { 
				$self->log('warning','Configured plugin [%s] not found!',$_);
			}
		}
		$self->{'plugins'} = $plugins;
	} else {
		$self->log('err','plugin_dir [%s] not found!',$plugin_dir);
	}
}

sub plugin_validation {
        #########################################################
        # Go through all configured plugins and call plugin 	#
	# call-method with args.			        #
        #########################################################

	my $self = shift;
	my $attr = shift;

	my $plugin = undef;
	# validate all plugins
	foreach(@{$self->{'plugins'}}) {
		$plugin = $_;
		my $result = 2;
		eval {
			$result = $plugin->call($attr);
		};
		if ($@) { 
			# something went wrong during verification - return temporary error
			$self->log('err','Plugin error [%s]: %s',$plugin->name,$@);
			last;
		}
		# permit
		next if $result == 1;
		# reject
		last if $result == 0;
	}
	# everything ok
	return $plugin;
}

sub post_configure_hook  {
	#########################################################
        # Hook called after plugin configuration via 		#
	# Net::Server     					#
        #########################################################
	
	my $self = shift;

	$self->read_plugins();
}

sub options {
	#########################################################
        # Overwrite Net::Server method to add additional       #
	# parameter to the configuration.			#
        #########################################################	

	my $self = shift;

	my $prop     = $self->{'server'};
	my $template = shift;
	
	# add new config parameters here
	my @new_options = qw(plugin_dir plugins timeout mysql_host mysql_db mysql_user mysql_password);

	# setup options in the parent classes
	$self->SUPER::options($template);

	for (@new_options) {
		$prop->{$_} = undef if !exists $prop->{$_};
		$template->{$_} = \$prop->{$_};
	}
	
}
1;
