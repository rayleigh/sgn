
=head1 NAME

SGN::Controller::ExpressionViewer.pm - controller for ExpressionViewer page

=cut

package SGN::Controller::ExpressionViewer;
use Moose;
use namespace::autoclean;
use SGN::ExpressionViewer::Analyzer;
use SGN::ExpressionViewer::Loader;
use constant config_file_name => 'config_file.txt';

has 'img_name_to_src' => {
    is => 'ro',
    isa => 'HashRef',
};

has 'img_src_to_gene_config' =>
{
    is => 'ro',
    isa => 'Hash',
    builder => '_parse_config_file'
};

has 'loader' => {
    is => 'ro',
    isa => 'SGN::Feature::ExpressionViewer::Loader',
   
};

has 'analyzer' => {
    is => "ro",
    isa => 'SGN::Feature::ExpressionViewer::Converter',
    lazy_build = 
};

has 'img_src_list' => {
    is => "ro",
    isa => 'Hash',
    lazy_build = 1;
};

#Assumes config_file has this format:
#img_name\timg_source\tgene_config_file_name\n
#Ex: Flower\tflower.png\tflower_config_file
sub _parse_config_file
{
    my $self = shift;
    open CONFIG, "<", config_file_name;
    while (<CONFIG>)
    {
       chomp;
       $entries = split;
       $self->img_name_to_src->{$entries[0]} = $entries[1];
       $self->img_src_to_gene_config->{$entries[1]} = $entries[2]; 
    }
    $self->img_src_to_gene_config; 
}

BEGIN { extends 'Catalyst::Controller' }

sub default :Path('expression_viewer/default')
{
   my ($self, $c) = @_;
   
}

sub submit :Path('expression_viewer/submit')
{
   my ($self, $c) = @_;
   my $img_name = $c->req->param{'image_selected'};
   my $data_source = $c->req->param{'data_source'};
   my $mode = $c->req->param{'mode'};
   my $gene_one = $c->req->param{'gene_one'};
   my $gene_two = $c->req->param{'gene_two'} if $mode eq 'compare';
   my $schema = ?;
   $self->_update_loader($schema, $gene_config_file, $ 
   'image_selected', 'data_source', 'mode'
   
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

