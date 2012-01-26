use strict;
use warnings;
use utf8;
use DateTime;
use Data::Dumper;
################################################################################
=head DB schema

 CREATE TABLE `users` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `login` varchar(50) NOT NULL,
  `email` varchar(50) NOT NULL,
  `password` varchar(50) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `login` (`login`)
) ENGINE=InnoDB AUTO_INCREMENT=6 DEFAULT CHARSET=utf8;

CREATE TABLE `user_info` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `user_id` int(11) NOT NULL,
  `register_date` datetime NOT NULL,
  `visit_date` datetime NOT NULL,
  `last_ip` varchar(16) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `user_id` (`user_id`),
  CONSTRAINT `user_info_ibfk_1` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=5 DEFAULT CHARSET=utf8;

CREATE TABLE `session` (
  `sid` int(11) NOT NULL AUTO_INCREMENT,
  `expires` int(11) NOT NULL,
  `data` blob,
  PRIMARY KEY (`sid`)
) ENGINE=InnoDB AUTO_INCREMENT=516 DEFAULT CHARSET=utf8;

CREATE TABLE `topics` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `name` varchar(255) NOT NULL,
  `user_id` int(11) NOT NULL,
  `date_create` datetime NOT NULL,
  `date_update` datetime NOT NULL,
  `update_user_id` int(11) NOT NULL,
  PRIMARY KEY (`id`),
  KEY `user_id` (`user_id`),
  KEY `update_user_id` (`update_user_id`),
  KEY `topics` (`name`),
  CONSTRAINT `topics_ibfk_1` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`),
  CONSTRAINT `topics_ibfk_2` FOREIGN KEY (`update_user_id`) REFERENCES `users` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8

CREATE TABLE `messages` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `topic_id` int(11) NOT NULL,
  `body` text NOT NULL,
  `body_raw` text NOT NULL,
  `user_id` int(11) NOT NULL,
  `date_created` datetime NOT NULL,
  `user_ip` varchar(16) NOT NULL,
  `sid` int(11) NOT NULL,
  PRIMARY KEY (`id`),
  KEY `sid` (`sid`),
  KEY `user_id` (`user_id`),
  KEY `topic_id` (`topic_id`),
  CONSTRAINT `messages_ibfk_1` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`),
  CONSTRAINT `messages_ibfk_2` FOREIGN KEY (`topic_id`) REFERENCES `topics` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8

=cut
################################################################################
package My::DB;
 
use Rose::DB;
our @ISA = qw(Rose::DB);
 
#Singleton constructor
my $instance;
sub new{
	my $class = shift;
	
	unless(defined $instance && $instance->dbh->ping)
	{
		$instance = $class->SUPER::new(@_);
		$instance->dbh->{mysql_enable_utf8} = 1;
	}
	return $instance;
	
}
	
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

#Overloaded constructor whith some private fields initialization
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

#Set default error_mode 'return', better 
#check error manual, that use eval to catch every exception
sub init{
	my $self = shift;

	$self->SUPER::init(@_);
	
	$self->meta->error_mode('return');
}

#Prevent load method from raise error,
#just return 0 if load fail
sub load{
	my $self = $_[0];
	
	my $old_err = $self->error;
	
	my $old_err_mode = $self->meta->error_mode;
	
	$self->meta->error_mode('return') unless $old_err_mode ne 'return';
	
	my $ret = $self->SUPER::load(@_);
	
	$self->error($old_err) if $self->error ne $old_err;
	
	return $ret;
}

#Nonpersistent properties for object, not saved in database
sub extra{
	
	my $self = shift;
	
	my $param = shift;
	
	my $val = shift;
	
	if (defined $val && defined $param) { $self->{__EXTRA}->{$param} = $val }
	
	return $self->{__EXTRA}->{$param};
}

#Fill object properties from hash or hashref, according to 
#$self->{__ALLOW_FILL} array. Not containing properties puts to $self->extra
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

#Now object can store many errors! xD
sub errors{
	my $self = shift;
	
	my @params = @_;
	
	push @{$self->{__ERRORS}}, @params if @params;	
	
	return wantarray ? @{$self->{__ERRORS}} : join "\n", @{$self->{__ERRORS}};
}

#Overloaded method returns error string including $self->errors messages
sub error{
	my $self = shift;
	
	my $old_err = $self->SUPER::error(@_) || '';
	
	my $ret = "";

	$ret = join "\n", $self->errors, $old_err;
	
	return $ret;
}

#Clear multiple errors storage
sub clear_errors {
	my $self = shift;
	$self->{__ERRORS} = [];
	
};


sub init_db{ My::DB->new };

#Method raised before save object to database,
#you can do some validation here.
#If returns 0, save() method don't do anything real to store data in database
#Don't forget set up some errors if you return 0 from here
sub before_save{ 
		my $self = $_[0];
		
		return ! $self->errors;		
};

#Overloaded save() method
sub save{
	my $self = $_[0];
	
	$self->db->dbh->{PrintError}=0;
	
	return 0 unless $self->before_save(@_);
	
	$self->SUPER::save(@_);
};

#Method check is object present in  database
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
	

	if($self->is_new)
	{
		#Check new login not exists in database
		my $user_check = User->new(login=>$self->login);
		if($user_check->load)
		{
			$self->errors("Пользователь " . $self->login . " уже зарегистрирован!");
		}
		$user_check = undef;
		
		#Simple validation
		$self->errors("Логин не должен быть пустым") unless $self->login;
		$self->errors("Эл. почта не должна быть пустой") unless $self->email;
		$self->errors("Пароль не должен быть пустым") unless $self->extra('password1');
		$self->errors("Пароль и подтверждение пароля не совпадают")
			if($self->extra('password1') and ($self->extra('password1') ne $self->extra('password2')));
		
		
		
		#On save put password into sha1 hash for security reason
		$self->password(sha1_sum($self->extra('password1')));
		
		#Set related info
		$self->user_info(User_Info->new);

		$self->user_info->register_date(DateTime->now);
		$self->user_info->last_ip($self->extra('last_ip')) if $self->extra('last_ip');
		
	}	
	
	if(!$self->error)
	{
		$self->user_info->visit_date(DateTime->now);
	}
	
	return ! scalar $self->errors;
}

sub do_login{
	my $self = shift;
	
	my ($login,$pass) = @_;
	
	$self->login($login);
	
	$self->errors("Пользователь $login не зарегистрирован!") unless $self->load;
	
	if(!$self->not_found)
	{
		$self->errors("Неправильный пароль!") if $self->password ne sha1_sum($pass);
	}
	
	return ! $self->errors;
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
package User_Info;

__PACKAGE__->meta->setup
(
  table => 'user_info',
  auto  => 1,
);

use base qw(My::DB::Object);

__PACKAGE__->meta->auto_initialize;

1;
################################################################################
package Topic;

use base qw(My::DB::Object);

__PACKAGE__->meta->auto_initialize;

sub new{
	my $class = shift;
	my $self = $class->SUPER::new(@_);
	$self->init(@_);
	$self->{__ALLOW_FILL} = ['name'];
	return $self;
}

sub before_save{
		my $self = shift;
		
		#Simple validation
		$self->errors("Не указано название топика") unless $self->name;
		$self->errors("Невозможно определить автора топика") unless $self->user;
		
		
		#$self->errors("topic error 1");
		#$self->errors("topic error 2");
		#$self->errors("topic error 3");
		
		if($self->is_new)
		{
			$self->update_user($self->user) if $self->user;
			$self->date_create(DateTime->now);
			$self->date_update(DateTime->now);
		}
		
		return ! scalar $self->errors;
		
}

1;
################################################################################
package Topic::Manager;
 
use base 'Rose::DB::Object::Manager';
 
sub object_class { 'Topic' }
 
__PACKAGE__->make_manager_methods('topics');
 
1;
################################################################################
package Message;

use base qw(My::DB::Object);

__PACKAGE__->meta->auto_initialize;

sub new{
	my $class = shift;
	my $self = $class->SUPER::new(@_);
	$self->init(@_);
	$self->{__ALLOW_FILL} = [];
	return $self;
}

sub before_save{
		my $self = shift;
		
		#Simple validation
		$self->errors("Не указано сообщение") unless $self->body_raw;
		$self->errors("Невозможно определить автора сообщения") unless $self->user;
		$self->errors("Невозможно определить топик сообщения") unless $self->topic;
		
		if($self->is_new)
		{
			$self->body($self->body_raw);
			$self->date_create(DateTime->now);
			$self->user_ip($self->extra('ip') || '?.?.?.?');
			
			#fill sid (sub_id, numeration messages in topic)
			if($self->topic)
			{
				my $count = Message::Manager->get_messages_count(
								query => 
									[
										'topic_id' => $self->topic->id
									]
								) || 0;
				$self->sid($count+1);
			}
		}
		
		return ! scalar $self->errors;
		
}
1;
################################################################################
package Message::Manager;
 
use base 'Rose::DB::Object::Manager';
 
sub object_class { 'Message' }
 
__PACKAGE__->make_manager_methods('messages');
 
1;
################################################################################
