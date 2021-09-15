package SVGSub;

use strict;
use warnings;

use XML::DOM;

use Log::Any '$log';

sub load_svg {
    my $svgpath = shift;

    my $parser = XML::DOM::Parser->new;
    $log->info("Loading $svgpath");
    return $parser->parsefile($svgpath);
}

sub dup_svg {
    my $svgdoc = shift;

    return $svgdoc->cloneNode(1);
}

sub sub_svg {
    my ($svgdoc, $vars) = @_;

    _sub_subtree($svgdoc->getDocumentElement, $vars);
}

sub _sub_text {
    my ($text, $vars) = @_;

    $text =~ s[\$\{([a-zA-Z0-9_]+)\}]
              [exists $vars->{vars}->{$1} ? $vars->{vars}->{$1} : '???']eg;

    $log->debug("Substituted text: $text");

    return $text;
}

sub _sub_subtree {
    my ($el, $vars) = @_;

    my $tag = $el->getTagName;
    $log->debug("Substituting in $tag");

    for my $child($el->getChildNodes)
    {
        if ($child->getNodeType == ELEMENT_NODE)
        {
            _sub_subtree($child, $vars);
        }
        if ($tag eq 'text' || $tag eq 'tspan')
        {
            if ($child->getNodeType == TEXT_NODE || $child->getNodeType == CDATA_SECTION_NODE)
            {
                my $textval = $child->getData;
                $log->debug("Text in $tag: $textval");
                $child->setData(_sub_text($textval, $vars));
            }
        }
    }
}

sub _get_config {
    my $node = shift;
    my %conf;

    if ($node->getNodeType == ELEMENT_NODE)
    {
        if (my $desc = $node->getAttribute('description'))
        {
            my @dirs = split /\n|;\s*/, $desc;
            for my $dir(@dirs)
            {
                my ($key, $value) = split /:\s*/, $dir;
                $conf{$key} = $value;
            }
        }
    }

    return \%conf;
}

1;
