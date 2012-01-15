package Life25;
use strict;
use warnings;
use Mojo::Base 'Mojolicious';

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
}
1;


__DATA__
@@ reg.html.ep
<h4>Reg item here</h4>

@@ reg2.html.ep
<h5>Reg2 item here</h5>
