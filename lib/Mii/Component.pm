package Mii::Base;
use Mojo::Loader;
use Mojo::Base -base;

sub create_component {
	my $self = shift;
	my $type;
	my $config = {};
	
	if (ref $_[0])
	{
		$config = $_[0];
		$type = $config->{type} if defined $config->{type};
	}
	else
	{
		$type = $_[0];
	}
	
	die 'Mii::Base::create_component: Object configuration must be an array containing a "class" element.' 
					unless $type;
					
	my $loader = Mojo::Loader->new;	
	die "Mii::Base::create_component: can't find $type module" unless $loader->search($type);
	
	my $e = $loader->load($type);
	
	die "Mii::Base::create_component: Error loading $type module - $e" if ref $e;
	
	my $component = $type->new( %{ $config } );
	
}
1;
################################################################################
package Mii::Component;
use Mojo::Base -base;

1;
################################################################################
package Mii::Module;
use Mojo::Base 'Mii::Component';

has _components => sub { {} };

1;
################################################################################
package Mii::ApplicationConponent;
use Mojo::Base 'Mii::Component';

has _is_initialized => 0;

sub new {
	my $self = shift->SUPER::new(@_);
	$self->_is_initialized = 1;
	
	return $self;
}

sub is_initialized {
	return shift->_is_initialized;
}
1;
################################################################################
package Mii::ClientScript;
use Mojo::Base 'Mii::ApplicationConponent';

sub pos_head { 0 };
sub pos_begin { 1 };
sub pos_end { 2 };
sub pos_load { 3 };
sub pos_ready { 4 };

has enable_javascript => 1;
has script_map => sub { {} };
has packages => sub { {} };
has core_packages => '';
has css_files => sub { {} };
has script_files => sub { {} };
has scripts => sub { {} };
has meta_tags => sub { {} };
has script_tags => sub { {} };
has link_tags => sub { {} };
has css => sub { {} };
has has_scripts => 0;
has core_scripts => sub { {} };
has core_script_position => sub { shift->pos_head };
has _base_url => '';

sub reset {
		my $self = shift;
		
		$self->has_scripts(0);
		$self->core_scripts({});
		$self->css_files({});
		$self->css([]);
		$self->script_files({});
		$self->scripts({});
		$self->meta_tags({});
		$self->link_tags({});

		#TODO
		#$self->recordCachingAction('clientScript','reset',array());
}

sub render {
	my $self = shift;
	return unless $self->has_scripts;
	
	
}

sub render_core_scripts {
	die "Mii::Base::render_core_scripts: not implemented yet!";
	
	my $self = shift;
	return unless $self->core_scripts;
	
	
	my $css_files = {};
	my $js_files = {};
	
	for my $name (sort keys %{$self->core_scripts})
	{
		my $package = $self->core_scripts->{$name};
		
	}
	
}
=for comment
public function registerCssFile($url,$media='')
        {
                $this->hasScripts=true;
                $this->cssFiles[$url]=$media;
                $params=func_get_args();
                $this->recordCachingAction('clientScript','registerCssFile',$params);
                return $this;
        }
=cut
 
sub register_css_file {
	my $self = shift;
	my $url = shift;
	my $media = shift || '';
	
	$self->has_scripts(1);
	$self->css_files->{$url} = $media;
	
	return $self;
		
}
1;
################################################################################
package Mii::BaseController;
use Mojo::Base qw(Mojolicious::Controller Mii::Component);

has _widget_stack => sub { [] };

sub view_file {
	die "Mii::BaseController->view_file: not implemented by subclass!";
}

1;

################################################################################
package Mii::Widget;
use Mojo::Base 'Mii::BaseController';
my $_counter = 0;

has action_prefix => '';
has _owner => sub { undef };
has _id => '';

sub owner {
	my $self = shift;
	$self->_owner($_[0]) if defined $_[0];
	return $self->_owner;
}

sub id {
	my $self = shift;
	$self->_id($_[0]) if defined $_[0];
	$self->_id = 'mw' . $_counter unless $self->_id;
	return $self->_id;	
}

1;
################################################################################
package Mii::Pagination;
use Mojo::Base  'Mii::Component';

has _current_page => 0;
has _item_count => 0;
has limit => 10;
has _page_count => 0;
has _page_size => 10;
has _page_size_default => sub { 10 };
has page_var => 'page';
has params => sub { Mojo::Parameters->new };
has route => '';
has validate_current_page => 0;


sub page_size {
	my $self = shift;
	my $size = shift;
	
	$self->_page_size = $size if defined $size;
	$self->_page_size = $self->_page_size_default if $self->_page_size <= 0;
	
	return $self->_page_size;
	 
}

sub item_count {
	my $self = shift;
	my $count = shift;
	
	$self->_item_count = $count if defined $count;
	$self->_item_count = 0 if $self->_item_count <= 0;
	
	return $self->_item_count;
}

sub page_count {
	my $self = shift;
	return int ($self->item_count + $self->page_size - 1) / $self->page_size;
}

sub current_page {
	my $self = shift;
	my $current = shift;
	
	$self->_current_page = $current if defined $current;
	
	$self->_current_page = $self->page_count -1 if $self->_current_page >= $self->page_count;
	$self->_current_page = 0 if $self->_current_page < 0;
	
	return $self->_current_page;
}

sub create_page_url {
	my $self = shift;
	my $c = shift;
	die "Mii::Pagination->create_page_url: controller required!";
	my $page = shift || 0;
	 
	my $params = $self->params || $c->req->query_params;
	my $page_var = $self->page_var;
	$params->$page_var($page + 1) if $page;
	
	return $c->url_for($self->route, $params->to_hash);
	
}

sub apply_limit {
	die "Mii::Pagination->apply_limit: not implemented yet!";
	my $self = shift;
	#TODO
	#$criteria->limit=$this->getLimit();
    #$criteria->offset=$this->getOffset();
}

sub offset {
	my $self = shift;
	return $self->current_page * $self->page_size;
}

sub limit {
	my $self = shift;
	return $self->page_size;
}
1;
################################################################################
package Mii::BasePager;
use Mojo::Base  'Mii::Widget';

has _pages => sub { Mii::Pagination->new };

sub pages {
	my $self = shift;
	$self->_pages($_[0]) if defined $_[0];
	return $self->_pages;	
}

sub page_size {
	my $self = shift;
	$self->_pages->page_size($_[0]) if defined $_[0];
	return $self->_pages->page_size;
}

sub item_count {
	my $self = shift;
	$self->_pages->item_count($_[0]) if defined $_[0];
	return $self->_pages->item_count;
}

sub page_count {
	my $self = shift;
	$self->_pages->page_count($_[0]) if defined $_[0];
	return $self->_pages->page_count;
}

sub current_page {
	my $self = shift;
	$self->_pages->current_page($_[0]) if defined $_[0];
	return $self->_pages->current_page;
}

sub create_page_url {
	#die "Mii::Pagination->create_page_url: not implemented yet!";
	my $self = shift;
	
	return $self->url_for();
}

1;
################################################################################
package Mii::LinkPager;
use Mojo::Base 'Mii::BasePager';

has max_button_count => 10;
has next_page_label => 'Next &gt;';
has prev_page_label => '&lt; Previous';
has first_page_label => '&lt;&lt; First';
has last_page_label => 'Last &gt;&gt;';
has header => 'Go to page: ';
has footer => '';
has css_file => '';
has html_options => sub { {} };

sub css_first_page { 'first' }
sub css_last_page { 'last' }
sub css_previuos_page { 'previous' }
sub css_next_page { 'next' }
sub css_internal_page { 'page' }
sub css_hidden_page { 'hidden' }
sub css_selected_page { 'selected' }

sub new {
	my $self = shift->SUPER::new(@_);
	$self->html_options->{id} = $self->id unless $self->html_options->{id};
	$self->html_options->{class} = 'MiiPager' unless $self->html_options->{class};
	
	return $self;
}

sub run {
	my $self = shift;
	
	my $buttons = $self->_create_buttons;
	
}

sub _create_page_buttons {
	my $self = shift;
	return [] if $self->page_count <= 1;
	
	my ($begin_page, $end_page) = $self->_get_page_range;
	
	my $current_page = $self->current_page;
	my $buttons = [];
	
	#first page
	
	
}

sub _create_page_button {
	my $self = shift;
	my ($label,$page,$class,$hidden,$selected) = @_;
	
	$class .= ' ' . ($hidden ? $self->css_hidden_page : $self->css_selected_page) if $hidden || $selected;
	return '<li class="' . $class ;
}


sub _page_range{
	my $self = shift;
	my $current_page = $self->current_page;
	my $page_count = $self->page_count;
	
	my $begin_page =  $current_page - int($self->max_button_count/2);
	$begin_page = 0 if $begin_page < 0;
	
	my $end_page = $begin_page + $self->max_button_count - 1;
	if($end_page >= $page_count)
	{
		$end_page = $page_count -1;
		$begin_page = $end_page - $self->max_button_count +1;
		$begin_page = 0 if $begin_page < 0;
	}
	
	return ($begin_page, $end_page);
}
1;









