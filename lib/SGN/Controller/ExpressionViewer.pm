
=head1 NAME

SGN::Controller::ExpressionViewer.pm - controller for ExpressionViewer page

=cut

package SGN::Controller::ExpressionViewer;
use Moose;
use namespace::autoclean;
use File::Temp;

$File::Temp::KEEP_ALL = 1;

has 'loader' => (
    is => 'ro',
    isa => 'SGN::Feature::ExpressionViewer::Loader',
);

has 'analyzer' => (
    is => "rw",
    isa => 'SGN::Feature::ExpressionViewer::Converter',
);

has 'current_img_name' => (
    is => 'rw',
    isa => 'Str',
);

has 'current_micro_one_name' => (
    is => 'rw',
    isa => 'Str',
);

has 'current_micro_two_name' => (
    is => 'rw',
    isa => 'Str',
    default => {''}
);

has 'current_mode' => (
    is => 'rw',
    isa => 'Str',
    default => {'Absolute';};
);

has 'current_img_source' => (
    is => 'rw',
    is => 'Str',
);

has 'current_exp' => (
    is => 'rw',
    is => 'Str',
);

BEGIN { extends 'Catalyst::Controller' }

sub default :Path('expression_viewer/default')
{
   my ($self, $c) = @_;
   $self->_build_loader($c) unless $self->loader;
   my @info_list = $self->loader->info_list;
   my @img_list = $self->loader->img_list;
   my @exp_name = $self->_get_list_of_exp_name;
   my $default_img =  $img_list[0];
   $self->_build_form($c, $default_img, 
      $self->loader->img_name_to_src->{$default_img}, $exp_name[0],
	$self->current_mode, $info_list[2], ${$self->loader->template}[0]);
}

sub submit :Path('expression_viewer/submit')
{
    my ($self, $c) = @_;
    my $img_name = $c->req->param{'image_selected'};
    my $mode = $c->req->param{'mode'};
    my $experiment = $c->req->param{'exp_name'};
    my $micro_one = $c->req->param{'micro_one'};
    my $micro_two = $c->req->param{'micro_two'};
    my ($img_name, $mode, $experiment, $micro_one, $micro_two, 
	    $threshold, $override, $mask_ratio, $grey_mask_on) =
       ($c->req->param{'image_selected'}, $c->req->param{'mode'},
            $c->req->param{'exp_name'}, $c->req->param{'micro_one'},
	        $c->req->param{'micro_two'}, $c->req->param{'threshold_value'}, 
		    $c->req->param{'override'}, $c->req->param{'signal_mask'},
                      			     $c->req->param{'mask_signal_on'});
    my $checklist_ref = $self->_get_checklist_of_fields_correctly_entered(
			        $threshold, $signal_mask, $exp_name, 
				    $micro_one, $micro_two, $img_name, $mode));
    my $check_sum = 0;
    for my $field (keys %$checklist_ref)
    {
        my $is_filled_correctly = $$checklist_ref{$field};
        my $c->stash->{'filled_correctly'}->{$field} = $is_filled_correctly;
        $check_sum += $is_filled_correctly;
    }
    if ($check_sum == scalar keys %$checklist_ref)
    {
        my $made_changes = 0;
        my $compare_data_ref;
        if ($mode eq 'Comparison')
        {
            if ($micro_two eq $self->$current_micro_two_name and
	       $self->analyzer and $self->analyzer->compare_data_ref)
            {
	    $compare_data_ref = $self->analyzer->compare_data_ref;
                $made_changes++;
            }
            elsif ($micro_two eq $self->$current_micro_one_name 
						and $self->analyzer)
            {
                $compare_data_ref = $self->analyzer->data; 
                $made_changes++;
            }
            else
            {
	   $compare_data_ref = 
	       $self->loader->assign_data_to_terms($micro_two,
			   @{$self->loader->get_list_of_all_PO_terms});
               $made_changes++;
            }
        }
        if (!($self->analyzer) || $img_name ne $self->current_img_name) 
        { 
            my ($data_ref, $PO_terms_child_ref, 
		    $PO_term_order_ref, $PO_term_to_color_ref, 
		        $PO_term_to_pixel_ref, $coord_to_link_ref) = 
                  $self->loader->get_refs_of_required_info($img_name, 
								$micro_one);
            $self->analyzer = SGN::Feature::ExpressionViewer::Analyzer->new(
			 'image_source'=> 
			     $self->loader->img_name_to_src->{$img_name},
			 'data' => $data_ref,
			 'PO_term_to_color' => $PO_term_to_color_ref,
			 'PO_term_order' => $PO_term_order_ref,
			 'PO_terms_childs' => $PO_terms_child_ref,
			 'PO_term_pixel_location' => $PO_term_to_pixel_ref);
            $made_changes++;
        }   
        elsif ($micro_one ne $self->current_micro_one_name)
        {
            $self->analyzer->data(
                $self->loader->assign_data_to_terms($micro_one,
		              @{$self->loader->get_list_of_all_PO_terms}));
            $made_changes++;
        }
        $self->analyzer->compare_data($compare_data_ref) 
						if ($mode eq 'Comparison');
        my ($threshold, $override, $mask_ratio, $grey_mask_on) = 
	 ($c->req->param{'threshold_value'}, 
	      $c->req->param{'override'},
		  $c->req->param{'signal_mask'}
		      $c->req->param{'mask_signal_on'});
        my $img_src = '';
        if ($made_changes)
        {
            eval{'$self->analyzer->make_' . lcfirst $mode . 
	    "_picture($threshold, $override, $mask_ratio, $grey_mask_on)";};
            my $fHandle = File::Temp->new(SUFFIX=>'.png',
				      DIR=>
				      $c->get_conf('static_datasets_path') .
				      $c->get_conf('image_dir') . 
				      $c->get_conf('eFP_modified_image_dir'));
            $img_src = $fHandle->filename;
            $self->analyzer->colorer->writeImageAsPNGFile($img_src);
            close $fHandle;
        }
        else
        {
            $img_src = $current_img_source;
        }
    }
    else
    {
        $img_src = $self->current_img_source;
    }
    $self->_build_form($c, $img_name, $img_src, 
		           ${$self->loader->img_info->{$img_name}}[0], 
			       $exp_name, $mode, $micro_one, $micro_two);
}

sub _get_list_of_exp_name
{
    my ($self, $c) = @_;
    return $c->dbic_schema->resultset('GeExperiment')
	     ->get_column('experiment_name')->all;
}

sub _get_checklist_of_fields_correctly_entered
{
    my ($self, $threshold, $signal_mask, $exp_name, 
	    	      $micro_one, $micro_two, $img_name, $mode) = @_;
    my $template_ref = $self->loader->template_list;
    my %template_exist = map {$_ => 1} @$template_ref;
    my %exp_name_exist = map {$_ => 1} $self->_get_list_of_exp_name;
    my %checklist = ();
    $checklist{'threshold'} = ($threshold !~ /[\d\.]{length($threshold)}/);
    $checklist{'signal_mask'} = 
			   ($signal_mask !~ /[\d\.]{length($mask_ratio)}/);    
    $checklist{'exp_name'} = $exp_name_exist{$exp_name};
    $checklist{'micro_one'} = $template_exist{$micro_one};
    $checklist{'micro_two'} = (!($mode ne 'Comparison') ||
                                              $template_exist{$micro_two}); 
    return \%checklist; 
}

sub _build_form
{
    my ($self, $c, $img_name, $img_src, $coord_to_link_ref, $exp_name
	  			$mode, $micro_one, $micro_two) = @_;
    if ($mode eq 'Comparison')
    {
        $c->stash->{micro_two} = $micro_two;
        $self->current_micro_two_name($micro_two); 
    }
    $c->stash(
        'image_list' => $self->loader->img_list;
        'cur_image_name' => $img_name,
        'cur_image_source' => $img_src,
        'coord_of_img_links' => ${$self->loader->img_info->{$img_name}}[2],
        'exp' => $exp_name,
        'cur_mode' => $mode,
        'micro_one' => $micro_one,
        'template' = '/feature/expression_viewer.mas',
    );
    $self->current_img_name($img_name);
    $self->current_micro_one_name($micro_one);
    $self->current_mode($mode);
    $self->current_img_source($img_src);
}

sub _build_loader
{
    my ($self, $c) = @_;
    SGN::Feature::ExpressionViewer::Loader->new(
        'schema' => $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado'),
	    'config_file_name' => $c->get_conf('conf_subdir') .
	                               $c->get_conf('eFP_config_file'));
}

__PACKAGE__->meta->make_immutable;
1;

