#########################################################
# Basis plugin class 					#
# add  use plugin & our @ISA = qw(plugin) in the head   #
# of your plugin to use	it				#
# Important: validate method has to be overwritten in	#
# inherited classes					#
#########################################################

package plugin;

use strict;

use DBI;
use MIME::Lite;
our $AUTOLOAD;

#  vars
# standard mail configuration
my $MAIL = {
        'smtp.myhost.com' => {
		'mail-to' => 'support@myhost.com',
                'mail-from' => 'abuse@myhost.com',
        },
};

sub new {
        #########################################################
        # the constructor                                       #
        #########################################################

        my $class = shift;
        my $self = {};

	$self->{'attr'} = {};
	$self->{'needed_attr'} = [];
        $self->{'serverObj'} = {};
	$self->{'error'} = undef;
	$self->{'action'} = 'defer_if_permit Service is unavailable - please try again later!';
	# standard actions
	$self->{'actions'} = {
		'permit' => 'dunno',
		'reject' => 'reject',
	};

        # bless ref 
        bless($self,$class);

	# run init 
        return $self->init;
}

sub call {
	#########################################################
        # Main caller method used by the policyd		#
        #########################################################

	my $self = shift;
	$self->{'attr'} = shift;

	return $self->_check_attr ? $self->validate : $self->set_action('permit');
}

sub init {
        #########################################################
        # Private method which is called by constructor         #
        #########################################################

        my $self = shift;

        return $self;
}

sub validate {
	#########################################################
	# Main validation method				#
	# Has to be overwritten in inherited classes		#
	#########################################################

	my $self = shift;

	$self->log('warning','Plugin [%s] has no validate-method -> ignored!', $self->name);	
	$self->set_action('permit');
}

sub connectDB {
	#########################################################
        # Private method which is called by exec_sql		#
        #########################################################

        my $self = shift;

        # return DB handler is existing
        return $self->{'dbh'} if $self->{'dbh'} && $self->{'dbh'}->ping;

        $self->{'dbh'} = DBI->connect('DBI:mysql:database='.$self->get_option('mysql_db').';host='.$self->get_option('mysql_host'),
                                       $self->get_option('mysql_user'),
                                       $self->get_option('mysql_password')) || die (DBI->errstr);
        return $self->{'dbh'};
}

sub exec_sql {
	#########################################################
        # MySQL query method             			#
        #########################################################

        my $self = shift;
        my $sql = shift;

        my $dbh = $self->connectDB();

        my $query = $dbh->prepare($sql);
        $query->execute(@_) ||
                        die ($query->errstr()."[Query: $sql]");

        return $query;
}

sub get_option {
	#########################################################
        # Retrieve configuration parameters stored in policyd   #
        #########################################################

        my $self = shift;
        my $key = shift;

        return defined $self->{'serverObj'}->{'server'}->{$key} ? $self->{'serverObj'}->{'server'}->{$key} : '';
}

sub log {
	#########################################################
        # Handler for using policyd log facility  		#
        #########################################################

        my $self = shift;

        my $serverObj = $self->{'serverObj'};
        $serverObj->log(@_) if $serverObj;
}

sub send_mail {
	#########################################################
        # Send mail to configured mail host 		        #
        #########################################################

	my $self = shift;

        my $subject = shift;
        my $msg = shift;

	$ENV{PATH} = '/bin';
	my $host = $self->get_option('peerhost') ? $self->get_option('peerhost') : $self->get_option('peeraddr');
	if (defined $MAIL->{$host}) {

	my $mail = MIME::Lite->new(
		From	=> $MAIL->{$host}->{'mail-from'},
		To	=> $MAIL->{$host}->{'mail-to'},
		Subject => $subject,
		Data	=> $msg 
	);
	$mail->send;
	} else {
		$self->log('warning',"No mail configuration found for hostname [$host]");
	}
}

sub _check_attr {
	#########################################################
        # Check all attributes configured in $self->needed_attr	#
        #########################################################

	my $self = shift;

	foreach (@{$self->needed_attr}) {
		return 0 if !defined $self->{'attr'}->{$_};
	}
	return 1;
}

sub check_mailaddr {
	#########################################################
        # mailaddress check 					#
        #########################################################

        my $self = shift;
        my $mailaddr = shift;

        # simple regular expression check
        return ($mailaddr =~ /^[A-Za-z0-9\._%+-]+@[A-Za-z0-9\.-]+\.[A-Za-z]{2,6}$/) ? 1 : 0;
}

sub set_action {
	#########################################################
        # Set & return action					#
        #########################################################

	my $self = shift;
	my $action = shift;

	my $returnval = 2;
	$self->{'action'} = $self->{'actions'}->{$action} if defined $self->{'actions'}->{$action};

	$returnval = 0 if $action eq 'reject';
	$returnval = 1 if $action eq 'permit';

	return $returnval;
}

sub name {
	#########################################################
        # Returns the plugin name                               #
        #########################################################

	my $self = shift;

	 $self =~ /^([^=]+)/;
	 return $1;
}

sub AUTOLOAD {
        ###########################################################
        # gives access to objects properties                      #
        ###########################################################

        my $self = shift;
        my $type = ref($self) || die "$self is not an object!";

        my $property = $AUTOLOAD;

        $property =~ s/.*:://;
        return unless $property =~ /[^(DESTROY)]/;

        if (exists  $self->{$property}) { return @_ ? $self->{$property} = shift : $self->{$property}; }
        else { die "$property not existing in object $type!"; }
}

1;
