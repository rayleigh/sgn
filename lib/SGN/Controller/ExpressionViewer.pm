
=head1 NAME

SGN::Controller::ExpressionViewer.pm - controller for ExpressionViewer page

=cut

package SGN::Controller::ExpressionViewer;
use Moose;
use namespace::autoclean;
use File::Temp;

$File::Temp::KEEP_ALL = 1;

Somehow has schema object

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

BEGIN { extends 'Catalyst::Controller' }

sub default :Path('expression_viewer/default')
{
   my ($self, $c) = @_;
   $self->_build_loader($c) unless $self->loader;
   my @info_list = $self->loader->info_list;
   my @img_list = $self->loader->img_list;
   my $default_img =  $img_list[0];
   $self->_build_form($c, $default_img, 
      $self->loader->img_name_to_src->{$default_img},
	$self->current_mode, $info_list[2], ${$self->loader->template}[0]);
}

sub submit :Path('expression_viewer/submit')
{
    my ($self, $c) = @_;
    my $img_name = $c->req->param{'image_selected'};
    my $mode = $c->req->param{'mode'};
    my $micro_one = $c->req->param{'micro_one'};
    my $made_changes = 0;
    my ($micro_two, $compare_data_ref);
    if ($mode eq 'Comparison')
    {
        my $micro_two = $c->req->param{'micro_two'};
        if ($micro_two eq $self->$current_micro_two_name)
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
        my ($data_ref, $PO_terms_child_ref, $PO_term_order_ref, 
           $PO_term_to_color_ref, $PO_term_to_pixel_ref, $coord_to_link_ref) = 
              $self->loader->get_refs_of_required_info($img_name, $micro_one)
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
    if ($made_changes and $threshold !~ /[\d\.]{length($threshold)}/ 
	    		and $mask_ratio !~ /[\d\.]{length($mask_ratio)}/)
    {
        eval{'$self->analyzer->make_' . $mode . 
	    "_picture($threshold, $override, $mask_ratio, $grey_mask_on)";};
        my $fHandle = File::Temp->new(SUFFIX=>'.png',
				      DIR=>
				      $c->get_conf('static_datasets_path') .
				      $c->get_conf('image_dir') . 
				      $c->get_conf('eFP_modified_image_dir'));
        $img_src = $fHandle->filename;
        $self->analyzer->colorer->writeImageAsPNGFile($img_src);
        close $fHandle;
        $c->stash->{$filled_correctly}->{'threshold'} = 1;
        $c->stash->{$filled_correctly}->{'signal_mask'} = 1;
    }
    else
    {
        $c->stash->{$filled_correctly}->{'threshold'} = 
		       ($threshold !~ /[\d\.]{length($threshold)}/);
        $c->stash->{$filled_correctly}->{'signal_mask'} = 
		       ($threshold !~ /[\d\.]{length($mask_ratio)}/);
        $img_src = $self->current_img_source;
    }
    $self->_build_form($c, $img_name, $img_src, $mode, $micro_two);
}

sub _build_form
{
   my ($self, $c, $img_name, $img_src, $coord_to_link_ref
	  			$mode, $micro_one, $micro_two) = @_;
   if ($micro_two)
   {
       $c->stash->{micro_two} = $micro_two;
       $self->current_micro_two_name($micro_two); 
   }
   $c->stash(
       'image_list' => $self->loader->img_list;
       'cur_image_name' => $img_name,
       'cur_image_source' => $img_src,
       'cur_mode' => $mode,
       'micro_one' => $micro_one,
       'coord_of_img_links' => ${$self->loader->img_info->{$img_name}}[2],
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

sub _update_loader
{
   my ($self, $new_schema, $new_gene_config_file, $new_data_source) = @_;
   unless ($self->loader)
   {
      $self->loader = 
         SGN::Feature::ExpressionViewer::Loader->new(-schema => $new_schema,
				  -gene_config_file => $new_gene_config_file,
                                    	    -data_source => $new_data_source);
   }
   #Compares if schema is the same as before
   $self->schema($new_schema) if (
      _schema_is_same($self->schema->connect_info, $new_schema->connect_info);
   #File name so can use string comparison to test 
   $self->gene_config_file($new_gene_config_file)
		if ($new_gene_config_file ne $self->loader->gene_config_file);

   #Not sure how data is to be retrieved
   #If data source is a str with name of the table, can use below
   $self->data_source_file($new_data_source)
		if ($new_data_source ne $self->loader->data_source);
}

#Tests if schemas are equal
sub _schema_is_same
{
   my ($schema_1_info_ref, $schema_2_info_ref) = @_;
   my $
   my %temp1 = map{$_ => 1} 
      (splice(@{$schema_1_info_ref},0,3), splice(@{schema_2_info_ref}, 0,3));
   return 0 if scalar(keys(%temp1)) != 3; 
   my %temp2 = map{$_ => 1} 
      (
   
}

__PACKAGE__->meta->make_immutable;
1;

