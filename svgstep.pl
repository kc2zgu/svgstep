#!/usr/bin/perl

use strict;
use warnings;

use XML::DOM;

use SVGStep;

my ($svgtile, $svgout, $width, $height, $x, $y, $dx, $dy, $xs, $ys) = @ARGV;

my $tile = SVGStep::load_svg($svgtile);
my $tile_root = $tile->getDocumentElement;

my ($xres, $yres) = SVGStep::get_pixel_size($tile);
print "Input pixel size: $xres x $yres\n";

my $page = SVGStep::new_svg($width, $height, $xres, $yres);

SVGStep::svg_copy_defs($tile, $page);

$xs = 1 unless $xs;
$ys = 1 unless $ys;
$dx = '0mm' unless $dx;
$dy = '0mm' unless $dy;

for my $tx (0..$xs-1)
{
    for my $ty (0.. $ys-1)
    {
        my $offsetx = (SVGStep::svg_to_mm($x) + $tx * SVGStep::svg_to_mm($dx)) * $xres;
        my $offsety = (SVGStep::svg_to_mm($y) + $ty * SVGStep::svg_to_mm($dy)) * $yres;
        print "Output tile position: $offsetx $offsety\n";

        SVGStep::svg_add_step($tile, $page, $offsetx, $offsety, "$tx-$ty");
    }
}

$page->printToFile($svgout);
