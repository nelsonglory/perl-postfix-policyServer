#########################################################
# Accounting plugin		                        #
# Infos of authenticated IMAP user connections are 	#
# stored in an accounting table.			#
# Has to be the first plugin (see policyServer-config)	#
#########################################################

package accounting;

use strict;
use plugin;
our @ISA = qw(plugin);


sub new {
	my $class = shift;
	my $self = $class->SUPER::new();	
	$self->{'needed_attr'} = ['queue_id','sasl_username','client_address','recipient_count']; 

        return $self;
}

sub validate {
	my $self = shift;

	# accounting
	$self->exec_sql("INSERT INTO accounting (queue_id,sasl_username,client_address,recipient_count) 
	 	         VALUES (?, ?, ?, ?)
			 ON DUPLICATE KEY UPDATE timestamp = NOW()", $self->attr->{'queue_id'}, $self->attr->{'sasl_username'}, $self->attr->{'client_address'}, $self->attr->{'recipient_count'});

	return $self->set_action('permit');
}

1;
