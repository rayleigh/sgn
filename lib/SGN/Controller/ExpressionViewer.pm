
=head1 NAME

SGN::Controller::ExpressionViewer.pm - controller for ExpressionViewer page

=cut

package SGN::Controller::ExpressionViewer;
use Moose;
use namespace::autoclean;
use File::Temp;

$File::Temp::KEEP_ALL = 1;

#Following attributes already set by sgn.conf file
has 'conf_file' => (
    is => 'ro',
    isa => 'Str'
);

has 'static_img_dir' => (
    is => 'ro',
    isa => 'Str'
);

has 'original_dir' => (
    is => 'ro',
    isa => 'Str'
);

has 'mod_dir' => (
    is => 'ro',
    isa => 'Str'
);

#These attributes are not set in sgn.conf file
has 'loader' => (
    is => 'rw',
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
);

has 'current_mode' => (
    is => 'rw',
    isa => 'Str',
    default => sub{'Absolute'}
);

has 'current_img_source' => (
    is => 'rw',
    isa => 'Str',
);

BEGIN { extends 'Catalyst::Controller' }

#Default page
sub default :Path('/expression_viewer/default')
{
   my ($self, $c) = @_;
   $self->_build_loader($c) unless $self->loader;
   my @img_list = $self->loader->img_list;
   my $default_img =  $img_list[0];
   my $default_template = $c->dbic_schema('CXGN::GEM::Schema', 'sgn_chado')
                                ->resultset('GeTemplate')
                                    ->get_column('template_name')->first;
   $self->_build_form($c, $default_img, 
      $self->loader->img_name_to_src->{$default_img},
	$self->current_mode, $default_template);
}

#Processes user request
sub submit :Path('/expression_viewer/submit')
{
    my ($self, $c) = @_;
    my ($img_name, $mode, $micro_one, $micro_two, 
	    $threshold, $override, $signal_mask, $grey_mask_on) =
       ($c->request->param('image_selected'), $c->request->param('mode'),
            $c->request->param('micro_one'), $c->request->param('micro_two'), 
		$c->request->param('threshold_value'), 
		    $c->request->param('override'), 
			$c->request->param('signal_mask'),
                      	    $c->request->param('mask_signal_on'));
    my $checklist_ref = $self->_get_checklist_of_fields_correctly_entered(
			      $threshold, $signal_mask, $micro_one, 
			    $micro_two, $img_name, $mode, $grey_mask_on, $c);
    my $check_sum = 0;
    my $img_src = '';
    for my $field (keys %$checklist_ref)
    {
        my $is_filled_correctly = $$checklist_ref{$field};
        $c->stash->{'filled_correctly'}->{$field} = $is_filled_correctly;
        $check_sum += $is_filled_correctly;
    }
    $self->_build_loader($c) unless $self->loader;
    if ($check_sum == scalar keys %$checklist_ref)
    {
        my $made_changes = 0;
        my $compare_data_ref;
        if ($mode eq 'Comparison')
        {
            if ($micro_two eq $self->current_micro_two_name and
	       $self->analyzer and $self->analyzer->compare_data_ref)
            {
	        $compare_data_ref = $self->analyzer->compare_data_ref;
                $made_changes++;
            }
            elsif ($micro_two eq $self->current_micro_one_name 
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
        my $exp_PO_guide_ref;
        if (!($self->analyzer) || $img_name ne $self->current_img_name) 
        { 
            my ($data_ref, $exp_PO_guide_ref, $PO_terms_child_ref, 
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
            my ($data_ref, $exp_PO_guide_ref) = 
		$self->loader->get_data_and_exp_PO_guide($micro_one); 
            $self->analyzer->data($data_ref);
            $made_changes++;
        }
        $self->analyzer->compare_data($compare_data_ref) 
						if ($mode eq 'Comparison');
        if ($made_changes)
        {
            eval{'$self->analyzer->make_' . (lcfirst $mode) . 
	    '_picture(' . $threshold . ',' . $override . ',' . 
		         $signal_mask . ',' . $grey_mask_on . ',' .
		            $exp_PO_guide_ref . ');'};
            my $fHandle = File::Temp->new(SUFFIX=>'.png',
				      DIR=>
				      $self->static_img_dir .
				      $self->mod_dir);
            $img_src = $fHandle->filename;
            $self->analyzer->colorer->writeImageAsPNGFile($img_src);
            close $fHandle;
        }
        else
        {
            $img_src = $self->current_img_source;
        }
    }
    else
    {
        $img_src = $self->current_img_source;
    }
    $self->_build_form($c, $img_name, $img_src, $mode, $micro_one, $micro_two);
}

#Returns a checklist that notes if certain fields are correctly entered
sub _get_checklist_of_fields_correctly_entered
{
    my ($self, $threshold, $signal_mask, 
       $micro_one, $micro_two, $img_name, $mode, $mask_signal_on, $c) = @_;
    my %checklist = ();
    $checklist{'threshold'} = ($threshold !~ /[\d\.]{length($threshold)}/);
    $checklist{'signal_mask'} = (!($mask_signal_on) || 
			   $signal_mask !~ /[\d\.]{length($signal_mask)}/);    
    $checklist{'micro_one'} = $self->_check_template($c, $micro_one);
    $checklist{'micro_two'} = ($mode ne 'Comparison' ||
                                    $self->_check_template($c, $micro_two)); 
    return \%checklist; 
}

#Checks to see if the template exists
sub _check_template
{
    my ($self, $c, $template_name) = @_;
    return 1 if $c->dbic_schema('CXGN::GEM::Schema', 'sgn_chado')
		       ->resultset('GeTemplate')
                           ->search_rs({template_name => $template_name })
                              ->first;
    return 0;
}

#Builds the page using the image name and source, coordinates linking
#to more information, the mode, and the templates
sub _build_form
{
    my ($self, $c, $img_name, $img_src, $mode, $micro_one, $micro_two) = @_;
    if ($mode eq 'Comparison')
    {
        $c->stash->{micro_two} = $micro_two;
        $self->current_micro_two_name($micro_two); 
    }
    $c->stash(
        'image_list' => $self->loader->img_list,
        'cur_image_name' => $img_name,
        'cur_image_source' => $img_src,
        'coord_of_img_links_ref' => ${$self->loader->img_info->{$img_name}}[2],
        'order_of_coord_ref' => ${$self->loader->img_info->{$img_name}}[3],
        'cur_mode' => $mode,
        'micro_one' => $micro_one,
        'template' => '/feature/expression_viewer.mas',
    );
    $self->current_img_name($img_name);
    $self->current_micro_one_name($micro_one);
    $self->current_mode($mode);
    $self->current_img_source($img_src);
}

#Builds the loader
sub _build_loader
{
    my ($self, $c) = @_;
    
    #$self->conf_file refers to conf_file in sgn.conf file
    $self->loader(SGN::Feature::ExpressionViewer::Loader->new(
        'bcschema' => $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado'),
        'cgschema' => $c->dbic_schema('CXGN::GEM::Schema', 'sgn_chado'),
        'config_file_name' => $self->conf_file));
}

__PACKAGE__->meta->make_immutable;
1;

