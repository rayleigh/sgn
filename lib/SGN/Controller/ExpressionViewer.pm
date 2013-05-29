
=head1 NAME

SGN::Controller::ExpressionViewer.pm - controller for ExpressionViewer page

=cut

package SGN::Controller::ExpressionViewer;
use Moose;
use namespace::autoclean;
use File::Temp;
#use Data::Dumper;

$File::Temp::KEEP_ALL = 1;

has 'loader' => (
    is => 'rw',
    isa => 'SGN::Feature::ExpressionViewer::Loader',
);

has 'analyzer' => (
    is => "rw",
    isa => 'SGN::Feature::ExpressionViewer::Analyzer',
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
    default => sub{''}
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
   $self->current_img_source($self->loader->img_name_to_src->{$default_img});
   $self->_build_form($c, $default_img, $self->current_img_source,
				      $self->current_mode, $default_template);
}

#Processes user request
sub submit :Path('/expression_viewer/submit')
{
    my ($self, $c) = @_;
    my ($img_name, $mode, $micro_one, $threshold) = 
       ($c->request->param('image_selected'), 
	$c->request->param('mode'),
        $c->request->param('micro_one'), 
	$c->request->param('threshold_value')
       );
    my $micro_two = $c->request->param('micro_two');
    my $override = $c->request->param('override'); 
    my $signal_mask = $c->request->param('signal_mask');
    my $grey_mask_on = $c->request->param('mask_signal_on');    
    unless ($override)
    {
       $override = '';
    }
    unless ($grey_mask_on)
    {
       $grey_mask_on = '';
       $signal_mask = '';
    }

    #my $threshold =  $c->request->param('threshold_value'); 
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
        my $exp_PO_guide_ref = {};
        if (!($self->analyzer) || $img_name ne $self->current_img_name) 
        { 
            print STDERR "Here\n"; 
            print STDERR "$img_name $micro_one\n";  
            my ($data_ref, $exp_PO_guide_ref_temp, $PO_term_to_color_ref,
		    $PO_terms_child_ref, $PO_term_order_ref, 
		        $PO_term_to_pixel_ref, $coord_to_link_ref, 
						  $order_of_coord_ref) = 
                  $self->loader->get_refs_of_required_info($img_name, 
								$micro_one);
            $self->analyzer(SGN::Feature::ExpressionViewer::Analyzer->new(
			 'image_source'=> 
			     $self->loader->img_name_to_src->{$img_name},
			 'data' => $data_ref,
			 'PO_term_to_color' => $PO_term_to_color_ref,
			 'PO_term_order' => $PO_term_order_ref,
			 'PO_terms_childs' => $PO_terms_child_ref,
			 'PO_term_pixel_location' => $PO_term_to_pixel_ref));
            $exp_PO_guide_ref = $exp_PO_guide_ref_temp;
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
            #$signal_mask = 0 unless $signal_mask;
	    #print STDERR "$threshold\n";  
            #unless ($self->_exp_PO_guide_ref_has_duplicates(
	    #			$exp_PO_guide_ref, 
	    #			   $self->analyzer->PO_terms_childs))
            #{    
                $c->stash->{'error_message'} = ''; 
                my $legend_ref = 
		   eval('$self->analyzer->make_' . (lcfirst $mode) . 
	    	    			   '_picture($threshold, 
						     $override, 
						     $signal_mask, 
						     $grey_mask_on, 
	 	            			     $exp_PO_guide_ref);');
                print STDERR "There";
                my ($fHandle, $uri_info)  = 
			 $c->tempfile(TEMPLATE => 'exp_viewer-XXXXXXX',
				      SUFFIX =>'.png');
                $img_src = $uri_info->as_string;
                $self->analyzer->colorer->writeImageAsPNGFile($fHandle->filename);
                close $fHandle;
                print STDERR "$img_src";
                $c->stash->{'legend_ref'} = $legend_ref;
            #}
	    #else
	    #{
            #    $c->stash->{'error_message'} = 
	    #		"The experiment has duplicate PO terms or related PO terms.";
            #    unless ($self->current_img_source)
            #    {
	    #	   $img_src = $self->loader->img_name_to_src->{$img_name};
            #    }
            #    else
            #    {
            #       $img_src = $self->current_img_source;
            #    }
	    #}
            
        }
        else
        {
	    unless ($self->current_img_source)
	    {
	       $img_src = $self->loader->img_name_to_src->{$img_name};
	    }
	    else
	    {
	       $img_src = $self->current_img_source;
	    }
        }
    }
    else
    {
	unless ($self->current_img_source)
	{
	   $img_src = $self->loader->img_name_to_src->{$img_name};
	}
	else
	{
	   $img_src = $self->current_img_source;
	}
    }
    $self->_build_form($c, $img_name, $img_src, $mode, $micro_one, $micro_two);
}

#Returns a checklist that notes if certain fields are correctly entered
sub _get_checklist_of_fields_correctly_entered
{
    my ($self, $threshold, $signal_mask, 
       $micro_one, $micro_two, $img_name, $mode, $mask_signal_on, $c) = @_;
    my %checklist = ();
    $checklist{'threshold'} = (!($threshold) || $threshold !~ /[\d\.]{length($threshold)}/);
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
        $c->stash->{'micro_two'} = $micro_two;
        $self->current_micro_two_name($micro_two); 
    }
    $c->stash(
        'image_list' => $self->loader->img_list,
        'cur_image_name' => $img_name,
        'cur_image_source' => $img_src,
        'coord_of_img_links_ref' => ${$self->loader->img_info->{$img_name}}[4],
        'order_of_coord_ref' => ${$self->loader->img_info->{$img_name}}[5],
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
        'config_file_name' => $self->{conf_file},
        'other_info_file_name' => $self->{other_info_file}));
}

#Checks for duplicates in the $exp_PO_guide_ref
sub _exp_PO_guide_ref_has_duplicates
{
   my ($self, $guide_ref, $PO_terms_child_ref) = @_;
   #print STDERR Dumper($guide_ref);
   #print STDERR Dumper($PO_terms_child_ref);
   my %check_hash = ();
   for my $exp (keys %$guide_ref)
   {
      for my $PO_term (@{$$guide_ref{$exp}})
      {
         return 1 if $check_hash{$PO_term};
         $check_hash{$PO_term} = 1;
         for my $child_PO_term (@{$$PO_terms_child_ref{$PO_term}})
         {
             return 1 if $check_hash{$child_PO_term};
             $check_hash{$child_PO_term} = 1;
         }
      }
   }
   0;
}

__PACKAGE__->meta->make_immutable;
1;

