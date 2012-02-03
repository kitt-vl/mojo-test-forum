package Life25;
use strict;
use warnings;
use Data::Dumper;
use Mojo::Base 'Mojolicious';
use MojoX::Session;
#use MojoX::Session::Store::Dbi;
use MojoX::Session::Store::File;
use Life25::MojoX::Session::Store::Dummy;
use Life25::DB;		
use Storable;
use Life25::Site;

#Singleton Mojox::Session
my $session;

#MySql session table schema:
#CREATE TABLE `session` (
#  `sid` int(11) NOT NULL AUTO_INCREMENT,
#  `expires` int(11) NOT NULL,
#  `data` blob,
#  PRIMARY KEY (`sid`)
#) ENGINE=InnoDB AUTO_INCREMENT=191 DEFAULT CHARSET=utf8 

sub session{
	
	$Storable::Deparse = $Storable::Eval = 1; 
	unless(defined $session)
	{
		$session = MojoX::Session->new(
			#store     => MojoX::Session::Store::Dbi->new(dbh  => My::DB->new->dbh),
			#store     => MojoX::Session::Store::File->new(), 
			store	   => Life25::MojoX::Session::Store::Dummy->new,
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
  #$self->secret(rand() . $$ . rand($$));	
  $self->secret('Mojolicious Rocksss!!');

  
  # Documentation browser under "/perldoc" (this plugin requires Perl 5.10)
  $self->plugin('PODRenderer');
  $self->plugin('Mii');
  
  #Default layout
  $self->defaults(layout => 'skeleton');

  # Routes
  my $r = $self->routes;

  # Normal route to controller
  $r->route('/:page', page => qr!\d+|.{0}!)->name('topic_list')->to(controller => 'site', action => 'index', page => 1);  
  $r->route('/topic/:topic/:page', topic => qr(\d+), page => qr(\d+|.{0}))->to(controller => 'site', action => 'topic' , page => 1);  
  $r->route('/topic/post')->via('post')->to(controller =>'site', action =>'new_message');

  $r->route('/register')->to(controller => 'site', action =>'register');
  $r->route('/login')->to(controller =>'site', action =>'login');
  $r->route('/logout')->to(controller =>'site', action =>'logout');
  $r->route('/show')->to(controller =>'site', action =>'show');
  $r->route('/user')->to(controller =>'site', action =>'user');
  $r->route('/topic/new')->via('post')->to(controller =>'site', action =>'new_topic');


  $r->route('/not_obvius_path/news/:news_id/custom_path/:page', news_id => qr(\d+), page => qr(\d+) )->name('news')->to(controller => 'site', action => 'news' ); 
  $r->route('/user/show/:uid')->to(controller =>'user', action =>'show');
  
  
  #Set server-storable session
  $self->hook(before_dispatch => sub {
	  my $c = shift;
	    
	  
	  my $s = $c->app->session;	  
	 	  
	  $s->tx($c->tx);
		
	  $s->create unless $s->load;
	  #$c->app->log->info('----------- sid = '. $s->sid . ' path = ' . $c->req->url);
	  $s->extend_expires; 
	  $s->flush;
	  
	  #$DB::single = 1;
	});
	
	#$self->hook(after_dispatch => sub {
			
			#my $c = shift;
			#return if $c->stash('mojo.static');
			
			#$DB::single = 1;

			#my $dom = $c->res->dom;
			#$dom->html->body->replace($dom->html->body->append_content('<br/><br/><br/>Nayaned at ' . time));
			#$c->res->body($dom->content_xml);
			##$c->res->body('some content');
			
		#});
}
1;
