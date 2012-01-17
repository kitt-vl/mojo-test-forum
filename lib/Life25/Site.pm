package Life25::Site;
use strict;
use warnings;
use base 'Mojolicious::Controller';
use utf8;
use Data::Dumper;
use Life25::DB;

sub register
{	
		my $self = shift;
		
		my $user = User->new;

		$user->fill($self->req->body_params->to_hash);
		
		$user->extra('last_ip', $self->tx->remote_address);
		
		$user->save();
	
		
		$self->stash('user', $user);
		
		$self->render();
}

sub test{	
		my $self = shift;
		
		my $txt = $self->render_partial(template => "site/common.html.ep/reg");
		$txt .= $self->render_partial(template => "site/common.html.ep/reg2");
		
		$self->render( message => "test page here12 Hello!.", details => $txt, template => "site/index");
}

sub index{	
		my $self = shift;

		$self->render(	message => "In development yet. See you later.",
						details => "Some info");
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

