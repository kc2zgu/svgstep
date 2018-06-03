package SVGSub;

use strict;
use warnings;

use XML::DOM;

sub load_svg {
    my $svgpath = shift;

    my $parser = XML::DOM::Parser->new;
    print "Loading $svgpath\n";
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

    print "Substituted text: $text\n";

    return $text;
}

sub _sub_subtree {
    my ($el, $vars) = @_;

    my $tag = $el->getTagName;
    print "Substituting in $tag\n";

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
                print "Text in $tag: $textval\n";
                $child->setData(_sub_text($textval, $vars));
            }
        }
    }
}

1;
