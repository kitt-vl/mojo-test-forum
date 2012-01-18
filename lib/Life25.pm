package Life25;
use strict;
use warnings;
use Data::Dumper;
use Mojo::Base 'Mojolicious';
use MojoX::Session;
use MojoX::Session::Store::Dbi;
use Life25::DB;		


#Singleton Mojox::Session
my $session;

sub session{
	unless(defined $session)
	{
		$session = MojoX::Session->new(
			store     => MojoX::Session::Store::Dbi->new(dbh  => My::DB->new->dbh),
			transport => MojoX::Session::Transport::Cookie->new,
			ip_match  => 1,
			expires_delta => 3600,
		);
		$session->expires(3600);
	}
	
	return $session;
}

# This method will run once at server start
sub startup {
  my $self = shift;
  $self->secret(rand);	
  
  # Documentation browser under "/perldoc" (this plugin requires Perl 5.10)
  $self->plugin('PODRenderer');

  # Routes
  my $r = $self->routes;

  # Normal route to controller
  $r->route('/user/:taction/:id')->to(controller => 'site', action =>'r_test');
  $r->route('/register')->to(controller => 'site', action =>'register');
  $r->route('/test')->to(controller =>'site', action =>'test');
  $r->route('/welcome')->to('example#welcome');
  $r->route('/')->to('site#index');  
  
  #Set server-storable session
  $self->hook(before_dispatch => sub {
	  my $c = shift;
	    
	  my $s = $c->app->session;
	  
	  
	  $c->app->log->debug('S_EXPIRES = ' .  $s->expires);
	  
	  $s->tx($c->tx);

	  $s->create unless $s->load;
	  $s->extend_expires; 
	  $s->flush;
	});
}
1;
