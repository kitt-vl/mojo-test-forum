package MojoX::Session::Store::Memory;
use base 'MojoX::Session::Store';
 
 my $instance;
 
sub new {
	unless(defined $instance)
	{
		my $class = shift;
		my $self = { '__store' => {} };
		$instance = bless $self, $class;
	}
	
	return $instance;
}

sub create {
    my ($self, $sid, $expires, $data) = @_;
   # ...
    return 1;
}
 
sub update {
    my ($self, $sid, $expires, $data) = @_;
    #...
    return 1;
}
 
sub load {
    my ($self, $sid) = @_;
    #...
    return ($expires, $data);
}
 
sub delete {
    my ($self, $sid) = @_;
    #...
    return 1;
}

1;
