#!/usr/bin/perl

use strict;
use warnings;

use Getopt::Long;

use SVGStep;
use SVGSub;

# tile input SVG
my $tilepath;
# output SVG
my $outputpath;
# page template
#   db file and key
my $pagedb;
my $pagename;
#   page size
my ($pagewidth, $pageheight);
my $pagesize;
#   column/row count
my ($cols, $rows);
my $tiles;
#   column/row pitch
my ($colpitch, $rowpitch);
my $pitch;
# origin
my ($originx, $originy) = ('0mm', '0mm');
my $origin;
# row major (default column)
my $rowmajor = 0;
# active cells
my @activecells;
my $activespec;
# data source
#   immediate values
my @data_defs;
my @data_vars;
#   CSV
#   DBI
my $dataformat;
my $datasource;
# query/subset
my $query;
#   index
#   SQL
# copies per datum
my $copies;
#   immediate
#   data property

Getopt::Long::Configure('bundling');

GetOptions('input|i=s'        => \$tilepath,
           'output|o=s'       => \$outputpath,
           'pagedb|P=s'       => \$pagedb,
           'page|p=s'         => \$pagename,
           'size|s=s'         => \$pagesize,
           'tiles|t=s'        => \$tiles,
           'pitch|I=s'        => \$pitch,
           'origin|O=s'       => \$origin,
           'rowmajor|r'       => \$rowmajor,
           'active|a=s'       => \$activespec,
           'var|V=s@'         => \@data_defs,
           'format|f=s'       => \$dataformat,
           'datasource|d=s'   => \$datasource,
           'query|q=s'        => \$query,
           'copies|c=s'       => \$copies);

# verify/expand options

if (defined $tiles)
{
    if ($tiles =~ /^(\d+)x(\d+)$/)
    {
        $cols = $1;
        $rows = $2;
    }
    else
    {
        die "Invalid tile grid specification: $tiles\n";
    }
}

if (defined $pitch)
{
    if ($pitch =~ /^(-?[0-9.]+[a-z]+)x(-?[0-9.]+[a-z]+)$/)
    {
        $colpitch = $1;
        $rowpitch = $2;
    }
    else
    {
        die "Invalid tile pitch specification: $pitch\n";
    }
}

if (defined $pagesize)
{
    if ($pagesize =~ /^(-?[0-9.]+[a-z]+)x(-?[0-9.]+[a-z]+)$/)
    {
        $pagewidth = $1;
        $pageheight = $2;
    }
    else
    {
        die "Invalid tile pitch specification: $pagesize\n";
    }
}

if (defined $origin)
{
    if ($origin =~ /^(-?[0-9.]+[a-z]+)x(-?[0-9.]+[a-z]+)$/)
    {
        $originx = $1;
        $originy = $2;
    }
    else
    {
        die "Invalid origin specification: $origin\n";
    }
}

if (defined $activespec)
{
    for my $active(split /,/, $activespec)
    {
        if ($active =~ /^(\d+)-(\d+)$/)
        {
            push @activecells, ($1..$2);
        }
        elsif ($active =~ /^(\d+)$/)
        {
            push @activecells, $1;
        }
        else
        {
            die "Invalid active cell specification: $active\n";
        }
    }
}

for my $varspec(@data_defs)
{
    if ($varspec =~ /^([0-9a-z_]+)=(.*)$/i)
    {
        push @data_vars, [$1, $2];
    }
    else
    {
        die "Invalid variable specification: $varspec\n";
    }
}

die "No input specified\n" unless defined $tilepath;
die "No output specified\n" unless defined $outputpath;

# get page dimensions

die "Page DB not implemented\n" if defined $pagedb;
die "Page DB not implemented\n" if defined $pagename;

die "Page size not set\n" unless (defined $pagewidth && defined $pageheight);
die "Grid size not set\n" unless (defined $cols && defined $rows);
die "Grid spacing not specified\n" unless (defined $colpitch && defined $rowpitch);

#die "No data source specified\n" unless (defined $datasource);
die "No data format specified\n" if (!defined $dataformat && defined $datasource);

print "Input SVG tile: $tilepath\n";
print "Output SVG file: $outputpath\n";
print "Output page size: $pagewidth x $pageheight\n";
print "Grid size: $cols x $rows\n";
print "Grid spacing: $colpitch x $rowpitch\n";
print "Origin: $originx x $originy\n";
print "Grid order: " . ($rowmajor ? 'row' : 'column') . " major\n";
print "Active cells: @activecells\n" if @activecells;
for my $var(@data_vars)
{
    print "Data variable: $var->[0] = $var->[1]\n";
}
print "Data source: $dataformat $datasource\n" if defined $datasource;
print "Data selection query: $query\n" if defined $query;

# open input

my $tile = SVGStep::load_svg($tilepath);
my $tile_root = $tile->getDocumentElement;

my ($xres, $yres) = SVGStep::get_pixel_size($tile);
print "Input pixel size: $xres x $yres\n";

# create output page

my $page = SVGStep::new_svg($pagewidth, $pageheight, $xres, $yres);

SVGStep::svg_copy_defs($tile, $page);

# open datasource

my @records;

if (defined $datasource)
{
    if ($dataformat eq 'CSV')
    {
        die "CSV data source not implemented\n";
    }
    elsif ($dataformat eq 'DBI')
    {
        die "DBI data source not implemented\n";
    }
    else
    {
        die "Unknown data format $dataformat\n";
    }
    unless (defined $copies)
    {
        print "Defaulting to 1 copy\n";
        $copies = 1;
    }
}
else
{
    @records = ({});
    unless (defined $copies)
    {
        $copies = $cols*$rows;
        print "Defaulting to $copies copies\n";
    }
}

# generate grid locations

my @allcells;
my ($cx, $cy) = (0,0);
for (1..$cols*$rows)
{
    print "Cell $cx $cy\n";
    push @allcells, [$cx, $cy];
    if ($rowmajor)
    {
        $cx++;
        if ($cx == $cols)
        {
            $cx = 0;
            $cy++;
        }
    }
    else
    {
        $cy++;
        if ($cy == $rows)
        {
            $cy = 0;
            $cx++;
        }
    }
}

# select active cells

my @selectedcells;
if (@activecells)
{
    for my $acn(@activecells)
    {
        my $acell = @allcells[$acn-1];
        print "Active cell: $acell->[0] $acell->[1]\n";
        push @selectedcells, $acell;
    }
}
else
{
    print "All cells selected\n";
    @selectedcells = @allcells;
}

my $celln = 0;

# loop through data records
for my $rec(@records)
{
    for (1..$copies)
    {
        print "Placing cell $celln\n";
        # calculate cell origin
        my $offsetx = (SVGStep::svg_to_mm($originx) +
                       $selectedcells[$celln]->[0] * SVGStep::svg_to_mm($colpitch)) * $xres;
        my $offsety = (SVGStep::svg_to_mm($originy) +
                       $selectedcells[$celln]->[1] * SVGStep::svg_to_mm($rowpitch)) * $yres;

        print "Output location: $offsetx mm $offsety mm\n";

        # add immediate values

        for my $var(@data_vars)
        {
            $rec->{$var->[0]} = $var->[1];
        }

        for my $key(sort keys %$rec)
        {
            print "Data value: $key = $rec->{$key}\n";
        }

        my $subdoc = SVGSub::dup_svg($tile);

        SVGSub::sub_svg($subdoc, {vars => $rec});

        SVGStep::svg_add_step($subdoc, $page, $offsetx, $offsety, $celln);

        # advance to next cell
        $celln++;
    }
}

# save output

$page->printToFile($outputpath);
