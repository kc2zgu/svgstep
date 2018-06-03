#!/usr/bin/perl

use strict;
use warnings;

use SVGSub;

my ($svginput, $svgoutput, @vardefs) = @ARGV;

my $svgdoc = SVGSub::load_svg($svginput);

my $vars = {};

for my $def(@vardefs)
{
    if ($def =~ /=/)
    {
        my ($var, $value) = split /=/, $def;
        print "$var = $value\n";
        $vars->{$var} = $value;
    }
    else
    {
        print "no definition: $def\n";
    }
}

my $subdoc = SVGSub::dup_svg($svgdoc);

SVGSub::sub_svg($subdoc, {vars => $vars});

$subdoc->printToFile($svgoutput);
