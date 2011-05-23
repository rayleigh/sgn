package SGN::Feature::ExpressionViewer::Initializer;
use Moose;

has 'image_list_file_name' =>  {isa => 'Str', is => 'bare', required => 1, default => 'some_file_name.txt'};
has 'img_name_to_img_source' => {isa => 'Hash', is => 'ro'};


