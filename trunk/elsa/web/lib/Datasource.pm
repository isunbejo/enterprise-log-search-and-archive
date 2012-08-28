package Datasource;
use Moose;
use Log::Log4perl;

# Base class for Datasource plugins
has 'conf' => (is => 'rw', isa => 'Object', required => 1);
has 'log' => (is => 'rw', isa => 'Object', required => 1);
has 'name' => (is => 'rw', isa => 'Str', required => 1, default => '');
has 'args' => (is => 'rw', isa => 'ArrayRef', required => 1, default => sub { [] });

sub query {
	my $self = shift;
	my $q = shift;

	$self->_is_authorized($q) or die('Unauthorized');
	#$self->_build_query($q);
	$self->_query($q);
	
	return $q;	
}

1;