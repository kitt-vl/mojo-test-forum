package Life25::User;
use strict;
use warnings;
use base 'Mojolicious::Controller';

sub show{
	my $self = shift;
	$self->render( text => $self->url_for('news', news_id=>123, page => 456)->to_abs);
	#'User conroller action show uid='. $self->stash('uid'));
}
1;
################################################################################
package Life25::Site;
use strict;
use warnings;
use base 'Mojolicious::Controller';
use utf8;
use Data::Dumper;
use Life25::DB;

sub news {
	my $self = shift;
	$self->render(text => $self->url_for()->to_abs);
}

sub register
{	
		my $self = shift;
		
		my $user = User->new;

		if($self->req->method eq 'POST')
		{
			$user->fill($self->req->body_params->to_hash);
			
			$user->extra('last_ip', $self->tx->remote_address);
			
			$user->save()

		}
		
		$self->stash('user', $user);
		
		$self->render();
}

sub login{	
		my $self = shift;
		
		if($self->req->method eq 'POST')
		{
			my $user = User->new;
			
			if($user->do_login($self->req->body_params->param('login'),
								$self->req->body_params->param('password')))
			{
				my $s = $self->app->session;
				$s->data('auth', 1);
				$s->data('login', $user->login);
				$s->data('user', $user);

				$s->flush;
				$self->redirect_to('/');
			}
							
			$self->stash('user', $user);
		}		
		
		$self->render;
}

sub logout{
		my $self = shift;
		if($self->app->session->data('auth'))
		{
			$self->app->session->expire;
			$self->app->session->flush;
		}
		$self->redirect_to('/');
}

sub new_topic {
		my $self = shift;
		
		my $topic = Topic->new;
		
		$topic->db->begin_work;
		
		$topic->fill($self->req->body_params->to_hash); 
		$topic->user($self->app->session->data('user'));
		
		$topic->save;
		
		my @errors = ();
		#Only for users logged in
		if ($topic->error)
		{
			push @errors, $topic->errors;			
		}
		else
		{
			my $message = Message->new;
			
			$message->topic($topic);
			$message->user($topic->user);
			$message->body_raw($self->req->body_params->param('message'));
			$message->extra('ip',$self->tx->remote_address);
			$message->save;
			
			if($message->error)
			{
				push @errors, $message->errors;
			}
		}
		
		if(@errors)
		{
			#utf8::encode($errors);
			$self->app->session->data('new_topic_errors' =>\@errors);
			$self->app->session->flush;
			
			$topic->db->rollback;
			$self->redirect_to('/');
		}
		else
		{
			$topic->db->commit;
			$self->redirect_to('/topic/' . $topic->id);
			
		}
			
		
		
}

sub new_message {
	my $self = shift;
	my $tid = $self->req->body_params->param('tid');
	my $go_back = $self->req->headers->referrer || '/';
	
	$self->redirect_to($go_back) unless $tid;
	
	my $topic = Topic->new(id => $tid);
	$self->redirect_to($go_back) unless $topic->load;
	
	my $user = $self->app->session->data('user');
	$self->redirect_to($go_back) unless $user;
	
	my $db = $topic->db;
	$db->begin_work;
	
	my $message = Message->new;
	$message->topic($topic);
	$message->user($user);
	$message->body_raw($self->req->body_params->param('message'));
	$message->extra('ip',$self->tx->remote_address);
	$message->save;
	
	unless($message->errors)
	{
		$topic->update_user ($user);
		$topic->date_update ($message->date_create);
		$topic->save;
	}
	
	my @errors = $message->errors;
	
	if (@errors)
	{
		$self->app->session->data('new_message_error', \@errors);
		$self->app->session->flush;
		$db->rollback;
	}
	else
	{
		$db->commit;
		
	}
	
	$self->redirect_to($go_back);
	
}

sub show {
		my $self = shift;
		$self->render(template => 'site/index', details => "<pre><code> @{[ Dumper $self->app->session->data ]}</code></pre>", message=>0)
}

sub index{	
		my $self = shift;
		my $offset = $self->stash('page') || 1;
		
		my $topics = Topic::Manager->get_topics(
						limit => 10,
						offset => ($offset -1) * 10,
						sort_by => 'date_update desc'
					);
		
		$self->render(details => "Mojo Test Forum", topics => $topics);
}

sub topic {
		my $self = shift;
		my $tid = $self->stash('topic');
		$self->redirect_to('/') unless $tid;
		
		my $topic = Topic->new(id => $tid);
		
		unless ($topic->load)
		{
			$self->redirect_to('/');
		}
		
		my $offset = $self->stash('page') || 1;
		my $messages = 	Message::Manager->get_messages(					
						query => [topic_id => $tid],
						limit => 10,
						offset => ($offset -1) * 10);
						
		$self->render(topic => $topic, messages => $messages);
}
	
sub user {
		my $self = shift;
		$self->render();
}
	
sub r_test{
		my $self = shift;
		my $ofs = int rand(14);#int($self->stash('id')) || 0;
		my $users = User::Manager->get_users
  (
#    query =>
#    [
#      category_id => [ 5, 7, 22 ],
#      status      => 'active',
#      start_date  => { lt => '15/12/2005 6:30 p.m.' },
#      name        => { like => [ '%foo%', '%bar%' ] },
#    ],
#    sort_by => 'category_id, start_date DESC',
    limit   => 10,
    offset  => $ofs * 10
  );
  
		#$self->stash('users') = $users;
		$self->render(	message => "R_TEST",
						details => '',
						users => $users,
						template => 'site/index');
}
 
1;
################################################################################
package Mii;
use Mojo::Base 'Mojolicious::Plugin';
use Mojo::ByteStream 'b';
use Mojo::Util 'xml_escape';
use Mojo::Loader;
use Data::Dumper::HTML qw(dumper_html);

has _owner => sub { undef };

sub register {
	my ($self, $app) = @_;

	$app->helper(
		widget => sub {

		  my $c = shift;		  
		  my $name = shift;		
		  my $widget;
		  
		  #$DB::single = 1;
		  if(ref $name && $name->isa('Mii'))
		  {	  
			$widget = $name;
		  }
		  else
		  {
			  #If name without package asumming its Mii::
			  $name = 'Mii::' . $name unless $name =~ /(\:\:)+/;
			  
			  my $loader = Mojo::Loader->new;
			  my $e = $loader->load($name);
			  die "Can't load $name: $e" if ref $e;
			  die "Can't load $name: nothing to load" if defined $e;
			  $widget = $name->new;
		  }
		  my $params = $self->_parse( @_);
		  
		  
		  $widget->_owner($c);
		  $widget->_init($params->{params});
		  
		  return b( $widget->render($params) );
		}
	);
}

sub _parse {
  my $self = shift;
 
  # Content
  my $cb = defined $_[-1] && ref($_[-1]) eq 'CODE' ? pop @_ : undef;
  my $content = pop if @_ % 2;
  $content = xml_escape $content if defined $content;
  
   # Attributes
   my %attrs = @_;
    
	# Block
	my $block;
	if ($cb || defined $content) {
		$block = $cb ? $cb->() : $content;
	}
	my $params = {content => $block, params => \%attrs}; 

	return $params;
}

sub render {
	my $self = shift;
	die "Subclass '" . (ref $self) . "' not implement 'render' method.";
	my $params = shift;
	
	return dumper_html $params;
}

1;
################################################################################
package Mii::Widget;
use Mojo::Base 'Mii';
#Common staff for all widgets
my $_id_counter = 0;

has _id => '';

sub _init{
	my $self = shift;
	my %params;
		
	if (ref $_[0] eq 'HASH')
	{
		%params = %{ $_[0] };
	}
	else
	{
		%params =  @_ ;
	}		
	
	for my $par (keys %params)
	{
		$self->$par(delete $params{$par}) if $par !~ /^[_]/ && $self->can($par) && defined $params{$par};
	}
}

sub id {
	my $self = shift;
	$self->_id($_[0]) if defined $_[0];
	
	unless ($self->_id)
	{
		$self->_id ('MiiWidget' . (++$_id_counter));
	}
		
	return $self->_id;	
}

1;
################################################################################
package Mii::LinkPager;
use Mojo::Base 'Mii::Widget';
use Data::Dumper::HTML qw(dumper_html);

use POSIX qw(ceil floor);

has count => 10;	
has current_page => 0;	
has block_len => 3;
has per_page => 10;		
has space => '...';	
has page_var => 'page';	
has route_name => '';

sub paginate {
		my $self = shift;
		
		my $len = $self->block_len || 1;
		my $first = 1;
		my $count = ceil($self->count/$self->per_page);
		my $last = $count ;
		
		$len = $last if $len > $last;
		
		$self->current_page( $self->_owner->stash($self->page_var) || 1) unless $self->current_page;
		my $current =  $self->current_page ;
		my $space = $self->space;
				
		my %uniq = ();
			
		for my $cur ($first  .. $first + $len -1 )
		{
			$uniq{$cur}++ if $cur > 0;
		}
		
		my $mid_len = $len == 1 ? 2 : $len;
		for my $cur ($current - $mid_len +1 .. $current + $mid_len -1)
		{
			$uniq{$cur}++ if $cur > 0 && $cur < $last;
		}
		
		for my $cur ($last - $len + 1  .. $last)
		{
			$uniq{$cur}++ if $cur <= $last && $cur > 0;
		}
		
		my @res = sort { int($a) <=> int($b) } keys %uniq;
		my @ans = ();
		
		while(@res)
		{
			my $tmp = shift @res;
			push @ans, $space if @ans && $ans[-1] +1 != $tmp;
			
			push @ans, $tmp;
		}
		
		return @ans; 
}

sub render {
	my $self = shift;

	my $params = shift;	

	my @buttons = $self->paginate;
	
	my $pager = "";
	for my $page (@buttons)
	{
		my @url_params = ($self->page_var => $page);
		unshift @url_params, $self->route_name if $self->route_name;
		
		my $url = $self->_owner->url_for( @url_params)->to_abs;
		
		if($page eq $self->current_page)
		{
			$pager .= "<li class='active'><a href='" . $url  . "' >$page</a></li>\n" ;
		}
		elsif($page eq $self->space)
		{
			$pager .= "<li><a href='#' >$page</a></li>\n" ;
		}
		else
		{
			$pager .= "<li><a href='" . $url . "' >$page</a></li>\n" ;
		}
	} 
	
	$pager = "<div class='MiiLinkPager'>\n<ul class='MiiLinkPager tabs' id='". $self->id ."'>\n$pager\n</ul>\n</div>" ;
	#. dumper_html($params);
	# . "app.routes=" . dumper_html($self->_owner->app->routes);
	
	return $pager; 
}
1;
################################################################################
package Mii::ActiveForm;
use Mojo::Base 'Mii::Widget';
use Data::Dumper::HTML qw(dumper_html);

has object => sub { undef };

sub render{
	my $self = shift;
	my $params = shift;
	my $ret = "form start here<br/> ";
	$ret .= $params->{content} if defined $params->{content};
	$ret .= "<br/>form end here<br/>";
	
	return $ret;
}

sub test{
	my $self = shift;
		return 'object is '. dumper_html($self->object);
	}

1;
