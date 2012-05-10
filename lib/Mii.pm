package Mii;
use Mojo::Base 'Mojolicious::Plugin';
use Mojo::ByteStream 'b';
use Mojo::Util 'xml_escape';
use Mojo::Loader;
use Data::Dumper::HTML qw(dumper_html);

sub register {
	my ($self, $app) = @_;
	
	#$app->log->info("Mii register");
	$app->helper(
		widget => sub {
			#$app->log->info("Mii widget");
			my $widget = $self->_load_widget(@_);			
			
			return b( $widget->render );
		}
	);
	
	$app->helper(
		create_widget => sub{
			my $widget = $self->_load_widget(@_);
			return $widget;
		}
	);
	
	$app->helper(
		render_widget => sub{
			my ($c, $widget) = (shift, shift);
			die "Mii::render_widget - First parameter must be widget ref" unless ref $widget;
			my $params = $self->_parse( @_);
			$widget->_params($params);
			return $widget->render();
		}
	);
}

sub _load_widget{
	my ($self, $c, $name) = (shift, shift, shift);
	
	my $params = $self->_parse( @_);


	#If name without package asumming its Mii::
	$name = 'Mii::' . $name unless $name =~ /(\:\:)+/;

	my $loader = Mojo::Loader->new;
	my $e = $loader->load($name);
	die "Can't load '$name': $e" if ref $e;
	die "Can't load '$name': nothing to load" if defined $e;
	
	my $widget = $name->new($params->{params});
	$widget->_owner($c);
	$widget->_params($params);
	
	return $widget;
}

sub _parse {
  #most code here from Mojolisious::Plugins::TagHelper->_tag
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

1;
################################################################################
package Mii::ScriptManager;
use Mojo::Base -base;

has js_array => sub { {} };

my $_instance;
sub new {
	my $class = shift;
	$_instance = bless {}, $class unless defined $_instance;
	return $_instance;
}

################################################################################
package Mii::Widget;
use Mojo::Base -base;
use Mojo::ByteStream 'b';
use Mojo::Util 'xml_escape';

#Common staff for all widgets
my $_id_counter = 0;

has _id => '';
has _owner => sub { undef };
has _params => sub { undef };
has script_manager => sub { Mii::ScriptManager->new };

sub new {
	my $class = shift;
	my $self = bless {}, $class;

	my %params = ref $_[0] eq 'HASH' ? %{ $_[0] } : @_;
			
	for my $par (keys %params)
	{
		$self->$par(delete $params{$par}) if $par !~ /^[_]/ && $self->can($par) && defined $params{$par};
	}
	
	return $self;
}

sub id {
	my $self = shift;
	$self->_id($_[0]) if defined $_[0];	
	
	$self->_id ('MiiWidget' . (++$_id_counter)) unless ($self->_id);	
		
	return $self->_id;	
}

sub _tag {
  my ($self, $name) = (shift, shift);
 
  # Content
  my $content = pop if @_ % 2;
  $content = xml_escape($content) if defined $content; 
  # Tag
  my $tag = "<$name";
 
  # Attributes
  my %attrs = @_;
  for my $key (sort keys %attrs) {
    my $value = defined $attrs{$key} ? xml_escape($attrs{$key}) : '';
    $tag .= qq/ $key="$value"/;
  }
 
  # Block
  if (defined $content) {
    $tag .= '>';
    $tag .=  $content;
    $tag .= "</$name>";
  }
 
  # Empty element
  else { $tag .= ' />' }
 
  # Prevent escaping
  return b($tag);
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
	
	$pager = "<div class='MiiLinkPager'>\n<ul class='MiiLinkPager nav nav-pills' id='". $self->id ."'>\n$pager\n</ul>\n</div>" ;

	
	return $pager; 
}
1;
################################################################################
package Mii::ActiveForm;
use Mojo::Base 'Mii::Widget';
use Mojo::ByteStream 'b';
use Data::Dumper::HTML qw(dumper_html);

has object => sub { undef };

sub render{
	my $self = shift;
	my $ret = "form start here<br/> ";
	#$ret .= dumper_html($self);
	$ret .= $self->_params->{content} if defined $self->_params->{content};
	$ret .= "<br/>form end here<br/>";
	#$ret .= dumper_html($self->_params) . "<br/>form end here<br/>";
	
	$self->script_manager->js_array->{jquery1_7}++;
	$self->script_manager->js_array->{jui}++;
	
	return b($ret);
}

sub input{
	my $self = shift;
	my $name = shift || '';
	my $label = shift || $name;
	
	push @_, qw(type text);
	my $ret = "";
	$ret .= $self->_tag('strong' , $label) . "\n" if $label;
	$ret .= $self->_tag('input', name => $name, @_);
	#$ret .= '<input type=\'text\' name=\'' . $params{'name'} . '\' />' if defined $params{'name'};
	
	return b($ret);
}

sub test{
	#my $self = shift;
	#my $params = { @_ } ;
	#delete $self->{_owner};
	return b('object is '. dumper_html( @_));
}

1;
