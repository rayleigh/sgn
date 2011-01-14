

#If form uses POST, we will have to chain expression
sub expression_viewer : PathPart('expression_viewer') Chained('/') CaptureArgs(0) {
   my ($self, $c) = @_; 
   $c->stash->{template} = "/tools/expression_viewer.mas";
   
}

sub 

#If form uses GET, we will do the following
sub expression_viewer
{
   my ($self, $c) = @_;
   my $img_name = $c->req->param{'image_selected'};
   my $data_source = $c->req->param{'data_source'};
   my $mode = $c->req->param{'mode'};
   'image_selected', 'data_source', 'mode'
}
