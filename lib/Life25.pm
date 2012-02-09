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
use HTML::Packer;
use Life25::Site;
use Mojo::Util qw(sha1_sum);
use Time::HiRes qw/time/;

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

my $_cache;

sub cache{
	$_cache = Mojo::Cache->new unless defined $_cache;
	return $_cache;
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
  $r->route('/test')->to(controller =>'site', action =>'test');
  $r->route('/topic/new')->via('post')->to(controller =>'site', action =>'new_topic');


  $r->route('/not_obvius_path/news/:news_id/custom_path/:page', news_id => qr(\d+), page => qr(\d+) )->name('news')->to(controller => 'site', action => 'news' ); 
  $r->route('/user/show/:uid')->to(controller =>'user', action =>'show');
  
  #$self->log->level('info');
  
  #Set server-storable session
  #$self->hook(before_dispatch => sub {
	  #my $c = shift;
	  
	  #$c->stash('Mii.started' => time);
	    
	  
	  #my $s = $c->app->session;	  
	 	  
	  #$s->tx($c->tx);
		
	  #$s->create unless $s->load;
	  ##$c->app->log->info('----------- sid = '. $s->sid . ' path = ' . $c->req->url);
	  #$s->extend_expires; 
	  #$s->flush;
	  
		##return if $c->stash('mojo.static');
		###return if $c->req->content->headers->content_type !~ /html/i;
		###return unless defined $c->res->dom->at('html');


	  
	  ##my $key = sha1_sum($c->req->url->to_abs);
	  
	  ##$DB::single = 1;
	  
	  ##if(defined (my $val = $c->app->cache->get($key)))
	  ##{
			##$c->stash('Mii.cached' => 1);
			##$c->render_data($val);
			
	   ##}
	   ##my $tst = 1;

	#});
	
	#$self->hook(after_dispatch => sub {
			
			#my $c = shift;
			#return if $c->stash('mojo.static');
			#return if $c->res->content->headers->content_type !~ /html/i;
			#return unless defined $c->res->dom->at('html');
			
			##$DB::single = 1;
			
			##return if $c->stash('Mii.cached');
			

			##my $dom = $c->res->dom;
			##$dom->html->body->replace($dom->html->body->append_content('<br/><br/><br/>Сгенерировано за ' . (time - $c->stash('Mii.started')) . ' seconds'));
			
			#my $str_html = $c->res->dom->content_xml;
			
			#my $sm = Mii::ScriptManager->new;
			
			#my $js_str;
			#if (my @js = keys %{$sm->js_array})
			#{
					#$js_str = join "\n", map { "<script type='text/javascript' src='" . $_ . "' ></script>"} @js;
					#$c->app->log->info("ScriptManager js_array = ". $js_str);										
			#}
			
			#if($js_str){
				#$str_html =~ s{(\<\/\s*head\s*\>)}{$js_str $1}i;
			#}
			
			#my $gen_str = '<br/>!Сгенерировано за ' . (time - $c->stash('Mii.started')) . ' секунд!';
			#$str_html =~ s{(\<\/\s*body\s*\>)}{$gen_str $1}i;
			
			#$c->res->body($str_html);
			##my $key = sha1_sum($c->req->url->to_abs);
			##$c->app->cache->set($key => $dom->content_xml);

			
		#});
}
1;
