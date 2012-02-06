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
	$self->res->code(200);
}

sub test {
	my $self = shift;
	$self->render_text($self->url_for()->to_abs, layout => '');
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
