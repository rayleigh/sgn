package SGN::Feature::ExpressionViewer::Loader;
use Moose;
use Bio::Chadow::Schema;

has 'gene_config_file_name' => {isa => 'Str', is => 'bare', required => 1};
has 'PO_term_to_color' => {isa => 'Hash', is => 'rw', default => ()};
has 'coordinates_to_link' => {isa => 'Hash', is => 'rw',
                                builder => '_parse_gene_config_file'};
has 'data_source' => {isa => ' ', is => 'rw'
has 'data' => {isa => 'Hash', is => 'ro', lazy_buld => 1};

after 'set_data_source' => sub {
   my $self = shift
   $self-> data = $self -> _build_data;
};

#Config file should have this format:
#PO term\tColor RGB value and include data\tCoordinate on map\tLink
#Ex: PO00001\t0,0,26,1\t22,33\thttp://www.plant.com/
#Includes data from data_source
#Ex: PO00003\t0,0,24,0\t22,50\thttp://www.plant.com/
#Does not include data from data_source
sub _parse_gene_config_file
{
   my $self = shift;
   open CONFIG, "<", $self->gene_config_file_name;
   while (<CONFIG>)
   {
       #Removes all whitespace except \t
       chomp;
       $line =~ s/ //g;

       #Default is split("\t", $_)
       $entries = split;

       $entries[1] =~ s/\s//g;
       $entries[2] =~ s/\s//g;
       $self->PO_term_to_color->{$entries[0]} = $entries[1];
       $self->coordinates_to_link->{$entries[2]} = $entries[3];
   }
   $self->coordinates_to_link;
}

