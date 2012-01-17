use strict;
use warnings;
use utf8;

use DateTime;
use Data::Dumper;
################################################################################
package My::DB;
 
use Rose::DB;
our @ISA = qw(Rose::DB);
 
My::DB->register_db(
  domain   => 'development',
  type     => 'session',
  driver   => 'mysql',
  database => 'test_db',
  host     => 'localhost',
  username => 'test_db',
  password => 'test_db_$3c9|3T'
);

My::DB->default_domain('development');
My::DB->default_type('session');
1;
################################################################################
package My::DB::Object; 
use base 'Rose::DB::Object';

sub new
{
	
	my($class) = shift;

	my $self = $class->SUPER::new(@_);

	$self->init(@_);
	
	$self->{__ERRORS} = [];
	$self->{__EXTRA} = {};
	$self->{__ALLOW_FILL} = [];

	return $self;
}

sub init{
	my $self = shift;

	$self->SUPER::init(@_);
	
	$self->meta->error_mode('return');
}

sub load{
	my $self = $_[0];
	my $old_err = $self->error;
	my $ret = $self->SUPER::load(@_);
	$self->error($old_err) unless $self->error ne $old_err;
	return $ret;
}

sub extra{
	my $self = shift;
	my $param = shift;
	my $val = shift;
	if (defined $val && defined $param) { $self->{__EXTRA}->{$param} = $val }
	return $self->{__EXTRA}->{$param};
}

sub fill {
	my $self = shift;
	
	my @params = @_;
	my $params;
	if(ref (my $first = shift @params))
	{
		$params = $first;
	}
	else
	{
		my %params = @_;
		$params = \%params;
	}
	
	my $columns = $self->meta->auto_generate_columns;
	
	for my $allow (@{$self->{__ALLOW_FILL}})
	{
		if(defined $params->{$allow} && defined $columns->{$allow})
		{
			$self->$allow($params->{$allow});
			delete $params->{$allow};
		}
		else
		{
			$self->{__EXTRA}->{$allow} = $params->{$allow};
			delete $params->{$allow};
		}
	}
	
	for my $allow (keys %$params)
	{
		$self->{__EXTRA}->{$allow} = $params->{$allow};
	}
	
}

sub error{
	my $self = shift;
	
	my $old_err = $self->SUPER::error(@_) || '';
	
	my $ret = "";

	$ret = join "\n", $self->errors, $old_err;
	
	return $ret;
}

sub errors{
	my $self = shift;
	
	my @params = @_;
	
	push @{$self->{__ERRORS}}, @params if @params;	
	
	return wantarray ? @{$self->{__ERRORS}} : join "\n", @{$self->{__ERRORS}};
}

sub clear_errors {
	my $self = shift;
	$self->{__ERRORS} = [];
	
};

sub init_db{ My::DB->new };


sub before_save{ 
		my $self = $_[0];
		
		return ! $self->errors;		
};

sub save{
	my $self = $_[0];
	
	$self->db->dbh->{PrintError}=0;
	
	return 0 unless $self->before_save(@_);
	
	$self->SUPER::save(@_);
};

sub is_new{
	my $self = shift;
	return ! Rose::DB::Object::Util::is_in_db($self);
}

1; 
################################################################################
package User;
use Mojo::Util qw(sha1_sum);

use base qw(My::DB::Object);

__PACKAGE__->meta->auto_initialize;


sub new{
	my $class = shift;
	my $self = $class->SUPER::new(@_);
	$self->init(@_);
	$self->{__ALLOW_FILL} = ['login', 'email'];
	return $self;
}

sub before_save{
	my $self = shift;
	
	#Simple validation
	$self->errors("Логин не должен быть пустым!") unless $self->login;
	$self->errors("Эл. почта не должна быть пустой!") unless $self->email;
	$self->errors("Пароль не должен быть пустым!") unless $self->extra('password1');
	$self->errors("Пароль и подтверждение пароля не совпадают!")
		if($self->extra('password1') and ($self->extra('password1') ne $self->extra('password2')));
	
	#On save put password into sha1 hash for security reason
	if($self->is_new && !$self->error)
	{
		$self->password(sha1_sum($self->extra('password1')));
	}	
	
	return ! scalar $self->errors;
}

#sub save{
#	my $self = $_[0];
#	return 0 unless $self->before_save(@_);

#	return $self->SUPER::save(@_)
#}
 
1;
################################################################################
package User::Manager;
 
use base 'Rose::DB::Object::Manager';
 
sub object_class { 'User' }
 
__PACKAGE__->make_manager_methods('users');
 
1;
################################################################################
