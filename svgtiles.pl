#!/usr/bin/perl

use strict;
use warnings;

use Getopt::Long;
use Text::CSV_XS qw/csv/;
use FindBin;
use lib $FindBin::Bin;

use Log::Any '$log';
use Log::Any::Adapter ('Stdout', log_level => 'info');

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

sub usage {
    print "Usage: $0 -i input.svg -o output.svg\n";
    print "    -s pagesize -t tiles -I pitch -O origin\n";
    exit 1;
}

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

unless (defined $tilepath && defined $outputpath)
{
    usage();
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

$log->info("Input SVG tile: $tilepath");
$log->info("Output SVG file: $outputpath");
$log->info("Output page size: $pagewidth x $pageheight");
$log->info("Grid size: $cols x $rows");
$log->info("Grid spacing: $colpitch x $rowpitch");
$log->info("Origin: $originx x $originy");
$log->info("Grid order: " . ($rowmajor ? 'row' : 'column') . " major");
$log->info("Active cells: @activecells") if @activecells;
for my $var(@data_vars)
{
    $log->info("Data variable: $var->[0] = $var->[1]");
}
$log->info("Data source: $dataformat $datasource") if defined $datasource;
$log->info("Data selection query: $query") if defined $query;

# open input

my $tile = SVGStep::load_svg($tilepath);
my $tile_root = $tile->getDocumentElement;

my ($xres, $yres) = SVGStep::get_pixel_size($tile);
$log->debug("Input pixel size: $xres x $yres");

# create output page

my $page = SVGStep::new_svg($pagewidth, $pageheight, $xres, $yres);

SVGStep::svg_copy_defs($tile, $page);

# open datasource

my @records;

if (defined $datasource)
{
    if ($dataformat eq 'CSV')
    {
        @records = @{csv({in => $datasource, headers => 'auto'})};
        my $count = @records;
        $log->debug("Loaded $count CSV records from $datasource");
        if ($query)
        {
            my @selrows;
            for my $range(split /,/, $query)
            {
                $log->debug("CSV range: $range");
                if ($range =~ /(\d+)-(\d+)/)
                {
                    push @selrows, @records[$1-1..$2-1];
                }
                else
                {
                    push @selrows, $records[$range-1];
                }
            }
            @records = @selrows;
        }
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
        $log->info("Defaulting to 1 copy");
        $copies = 1;
    }
}
# if no datasource defined create a single null record (only command line vars)
else
{
    @records = ({});
    unless (defined $copies)
    {
        $copies = $cols*$rows;
        $log->info("Defaulting to $copies copies");
    }
}

# generate grid locations

my @allcells;
my ($cx, $cy) = (0,0);
for (1..$cols*$rows)
{
    $log->debug("Cell $cx $cy");
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
        my $acell = $allcells[$acn-1];
        $log->info("Active cell: $acell->[0] $acell->[1]");
        push @selectedcells, $acell;
    }
}
else
{
    $log->info("All cells selected");
    @selectedcells = @allcells;
}

my $celln = 0;

# loop through data records
for my $rec(@records)
{
    for (1..$copies)
    {
        $log->info("Placing cell $celln");
        # calculate cell origin
        my $offsetx = (SVGStep::svg_to_mm($originx) +
                       $selectedcells[$celln]->[0] * SVGStep::svg_to_mm($colpitch)) * $xres;
        my $offsety = (SVGStep::svg_to_mm($originy) +
                       $selectedcells[$celln]->[1] * SVGStep::svg_to_mm($rowpitch)) * $yres;

        $log->debug("Output location: $offsetx mm $offsety mm");

        # add immediate values

        for my $var(@data_vars)
        {
            $rec->{$var->[0]} = $var->[1];
        }

        for my $key(sort keys %$rec)
        {
            $log->debug("Data value: $key = $rec->{$key}");
        }

        my $subdoc = SVGSub::dup_svg($tile);

        SVGSub::sub_svg($subdoc, {vars => $rec});

        SVGStep::svg_add_step($subdoc, $page, $offsetx, $offsety, $celln);

        # advance to next cell
        $celln++;
    }
    if ($celln > @selectedcells)
    {
        $log->warn("Page overflow!");
        last;
    }
}

# save output

$page->printToFile($outputpath);
