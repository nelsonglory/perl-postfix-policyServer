#########################################################
# senderReject plugin                   	        #
# Checks table sender_blacklist	(regex)			#
#########################################################

package senderReject;

use strict;
use plugin;
our @ISA = qw(plugin);


sub new {
	my $class = shift;
	my $self = $class->SUPER::new();	
	$self->{'needed_attr'} = ['sender']; 

        return $self;
}

sub validate {
        my $self = shift;

        if ($self->check_mailaddr($self->attr->{'sender'})) {
                # check recipient_blacklist
                my $sqlresult = $self->exec_sql("SELECT sender FROM sender_blacklist");

                while (my $res = $sqlresult->fetchrow_hashref()) {
                        if ($self->attr->{'sender'} =~ /$res->{'sender'}/) {
                                $self->log('info','Sender address [%s] blocked by blacklist',$self->attr->{'sender'});
                                return $self->set_action('reject');
                        }
                }
        }
        return $self->set_action('permit');
}
1;
