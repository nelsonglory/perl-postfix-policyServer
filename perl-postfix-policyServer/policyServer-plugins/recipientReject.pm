#########################################################
# recipientReject plugin                   	        #
# Checks table recipient_blacklist (regex)		#
#########################################################

package recipientReject;

use strict;
use plugin;
our @ISA = qw(plugin);


sub new {
	my $class = shift;
	my $self = $class->SUPER::new();	
	$self->{'needed_attr'} = ['recipient']; 

        return $self;
}

sub validate {
	my $self = shift;

	if ($self->check_mailaddr($self->attr->{'recipient'})) {
		# check recipient_blacklist
		my $sqlresult = $self->exec_sql("SELECT recipient FROM recipient_blacklist");
				 
		while (my $res = $sqlresult->fetchrow_hashref()) {
			if ($self->attr->{'recipient'} =~ /$res->{'recipient'}/i) {
				$self->log('info','Recipient address [%s] blocked by blacklist',$self->attr->{'recipient'});
				return $self->set_action('reject');
			}
		}
	}
	return $self->set_action('permit');
}
1;
