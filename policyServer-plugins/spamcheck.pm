#########################################################
# Spamcheck plugin    		                        #
#########################################################

package spamcheck;

use strict;
use plugin;
our @ISA = qw(plugin);

# add your limits here
my $LIMITS = {
        'maxRecipientsPerMail' => 1000,
        'maxRecipientsPerDay' => 5000,

        'maxConnPerHour' => 1000,

        'maxRecipientsPerMinute' => {
                'recipients' => 10,
                'maxcount' => 5,
        },
};

sub new {
	my $class = shift;
        my $self = $class->SUPER::new();
        $self->{'needed_attr'} = ['sasl_username','recipient_count'];

        return $self;
}

sub init {
	my $self = shift;
	# be more verbose
	$self->{'actions'}->{'reject'} = 'reject You are blocked due to our spamming detection system!';

	return $self;
}

sub validate {
	my $self = shift;

	# check blocked user table
	my $sqlresult = $self->exec_sql("SELECT COUNT(*) AS total FROM blocked_user WHERE sasl_username = ?", $self->attr->{'sasl_username'});

	my $res = $sqlresult->fetchrow_hashref();
	
	# blocked user -> deny 
	if ($res->{'total'} > 0) {
		$self->log('info', 'Reject blocked user [%s]',$self->attr->{'sasl_username'});
		return $self->set_action('reject');
	}
	
	# checks 
	# check recipient_count of this mail
	if ($self->attr->{'recipient_count'} > $LIMITS->{'maxRecipientsPerMail'}) {
		my $msg = sprintf('User [%s] exceeded maxRecipientsPerMail limit [%u > %u]',$self->attr->{'sasl_username'},$self->attr->{'recipient_count'},$LIMITS->{'maxRecipientsPerMail'});
		$self->log('info',$msg);
		return $self->_is_allowed_spammer ? $self->set_action('permit') : $self->_block_user('maxRecipientsPerMail',$msg);
	}
		
	# check user mails of the last minute
	$sqlresult = $self->exec_sql("SELECT COUNT(*) AS total FROM accounting 
			      	       WHERE sasl_username = ?
				       AND timestamp > NOW() - INTERVAL 1 MINUTE 
			      	       AND recipient_count > ?", $self->attr->{'sasl_username'}, $LIMITS->{'maxRecipientsPerMinute'}->{'recipients'});

	$res = $sqlresult->fetchrow_hashref();
	if ($res->{'total'} >  $LIMITS->{'maxRecipientsPerMinute'}->{'maxcount'}) {
		my $msg = sprintf('User [%s] reached maxRecipientsPerMinute limit [%u mails > %u recipients]',$self->attr->{'sasl_username'},$LIMITS->{'maxRecipientsPerMinute'}->{'maxcount'}, $LIMITS->{'maxRecipientsPerMinute'}->{'recipients'});
		$self->log('info',$msg);
		return $self->_is_allowed_spammer ? $self->set_action('permit') : $self->_block_user('maxRecipientsPerMinute',$msg);
	}

	# connection count of the last hour
	$sqlresult = $self->exec_sql("SELECT COUNT(*) AS total FROM accounting 
				      WHERE sasl_username = ? 
				      AND timestamp > NOW() - INTERVAL 1 HOUR", $self->attr->{'sasl_username'});
		
	$res = $sqlresult->fetchrow_hashref();
	if ($res->{'total'} >  $LIMITS->{'maxConnPerHour'}) {
		my $msg = sprintf('User [%s] reached maxConnPerHour limit [%u]',$self->attr->{'sasl_username'},$LIMITS->{'maxConnPerHour'});
		$self->log('info',$msg);
                return $self->_is_allowed_spammer ? $self->set_action('permit') : $self->_block_user('maxConnPerHour',$msg);
        }

	# recipients per day
	$sqlresult = $self->exec_sql("SELECT COALESCE(SUM(recipient_count),0) AS total FROM accounting 
				      WHERE sasl_username = ? 
				      AND timestamp > NOW() - INTERVAL 1 DAY", $self->attr->{'sasl_username'});

	$res = $sqlresult->fetchrow_hashref();
	if ($res->{'total'} >  $LIMITS->{'maxRecipientsPerDay'}) {
		my $msg = sprintf('User [%s] reached maxRecipientsPerDay limit [%u]',$self->attr->{'sasl_username'},$LIMITS->{'maxRecipientsPerDay'});
		$self->log('info',$msg);
                return $self->_is_allowed_spammer ? $self->set_action('permit') : $self->_block_user('maxRecipientsPerDay',$msg);
        }
	# seems to be ok
	return $self->set_action('permit');
}

sub _block_user {
	my $self = shift;

	my $reason = shift;
	my $msg = shift;

	$self->exec_sql("INSERT INTO blocked_user (sasl_username, reason) 
			 VALUES (?, ?) 
			 ON DUPLICATE KEY UPDATE timestamp = NOW()", $self->attr->{'sasl_username'}, $reason);

	$self->log('info','User [%s] added to blocked_user!',$self->attr->{'sasl_username'});

	# send support mail
	$self->send_mail('Spamcheck ['.$self->get_option('peerhost').']: user '.$self->attr->{'sasl_username'}.' disabled!',$msg);
	# reject user
	return $self->set_action('reject');
}

sub _is_allowed_spammer {
	my $self = shift;
	
	# check if user is in allowed spammer table
	my $sqlresult = $self->exec_sql("SELECT COUNT(*) AS total FROM allowed_spammer WHERE sasl_username = ?", $self->attr->{'sasl_username'});
        my $res = $sqlresult->fetchrow_hashref();
       
	if ($res->{'total'} > 0) {
		$self->log('info', 'Permit allowed spammer [%s] sending mail to %u recipient(s)',$self->attr->{'sasl_username'},$self->attr->{'recipient_count'});
		return 1;
	} else {
		return 0;
	} 
}

1;
