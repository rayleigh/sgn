
=head1 NAME

SGN::Controller::ExpressionViewer.pm - controller for ExpressionViewer page

=cut

package SGN::Controller::ExpressionViewer;
use Moose;
use namespace::autoclean;

has 'analyzer' => {
    is => "bare",
    isa => 'SGN::Feature::ExpressionViewer::Converter',
    lazy_build = 
};

has 'img_src_list' => {
    is => "bare",
    isa => 'Hash',
    lazy_build = 1;
};

sub _build_img_src_list
{
    

}

BEGIN { extends 'Catalyst::Controller' }

#If form uses GET, we will do the following
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
   'image_selected', 'data_source', 'mode'

}
