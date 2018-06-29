#########################################################
# senderRecipientCheck plugin                           #
# Checks table user_blacklist which is maintained by 	#
# cronjobs on the mail backends				#
#########################################################

package senderRecipientCheck;

use strict;
use plugin;
our @ISA = qw(plugin);


sub new {
	my $class = shift;
	my $self = $class->SUPER::new();	
	$self->{'needed_attr'} = ['sender','recipient']; 

        return $self;
}

sub validate {
	my $self = shift;

	if ($self->check_mailaddr($self->attr->{'sender'}) && $self->check_mailaddr($self->attr->{'recipient'})) {
		# get user_blacklist entries
		my $sqlresult = $self->exec_sql("SELECT sender FROM user_blacklist
						 WHERE recipient = ?",$self->attr->{'recipient'});
			
		# go through results
		while(my $sender = $sqlresult->fetchrow_array) {
			# check sender
			if ($self->attr->{'sender'} =~ /^$sender$/) {
				$self->log('info','Sender address [%s] -> recipient address [%s] blocked by user blacklist',$self->attr->{'sender'},$self->attr->{'recipient'});
				return $self->set_action('reject');
			}
		}
	}
	return $self->set_action('permit');
}

1;
