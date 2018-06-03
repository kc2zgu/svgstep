#!/usr/bin/perl

use strict;
use warnings;

use XML::DOM;

my %svg_units = ( mm => 1,
                  in => 25.4,
                );
my $svg_ns = 'http://www.w3.org/2000/svg';

sub svg_to_mm {
    my $length = shift;

    my ($value, $unit) = $length =~ /^(-?(?:[0-9.])+)([a-z]+)$/i;
    print "parsed length: $length = $value * $unit\n";
    if (exists $svg_units{$unit})
    {
        my $mm = $value * $svg_units{$unit};
        print "converted: $mm mm\n";
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

sub svg_add_defs {
    my ($tile, $dest) = @_;

    my $dest_root = $dest->getDocumentElement;

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

my ($svgtile, $svgout, $width, $height, $x, $y, $dx, $dy, $xs, $ys) = @ARGV;

my $tile = load_svg($svgtile);
my $tile_root = $tile->getDocumentElement;
my $twidth = $tile_root->getAttribute('width');
my $theight = $tile_root->getAttribute('height');
my @vbox = split /\s+/, $tile_root->getAttribute('viewBox');
my $xres = $vbox[2] / svg_to_mm($twidth);
my $yres = $vbox[3] / svg_to_mm($theight);
print "Input pixel size: $xres x $yres\n";

my $page = new_svg($width, $height, $xres, $yres);

svg_add_defs($tile, $page);

$xs = 1 unless $xs;
$ys = 1 unless $ys;
$dx = '0mm' unless $dx;
$dy = '0mm' unless $dy;

for my $tx (0..$xs-1)
{
    for my $ty (0.. $ys-1)
    {
        my $offsetx = (svg_to_mm($x) + $tx * svg_to_mm($dx)) * $xres;
        my $offsety = (svg_to_mm($y) + $ty * svg_to_mm($dy)) * $yres;
        print "Output tile position: $offsetx $offsety\n";

        svg_add_step($tile, $page, $offsetx, $offsety, "$tx-$ty");
    }
}

$page->printToFile($svgout);
