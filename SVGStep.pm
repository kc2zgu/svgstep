package SVGStep;

use strict;
use warnings;

use XML::DOM;

my %svg_units = ( mm => 1,
                  cm => 10,
                  in => 25.4,
                  pt => 25.4 / 72,
                );

my $svg_ns = 'http://www.w3.org/2000/svg';

sub svg_to_mm {
    my $length = shift;

    my ($value, $unit) = $length =~ /^(-?(?:[0-9.])+)([a-z]+)$/i;
    #print "parsed length: $length = $value * $unit\n";
    if (exists $svg_units{$unit})
    {
        my $mm = $value * $svg_units{$unit};
        #print "converted: $mm mm\n";
        return $mm;
    }
    else
    {
        die "Undefined unit $unit";
    }
}

sub load_svg {
    my $svgpath = shift;

    my $parser = XML::DOM::Parser->new;
    print "Loading $svgpath\n";
    return $parser->parsefile($svgpath);
}

sub get_pixel_size {
    my $svgdoc = shift;

    my $svg_root = $svgdoc->getDocumentElement;
    my $twidth = $svg_root->getAttribute('width');
    my $theight = $svg_root->getAttribute('height');
    my @vbox = split /\s+/, $svg_root->getAttribute('viewBox');
    my $xres = $vbox[2] / svg_to_mm($twidth);
    my $yres = $vbox[3] / svg_to_mm($theight);

    return wantarray ? ($xres, $yres) : ($xres+$yres)/2;
}

sub new_svg {
    my ($width, $height, $xres, $yres) = @_;

    print "Crating new SVG document\n";
    my $svg = XML::DOM::Document->new;
    $svg->setXMLDecl($svg->createXMLDecl('1.0', 'UTF-8'));

    my $svg_root = $svg->createElement('svg');
    $svg_root->setAttribute(xmlns => $svg_ns);

    $svg_root->setAttribute(width => $width);
    $svg_root->setAttribute(height => $height);

    my @vbox = (0, 0, svg_to_mm($width) * $xres, svg_to_mm($height) * $yres);
    print "Computed viewBox: @vbox\n";
    $svg_root->setAttribute(viewBox => join(' ', @vbox));

    $svg->appendChild($svg_root);

    return $svg;
}

sub svg_copy_defs {
    my ($tile, $dest) = @_;

    my $dest_root = $dest->getDocumentElement;

    my $attlist = $tile->getDocumentElement->getAttributes;
    for my $index ($attlist->getValues)
    {
        my $prefix = $index->getName;
        next unless $prefix =~ /^xmlns:/;
        my $nsuri = $index->getValue;
        print "namespace: $prefix = $nsuri\n";
        $dest_root->setAttribute($prefix, $nsuri);
    }
    my @tile_nodes = $tile->getDocumentElement->getChildNodes;
    for my $child(@tile_nodes)
    {
        if ($child->getNodeType == ELEMENT_NODE && $child->getTagName ne 'g')
        {
            my $childcopy = $child->cloneNode(1);
            $childcopy->setOwnerDocument($dest);
            $dest_root->appendChild($childcopy);
            print "Copied " . $child->getTagName ." element\n";
        }
    }
}

sub svg_add_step {
    my ($tile, $dest, $offsetx, $offsety, $id) = @_;

    my $dest_root = $dest->getDocumentElement;

    my $newgroup = $dest->createElement('g');
    $newgroup->setAttribute(id => "step-$id");

    $newgroup->setAttribute(transform => "translate($offsetx, $offsety)");

    my @tile_nodes = $tile->getDocumentElement->getChildNodes;
    for my $child(@tile_nodes)
    {
        if ($child->getNodeType == ELEMENT_NODE && $child->getTagName eq 'g')
        {
            my $childcopy = $child->cloneNode(1);
            $childcopy->setOwnerDocument($dest);
            $newgroup->appendChild($childcopy);
            print "Copied " . $child->getTagName ." element\n";
        }
    }

    $dest_root->appendChild($newgroup);
}

1;
